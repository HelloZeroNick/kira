/*
 * 应用图标切换通道，对应 Android 的 "io.github.caolib.kira/app_icon"
 * （MainActivity 里切 launcher-alias 的那套）。
 *
 * 鸿蒙没有可运行时启停的 launcher alias，官方能力是 AppGallery Kit 的
 * 图标管理服务：图标先在 AGC「分发 > 服务 > 图标管理」上传并过审，客户端再用
 * selectDynamicIcon / disableDynamicIcon 切换。
 *
 * Dart 侧的语义是 [0, appLogoPaths.length) 的下标数组，这里把它映射成：
 *   index 0  → 恢复默认图标（disableDynamicIcon）
 *   index i  → 选第 i 个动态图标（icons[i - 1]）
 * 一个图标都没配（1006800010 No dynamic icon data）时，getAppIconIndex 返回 0、
 * setAppIcon 忽略写入，界面上的选项就会和实际不一致——所以调用方仍应按
 * 真实可用的图标数量决定是否展示入口。
 *
 * 约束：图标管理服务不支持模拟器，需真机；从 5.0.3(15) 起可用。
 */
import {
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
} from '@ohos/flutter_ohos';
import { appInfoManager } from '@kit.AppGalleryKit';
import { BusinessError } from '@kit.BasicServicesKit';
import Log from '@ohos/flutter_ohos/src/main/ets/util/Log';

const TAG = 'KiraAppIconChannel';
const CHANNEL = 'io.github.caolib.kira/app_icon';
/** 「No dynamic icon data」：应用没有配置任何动态图标。 */
const ERROR_NO_DYNAMIC_ICON = 1006800010;

export default class KiraAppIconChannel implements FlutterPlugin, MethodCallHandler {
  private channel: MethodChannel | null = null;

  getUniqueClassName(): string {
    return 'KiraAppIconChannel';
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL);
    this.channel.setMethodCallHandler(this);
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.channel?.setMethodCallHandler(null);
    this.channel = null;
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    switch (call.method) {
      case 'setAppIcon':
        this.setAppIcon(call, result);
        break;
      case 'getAppIconIndex':
        this.getAppIconIndex(result);
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  private setAppIcon(call: MethodCall, result: MethodResult): void {
    const index: number = (call.argument('index') as number) ?? 0;
    this.queryIcons().then((icons: appInfoManager.DynamicIconInfo[]) => {
      // index 0 表示恢复默认图标；越界时同样回落到默认，避免用户选中一个
      // AGC 上并不存在的图标后桌面图标卡住不动。
      if (index <= 0 || index > icons.length) {
        return appInfoManager.disableDynamicIcon().then(() => {
          result.success(null);
        });
      }
      return appInfoManager.selectDynamicIcon(icons[index - 1].iconId).then(() => {
        result.success(null);
      });
    }).catch((error: Error) => {
      Log.e(TAG, `setAppIcon(${index}) failed: ${error.message}`);
      result.error('set_app_icon_failed', error.message, null);
    });
  }

  private getAppIconIndex(result: MethodResult): void {
    this.queryIcons().then((icons: appInfoManager.DynamicIconInfo[]) => {
      // 返回「当前生效图标」的 Dart 下标：找到 enabled 的那一个即 +1，
      // 都不在生效状态就是默认图标（0）。
      for (let i = 0; i < icons.length; i++) {
        if (icons[i].enabled) {
          result.success(i + 1);
          return;
        }
      }
      result.success(0);
    }).catch((error: Error) => {
      Log.e(TAG, `getAppIconIndex failed: ${error.message}`);
      result.error('get_app_icon_failed', error.message, null);
    });
  }

  /** 查询动态图标列表，「未配置任何动态图标」当作空列表而不是错误。 */
  private queryIcons(): Promise<appInfoManager.DynamicIconInfo[]> {
    return appInfoManager.queryDynamicIcons().catch((error: BusinessError) => {
      if (error.code === ERROR_NO_DYNAMIC_ICON) {
        // 应用没在 AGC 上配任何动态图标：空列表，让上层回落到默认图标。
        return Promise.resolve([] as appInfoManager.DynamicIconInfo[]);
      }
      // ArkTS 只允许抛 Error，BusinessError 需要包一层，原始 code 放进 message 保留可读性。
      return Promise.reject(new Error(`queryDynamicIcons failed: ${error.code} ${error.message}`));
    });
  }
}