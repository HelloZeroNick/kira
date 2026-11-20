/*
 * 鸿蒙入口 Ability。
 *
 * 除了跑 Flutter，还要做两件平台侧的事：
 *   1. 注册 kira 自己的三个 MethodChannel（音量键/图标/加密），
 *      GeneratedPluginRegistrant 只覆盖 pub 依赖，覆盖不到这些。
 *   2. 处理 kira:// 深链与 https 分享链接（App Linking）的 want。
 *      module.json5 已声明对应 skill，但 flutter_ohos 的
 *      maybeGetInitialRouteFromIntent 是空实现，冷启动和热启动都不会把
 *      want.uri 交给 Flutter，需要自己补。
 *
 * 深链如何映射到路由：
 *   kira://open/comic/{pathWord}          → /comic/{pathWord}
 *   https://{webHost}/c/?w={pathWord}     → /comic/{pathWord}
 * 后者与 app_router.dart 里 /c 路由的 redirect 等价，见 lib/utils/kira_links.dart。
 *
 * 冷启动为什么覆写 getInitialRoute 而不是在 onCreate 里改 want:
 *   FlutterAbility.onCreate 内部会直接调 delegate.onWindowStageCreate()，
 *   而 doInitialFlutterViewRun() 在那之前就执行完毕并调用
 *   navigationChannel.setInitialRoute()。也就是说「在 super.onCreate 之后再往
 *   want.parameters 里塞 route」已经太晚，引擎早用空路由把 Dart 拉起来了。
 *   （PiliPlus 的做法是把 want.uri 在 super 之前改写。）
 *   这里改成覆写 getInitialRoute：它是引擎取初始路由的唯一入口，
 *   在 super.onCreate 期间被调用，时序上更稳。
 */
import { FlutterAbility, FlutterEngine } from '@ohos/flutter_ohos';
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';
import KiraVolumeChannel from '../plugins/KiraVolumeChannel';
import KiraAppIconChannel from '../plugins/KiraAppIconChannel';
import KiraCryptoChannel from '../plugins/KiraCryptoChannel';
import KiraDownloadDirChannel from '../plugins/KiraDownloadDirChannel';
import Log from '@ohos/flutter_ohos/src/main/ets/util/Log';
import { Want, AbilityConstant } from '@kit.AbilityKit';
import { uri } from '@kit.ArkTS';

const TAG = 'KiraEntryAbility';
/** 与 lib/utils/kira_links.dart 的 KiraLinks.scheme 保持一致。 */
const LINK_SCHEME = 'kira';
/** 与 KiraLinks.comicDetail 的固定 host 保持一致。 */
const LINK_HOST = 'open';
/** 与 KiraLinks.webHost 保持一致（module.json5 的 App Linking host 要一致）。 */
const WEB_HOST = 'kira.caolib.qzz.io';
/** 漫画分享落地页路径，与 Android intent-filter 的 pathPrefix="/c/" 一致。 */
const WEB_COMIC_PATH = '/c';

export default class EntryAbility extends FlutterAbility {
  /**
   * 冷启动深链解析结果。
   *
   * getInitialRoute() 是在 super.onCreate() **内部**被引擎调用的（delegate 在
   * onCreate 末尾就跑 doInitialFlutterViewRun），此时 this.launchWant 是否已由
   * 系统填好属于实现细节。onCreate 的 want 参数则是确定的，所以在进 super 之前
   * 先解析并缓存，getInitialRoute 优先用它，避免踩时序。
   */
  private launchRoute: string | null = null;

  configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    GeneratedPluginRegistrant.registerWith(flutterEngine)
    flutterEngine.getPlugins()?.add(new KiraVolumeChannel());
    flutterEngine.getPlugins()?.add(new KiraAppIconChannel());
    flutterEngine.getPlugins()?.add(new KiraCryptoChannel());
    flutterEngine.getPlugins()?.add(new KiraDownloadDirChannel());
  }

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    // 必须在 super.onCreate 之前解析：引擎在 super 内部就会取初始路由。
    this.launchRoute = routeFromWant(want);
    super.onCreate(want, launchParam);
  }

  /**
   * 冷启动的初始路由。引擎在 super.onCreate → delegate.onWindowStageCreate →
   * doInitialFlutterViewRun 里调用本方法，早于 Dart 执行，GoRouter 会以它
   * 作为 initialLocation（defaultRouteName 非 '/' 时优先于配置的 '/'）。
   *
   * 没有深链时返回 super 的实现（空串），行为与改动前一致。
   */
  getInitialRoute(): string {
    if (this.launchRoute != null) {
      Log.i(TAG, `cold start deep link: ${this.launchRoute}`);
      return this.launchRoute;
    }
    return super.getInitialRoute();
  }

  /**
   * 热启动（应用已在前台/后台）时系统不再重建引擎，只回调 onNewWant，
   * 需要主动把新路由推给 Flutter，效果与 Android 上「点击深链跳到详情页」一致。
   */
  onNewWant(want: Want, launchParams: AbilityConstant.LaunchParam): void {
    super.onNewWant(want, launchParams);
    const route = routeFromWant(want);
    if (route == null) {
      return;
    }
    Log.i(TAG, `new want deep link: ${route}`);
    this.getFlutterEngine()?.getNavigationChannel()?.pushRouteInformation(route);
  }
}

/**
 * 把 want.uri 换成 GoRouter 能直接匹配的内部路由，支持两种链接：
 *
 *   1. kira://open{path}           —— 自定义协议深链，path 就是内部路由；
 *   2. https://{webHost}/c/?w=xxx  —— 分享落地页（App Linking / Android App Links）。
 *
 * 第 2 种直接映射成 /comic/{pathWord}，与 app_router.dart 里 /c 路由的
 * redirect 等价：即使 GoRouter 的 /c redirect 没走到（例如链接被平台直接
 * 当作 initialLocation 使用），也能落到正确页面。
 *
 * 不是上述两种链接时返回 null（不干预正常启动）。
 */
function routeFromWant(want: Want): string | null {
  const raw: string = want.uri ?? '';
  if (raw.length === 0) {
    return null;
  }
  try {
    const parsed: uri.URI = new uri.URI(raw);
    if (parsed.scheme === LINK_SCHEME) {
      return routeFromCustomScheme(parsed);
    }
    if (parsed.scheme === 'https') {
      return routeFromWebLink(parsed);
    }
    return null;
  } catch (error) {
    // want.uri 不是合法 URI：忽略，不能让畸形深链打断启动。
    Log.w(TAG, `invalid want.uri: ${raw}`);
    return null;
  }
}

/** kira://open{path} → 内部路由；host 固定为 open。 */
function routeFromCustomScheme(parsed: uri.URI): string | null {
  if (parsed.host !== LINK_HOST) {
    Log.w(TAG, `ignored deep link with unexpected host: ${parsed.host}`);
    return null;
  }
  const path: string = parsed.path;
  if (path == null || path.length === 0) {
    return null;
  }
  // 带上 query 一起给 GoRouter（例如 /bookshelf?type=novel）。
  const query: string = parsed.query;
  return query == null || query.length === 0 ? path : `${path}?${query}`;
}

/** https://{webHost}/c/?w={pathWord} → /comic/{pathWord}；其它 https 链接忽略。 */
function routeFromWebLink(parsed: uri.URI): string | null {
  if (parsed.host !== WEB_HOST) {
    return null;
  }
  const path: string = parsed.path;
  // 允许 /c 与 /c/ 两种写法（浏览器可能省略尾斜杠）。
  if (path !== WEB_COMIC_PATH && path !== `${WEB_COMIC_PATH}/`) {
    return null;
  }
  const pathWord: string = parsed.getQueryValue('w');
  // 与 KiraLinks 的 pathWord 规则一致：只含字母、数字、下划线、连字符。
  const validWord: boolean =
    pathWord != null && pathWord.length > 0 && new RegExp('^[\\w-]+$').test(pathWord);
  if (!validWord) {
    // 参数缺失或非法：交给 Web 落地页处理，不要在应用里打开一个坏路由。
    Log.w(TAG, `ignored web link with invalid pathWord: ${pathWord}`);
    return null;
  }
  return `/comic/${pathWord}`;
}
