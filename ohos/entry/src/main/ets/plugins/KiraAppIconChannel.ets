/*
 * 应用图标切换通道，对应 Android 的 "io.github.caolib.kira/app_icon"。
 *
 * 鸿蒙用 app.json5 的 alternateIcons（API 26 起）+ bundleManager 的
 * getAlternateIcons / setAlternateIcon 切换，图标随 HAP 打包，无需 AGC 上架。
 *
 * 下标映射与 Android 一致：[0, appLogoPaths.length)
 *   index 0 → setAlternateIcon('')  恢复默认图标
 *   index i → icons[i - 1].iconName
 * 越界同样回默认。
 *
 * API < 26 等失败场景由本通道直接在原生侧弹 toast，Dart 侧不感知差异。
 */
import {
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
} from '@ohos/flutter_ohos';
import { bundleManager, common } from '@kit.AbilityKit';
import { BusinessError, deviceInfo } from '@kit.BasicServicesKit';
import { window } from '@kit.ArkUI';
import Log from '@ohos/flutter_ohos/src/main/ets/util/Log';

const TAG = 'KiraAppIconChannel';
const CHANNEL = 'io.github.caolib.kira/app_icon';
/** alternateIcons / setAlternateIcon 的起始 API 版本。 */
const MIN_API_VERSION = 26;
/** 未配置任何备选图标（等价于空列表）。 */
const ERROR_GET_ALTERNATE_ICON = 17700311;
/** 当前没有启用中的备选图标：恢复默认时视为成功。 */
const ERROR_NO_ALTERNATE_ICON_ENABLED = 17700309;
const UNSUPPORTED_CODE = 'app_icon_unsupported';
const TOAST_UNSUPPORTED = '当前系统版本不支持切换桌面图标';
const TOAST_FAILED = '桌面图标切换失败';

export default class KiraAppIconChannel implements FlutterPlugin, MethodCallHandler {
  private channel: MethodChannel | null = null;
  private context: common.Context | null = null;

  getUniqueClassName(): string {
    return 'KiraAppIconChannel';
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.context = binding.getApplicationContext();
    this.channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL);
    this.channel.setMethodCallHandler(this);
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.channel?.setMethodCallHandler(null);
    this.channel = null;
    this.context = null;
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
    if (!isSupported()) {
      this.toast(TOAST_UNSUPPORTED);
      result.error(UNSUPPORTED_CODE, `需要 HarmonyOS API ${MIN_API_VERSION} 及以上`, null);
      return;
    }
    const index: number = (call.argument('index') as number) ?? 0;
    this.resolveIconName(index).then((name: string) => {
      return bundleManager.setAlternateIcon(name);
    }).then(() => {
      result.success(null);
    }).catch((error: BusinessError) => {
      if (error.code === ERROR_NO_ALTERNATE_ICON_ENABLED) {
        // 已经是默认图标，重复恢复不算失败。
        result.success(null);
        return;
      }
      Log.e(TAG, `setAppIcon(${index}) failed: ${error.code} ${error.message}`);
      this.toast(TOAST_FAILED);
      result.error('set_app_icon_failed', `${error.code} ${error.message}`, null);
    });
  }

  private getAppIconIndex(result: MethodResult): void {
    if (!isSupported()) {
      // 读取失败不打扰用户，交给上层沿用本地偏好。
      result.error(UNSUPPORTED_CODE, `需要 HarmonyOS API ${MIN_API_VERSION} 及以上`, null);
      return;
    }
    this.queryIcons().then((icons: bundleManager.AlternateIconInfo[]) => {
      for (let i = 0; i < icons.length; i++) {
        if (icons[i].enabled) {
          result.success(i + 1);
          return;
        }
      }
      result.success(0);
    }).catch((error: BusinessError) => {
      Log.e(TAG, `getAppIconIndex failed: ${error.code} ${error.message}`);
      result.error('get_app_icon_failed', `${error.code} ${error.message}`, null);
    });
  }

  /** 把 Dart 下标换成备选图标名；0 或越界返回空串（恢复默认）。 */
  private resolveIconName(index: number): Promise<string> {
    if (index <= 0) {
      return Promise.resolve('');
    }
    return this.queryIcons().then((icons: bundleManager.AlternateIconInfo[]) => {
      return index > icons.length ? '' : icons[index - 1].iconName;
    });
  }

  /** 查询备选图标列表，未配置任何备选图标时当作空列表。 */
  private queryIcons(): Promise<bundleManager.AlternateIconInfo[]> {
    return bundleManager.getAlternateIcons().catch((error: BusinessError) => {
      if (error.code === ERROR_GET_ALTERNATE_ICON) {
        return Promise.resolve([] as bundleManager.AlternateIconInfo[]);
      }
      return Promise.reject(new Error(`${error.code} ${error.message}`));
    });
  }

  /** 原生 toast：Toast 挂在主窗口的 UIContext 上，拿不到窗口时静默放弃。 */
  private toast(message: string): void {
    const ctx = this.context;
    if (ctx == null) {
      return;
    }
    window.getLastWindow(ctx).then((win: window.Window) => {
      win.getUIContext().getPromptAction().showToast({ message: message, duration: 2000 });
    }).catch((error: BusinessError) => {
      Log.w(TAG, `showToast failed: ${error.code} ${error.message}`);
    });
  }
}

function isSupported(): boolean {
  return deviceInfo.sdkApiVersion >= MIN_API_VERSION;
}
