# 开发指南

本仓库是 [caolib/kira](https://github.com/caolib/kira) 的鸿蒙移植分支（[HelloZeroNick/kira](https://github.com/HelloZeroNick/kira) 的 `ohos` 分支），Android/Windows 相关说明沿用上游。

## 环境

- Flutter（Android/Windows 主目标）：版本见 [`.flutter-version`](../.flutter-version)，自带 Dart SDK
- Java 17
- 鸿蒙构建另用鸿蒙 Flutter SDK：[CPF-Flutter/flutter_flutter](https://gitcode.com/CPF-Flutter/flutter_flutter) 的 `oh-3.47.9-dev` 分支（本机 `flutter --version` 为 `3.47.7+ohos-0.0.1-canary`），并安装 DevEco Studio + HarmonyOS SDK（本机为 API 26），SDK 路径配置到 `DEVECO_SDK_HOME`。

## 获取代码

```sh
git clone -b ohos https://github.com/HelloZeroNick/kira.git
cd kira
```

## 安装依赖

```sh
flutter pub get --enforce-lockfile
```

依赖固定从 pub.dev 下载，不要设置 `PUB_HOSTED_URL`。不要直接运行 `flutter pub get`，它会重新解析依赖并改写 `pubspec.lock`。

## 调试运行

Android 首次调试或执行 `flutter clean` 后，先构建一次：

```sh
flutter build apk --debug
```

启动应用：

```sh
flutter run -d <设备ID>
```

## 鸿蒙构建

鸿蒙平台的构建、签名、调试、CI 与常见问题单独成文，见 [鸿蒙开发指南](harmonyos.md)。

## 发布

CI 只构建鸿蒙，发布流程见 [鸿蒙开发指南](harmonyos.md) 的「发布」一节。发布内容的人工确认仍走项目 [`/release` skill](../.claude/skills/release/SKILL.md)。

[`release.json` 发布清单](release-manifest.md) 协议与脚本仍在仓库中，但当前没有工作流会生成它。
