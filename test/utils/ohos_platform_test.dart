import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kira/utils/app_update.dart';
import 'package:kira/utils/ohos_platform.dart';

/// 鸿蒙判断必须用字符串而不是 `Platform.isOhos` / `TargetPlatform.ohos`：
/// 后两者只有 CPF-Flutter 的鸿蒙 SDK 才有，本仓库的 Android / Windows
/// 发布构建跑官方 Flutter，写死会编译失败。
void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  group('isOhosPlatform', () {
    test('官方 SDK 的六个平台都不算鸿蒙', () {
      for (final platform in [
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.fuchsia,
        TargetPlatform.linux,
        TargetPlatform.macOS,
        TargetPlatform.windows,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(
          isOhosPlatform(),
          isFalse,
          reason: '$platform must not be treated as HarmonyOS',
        );
      }
    });

    test('测试宿主默认平台不是鸿蒙', () {
      expect(defaultTargetPlatform, isNot(TargetPlatform.ohos));
      expect(isOhosPlatform(), isFalse);
    });
  });

  group('安装包平台识别', () {
    test('.hap 后缀识别为鸿蒙，不会被其它规则抢走', () {
      // 文件名里同时含 ohos/arm64，平台判定必须只落在 ohos 上。
      expect(
        AppUpdateService.detectPlatform(
          'kira-1.7.6+630-ohos-arm64-unsigned.hap',
        ),
        AssetPlatform.ohos,
      );
      expect(
        AppUpdateService.detectPlatform('Kira-v1.0.0-OHOS-arm64.HAP'),
        AssetPlatform.ohos,
      );
    });

    test('带 ohos/harmony 字样但非 .hap 后缀也识别为鸿蒙', () {
      expect(
        AppUpdateService.detectPlatform('kira-1.7.6-harmony.zip'),
        AssetPlatform.ohos,
      );
    });

    test('其它平台判定保持不变', () {
      final cases = {
        'kira-1.7.6-arm64-v8a.apk': AssetPlatform.android,
        'kira-1.7.6-windows.exe': AssetPlatform.windows,
        'kira-1.7.6-macos.dmg': AssetPlatform.macos,
        'kira-1.7.6-linux.AppImage': AssetPlatform.linux,
        'kira-1.7.6-ios.ipa': AssetPlatform.ios,
        'kira-1.7.6-unknown.bin': AssetPlatform.unknown,
      };
      for (final MapEntry(key: name, value: expected) in cases.entries) {
        expect(
          AppUpdateService.detectPlatform(name),
          expected,
          reason: 'unexpected platform for $name',
        );
      }
    });

    test('鸿蒙平台的标签与图标已登记', () {
      expect(AssetPlatform.ohos.label, 'HarmonyOS');
      expect(AssetPlatform.ohos.index, lessThan(AssetPlatform.web.index));
    });
  });

  group('isBetaChannelSupported', () {
    test('非鸿蒙的桌面测试宿主不支持 beta', () {
      // flutter_test 把 defaultTargetPlatform 固定成 android，但宿主是
      // Windows：deviceAndroidAbi() 依赖 Platform.isAndroid，于是返回 false。
      // 这条同时覆盖「isOhosPlatform() 为假」的分支。
      expect(isOhosPlatform(), isFalse);
      expect(isBetaChannelSupported(), isFalse);
    });
  });
}
