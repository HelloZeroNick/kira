import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 鸿蒙侧「保存位置」只有两种固定选择：应用沙箱（默认）与
/// `Download/<bundleName>/<子目录>` 应用专属目录。
///
/// phone 上拿不到公共目录权限，Picker 返回的文档类 URI 也不能交给 dart:io。
/// `Download/<bundleName>` 这一级只能由系统 Picker 以 DOWNLOAD 模式创建
/// （应用自己 mkdir 返回 EPERM），对应原生 KiraDownloadDirChannel。
class OhosDownloadDirectoryChoice {
  const OhosDownloadDirectoryChoice(this.path);

  /// null 表示沿用应用沙箱内的默认目录。
  final String? path;
}

const _channel = MethodChannel('io.github.caolib.kira/download_dir');

/// `Download/<bundleName>/<suffix>` 相对路径（无前导斜杠）。
Future<String?> ohosDownloadDirectoryPath(String suffix) async {
  final bundle = (await PackageInfo.fromPlatform()).packageName.trim();
  if (bundle.isEmpty) return null;
  return 'storage/Users/currentUser/Download/$bundle/$suffix';
}

/// 让系统 Picker 建出 `Download/<bundleName>/<suffix>` 并授权。
///
/// 返回可直接交给 dart:io 的目录路径；失败返回 null，调用方提示不可写。
Future<String?> ensureOhosDownloadDirectory(String suffix) async {
  try {
    final path = await _channel.invokeMethod<String>(
      'ensureDownloadDirectory',
      {'suffix': suffix},
    );
    // 路径必须落在 Download/<bundle>/ 下，否则宁可回退也不写到公共 Download 根。
    if (path != null && path.contains('/Download/')) {
      return path.startsWith('/') ? path : '/$path';
    }
  } on PlatformException catch (_) {
    return null;
  } on MissingPluginException catch (_) {
    return null;
  }
  return null;
}

/// 弹出二选一对话框；返回 null 表示用户取消。
///
/// `path` 为 null 表示应用内部目录；非 null 时已由原生侧建好并授权。
Future<OhosDownloadDirectoryChoice?> pickOhosDownloadDirectory(
  BuildContext context, {
  required String suffix,
}) async {
  if (!context.mounted) return null;
  final choice = await showDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('选择下载保存目录'),
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
          leading: const Icon(Icons.phone_android_outlined),
          title: const Text('应用内部目录'),
          onTap: () => Navigator.of(ctx).pop(''),
        ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
          leading: const Icon(Icons.folder_outlined),
          title: const Text('Download/kira'),
          onTap: () => Navigator.of(ctx).pop('download'),
        ),
      ],
    ),
  );
  if (choice == null) return null;
  if (choice.isEmpty) return const OhosDownloadDirectoryChoice(null);
  final path = await ensureOhosDownloadDirectory(suffix);
  if (path == null) return null;
  return OhosDownloadDirectoryChoice(path);
}
