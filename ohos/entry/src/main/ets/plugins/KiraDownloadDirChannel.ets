/*
 * 下载目录通道：`io.github.caolib.kira/download_dir`。
 *
 * `Download/<bundleName>` 这一级目录只能由系统 Picker 创建：应用自己 mkdir 会
 * 直接返回 EPERM（errno=1），因为它挂在 file_manager 名下。文档「DOWNLOAD 模式
 * 保存文件」写明该模式会「自动创建在 Download/包名/目录」，并让返回的 URI 自带
 * 持久化权限，所以这里用它把目录建出来，再把目录路径交给 Dart 侧。
 */
import {
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
  AbilityAware,
  AbilityPluginBinding,
} from '@ohos/flutter_ohos';
import { common, UIAbility } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { picker, fileUri, fileIo } from '@kit.CoreFileKit';
import Log from '@ohos/flutter_ohos/src/main/ets/util/Log';

const TAG = 'KiraDownloadDirChannel';
const CHANNEL = 'io.github.caolib.kira/download_dir';

export default class KiraDownloadDirChannel implements FlutterPlugin, MethodCallHandler, AbilityAware {
  private channel: MethodChannel | null = null;
  private ability: UIAbility | null = null;

  getUniqueClassName(): string {
    return 'KiraDownloadDirChannel';
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL);
    this.channel.setMethodCallHandler(this);
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.channel?.setMethodCallHandler(null);
    this.channel = null;
  }

  onAttachedToAbility(binding: AbilityPluginBinding): void {
    this.ability = binding.getAbility();
  }

  onDetachedFromAbility(): void {
    this.ability = null;
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    switch (call.method) {
      case 'ensureDownloadDirectory':
        this.ensureDownloadDirectory(call, result);
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  private ensureDownloadDirectory(call: MethodCall, result: MethodResult): void {
    const suffix: string = (call.argument('suffix') as string) ?? '';
    const ability = this.ability;
    if (ability === null) {
      result.error('no_ability', 'download dir channel requires a foreground ability', null);
      return;
    }
    const context = ability.context as common.UIAbilityContext;
    const options = new picker.DocumentSaveOptions();
    options.pickerMode = picker.DocumentPickerMode.DOWNLOAD;
    const viewPicker = new picker.DocumentViewPicker(context);
    viewPicker.save(options).then((uris: Array<string>) => {
      if (uris === null || uris.length === 0) {
        result.success('');
        return;
      }
      // DOWNLOAD 模式返回的就是目录 URI（文档示例直接在其后拼 /test.txt），
      // 若拿到的是文件，则取父目录并删掉预置文件。
      let dirUri = uris[0];
      try {
        if (fileIo.statSync(uris[0]).isFile()) {
          dirUri = this.parentUri(uris[0]);
          fileIo.unlinkSync(uris[0]);
        }
      } catch (err) {
        Log.d(TAG, `stat pre-created uri skipped: ${JSON.stringify(err)}`);
      }
      const candidates: Array<string> = this.pathCandidates(dirUri);
      let fallback = '';
      for (const candidate of candidates) {
        const verified = this.verifyWritable(candidate, suffix);
        if (verified.length === 0) continue;
        if (candidate.startsWith('file://')) {
          // fileIo 能写但 dart:io 不能用，只留作兜底日记，继续找路径形式。
          fallback = fallback.length > 0 ? fallback : verified;
          continue;
        }
        result.success(verified);
        return;
      }
      if (fallback.length > 0) {
        Log.w(TAG, `only uri form writable: ${fallback}`);
      } else {
        Log.e(TAG, `no writable path among ${JSON.stringify(candidates)}`);
      }
      result.success('');
    }).catch((err: BusinessError) => {
      Log.e(TAG, `DocumentViewPicker.save failed: ${JSON.stringify(err)}`);
      result.error(`${err.code}`, err.message, null);
    });
  }

  /** `file://docs/.../<bundle>/<file>` → `file://docs/.../<bundle>`。 */
  private parentUri(uri: string): string {
    const index = uri.lastIndexOf('/');
    return index <= 0 ? uri : uri.substring(0, index);
  }

  /**
   * 目录 URI 的候选路径形式。不同设备/版本下公共目录对应用暴露的路径不一致，
   * 这里全部列出，由 [verifyWritable] 实测决定用哪一个。
   */
  private pathCandidates(uri: string): Array<string> {
    const docsPrefix = 'file://docs/';
    const stripped = uri.startsWith(docsPrefix)
      ? uri.substring(docsPrefix.length).replace(/\/+$/, '')
      : '';
    const list: Array<string> = [];
    // 1. 绝对路径：应用沙箱里公共目录挂在 /storage/Users/currentUser/... 下，
    //    dart:io 用绝对路径最稳。
    if (stripped.length > 0) {
      list.push(`/${stripped}`);
    }
    try {
      // 2. FileUri.path：官方给出的「URI → 沙箱路径」转换。
      const sandboxPath = new fileUri.FileUri(uri).path;
      if (sandboxPath.length > 0) {
        list.push(sandboxPath.replace(/\/+$/, ''));
      }
    } catch (err) {
      Log.d(TAG, `FileUri.path failed: ${JSON.stringify(err)}`);
    }
    // 3. 相对路径（无前导斜杠），按进程工作目录解析。
    if (stripped.length > 0) {
      list.push(stripped);
    }
    // 4. 原始 URI，fileIo 能用但 dart:io 不行，仅作可写性佐证。
    list.push(uri);
    return list;
  }

  /**
   * 用 fileIo 在该路径下建子目录并写探针，返回 Dart 可用的路径；
   * 写不进去返回空串。返回 URI 时说明 dart:io 不可用，交由调用方判定。
   */
  private verifyWritable(base: string, suffix: string): string {
    const target = suffix.length > 0 ? `${base}/${suffix}` : base;
    try {
      if (!fileIo.accessSync(target)) {
        fileIo.mkdirSync(target);
      }
      const probe = `${target}/.kira_probe`;
      const file = fileIo.openSync(
        probe,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC
      );
      fileIo.writeSync(file.fd, 'ok');
      fileIo.closeSync(file);
      fileIo.unlinkSync(probe);
      Log.d(TAG, `writable path: ${target}`);
      return target;
    } catch (err) {
      Log.d(TAG, `not writable: ${target} (${JSON.stringify(err)})`);
      return '';
    }
  }
}
