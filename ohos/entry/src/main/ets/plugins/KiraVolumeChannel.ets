/*
 * 阅读器的音量键翻页与沉浸式系统栏通道，对应 Android MainActivity 的
 * "io.github.caolib.kira/volume"。
 *
 * 分两半：
 *   1. Dart → 平台（enable/disable/enableImmersive/disableImmersive）：与 Android 一致。
 *      沉浸/退出沉浸由 flutter_ohos 的 PlatformPlugin 接管 SystemChrome，
 *      这里只保证四个方法都回 success，别让 Dart 侧把通道判成不可用。
 *   2. 平台 → Dart（volumeUp/volumeDown 反向回调）：用 Input Kit 的
 *      inputConsumer.on('keyPressed')。
 *
 * 为什么不用 ArkUI 的 onKeyEvent：音量键在分发到应用之前就被系统消费了，
 * FlutterPage 的 onKeyEvent 收不到，实测「音量翻页」完全不触发。
 * 官方给阅读类应用的方案是「优先响应系统功能键」（API 16+）：
 *   - 只有应用处于前台焦点窗口时生效；
 *   - 订阅成功后系统音量调节会失效，所以必须严格跟随 enable/disable，
 *     绝不能在非阅读场景挂着订阅，否则用户调不了音量。
 */
import {
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
} from '@ohos/flutter_ohos';
import { inputConsumer, KeyCode } from '@kit.InputKit';
import { BusinessError } from '@kit.BasicServicesKit';
import Log from '@ohos/flutter_ohos/src/main/ets/util/Log';

const TAG = 'KiraVolumeChannel';
const CHANNEL = 'io.github.caolib.kira/volume';

export default class KiraVolumeChannel implements FlutterPlugin, MethodCallHandler {
  private channel: MethodChannel | null = null;
  /** 是否已向系统订阅音量键；与 Dart 侧的 enable/disable 一一对应。 */
  private subscribed: boolean = false;

  getUniqueClassName(): string {
    return 'KiraVolumeChannel';
  }

  // 不同按键必须用不同回调，否则订阅不生效（SDK 文档明确要求）。
  private onVolumeUp = (): void => {
    this.notifyReader('volumeUp');
  };

  private onVolumeDown = (): void => {
    this.notifyReader('volumeDown');
  };

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL);
    this.channel.setMethodCallHandler(this);
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.unsubscribe();
    this.channel?.setMethodCallHandler(null);
    this.channel = null;
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    switch (call.method) {
      case 'enable':
        this.subscribe();
        result.success(null);
        break;
      case 'disable':
        this.unsubscribe();
        result.success(null);
        break;
      case 'enableImmersive':
      case 'disableImmersive':
        // 沉浸切换由 Dart 的 SystemChrome.setEnabledSystemUIMode 完成，
        // flutter_ohos 的 PlatformPlugin 已实现；这里只回应成功。
        result.success(null);
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  private subscribe(): void {
    if (this.subscribed) {
      return;
    }
    try {
      // action: 1 = 只订阅按下；isRepeat: false = 长按不重复上报，
      // 避免按住音量键时连续翻页。
      const upOptions: inputConsumer.KeyPressedConfig = {
        key: KeyCode.KEYCODE_VOLUME_UP,
        action: 1,
        isRepeat: false,
      };
      const downOptions: inputConsumer.KeyPressedConfig = {
        key: KeyCode.KEYCODE_VOLUME_DOWN,
        action: 1,
        isRepeat: false,
      };
      inputConsumer.on('keyPressed', upOptions, this.onVolumeUp);
      inputConsumer.on('keyPressed', downOptions, this.onVolumeDown);
      this.subscribed = true;
      Log.i(TAG, 'volume key interception enabled');
    } catch (error) {
      // 801 = 设备不支持该能力（例如部分平板/PC 键盘形态）。
      // 订阅失败时必须保证 Dart 侧仍可用，通道本身照常回应成功。
      const e = error as BusinessError;
      this.subscribed = false;
      Log.w(TAG, `subscribe volume key failed: ${e.code} ${e.message}`);
    }
  }

  private unsubscribe(): void {
    if (!this.subscribed) {
      return;
    }
    try {
      inputConsumer.off('keyPressed', this.onVolumeUp);
      inputConsumer.off('keyPressed', this.onVolumeDown);
      Log.i(TAG, 'volume key interception disabled');
    } catch (error) {
      const e = error as BusinessError;
      Log.w(TAG, `unsubscribe volume key failed: ${e.code} ${e.message}`);
    } finally {
      // 无论 off 是否抛错都复位：下一次 enable 必须能重新订阅。
      this.subscribed = false;
    }
  }

  private notifyReader(method: string): void {
    const channel = this.channel;
    if (channel == null) {
      return;
    }
    channel.invokeMethod(method, null, {
      success: (): void => {},
      error: (code: string, message: string): void => {
        Log.w(TAG, `${method} failed: ${code} ${message}`);
      },
      notImplemented: (): void => {},
    });
  }
}
