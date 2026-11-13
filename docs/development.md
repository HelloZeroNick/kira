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

移动端首次调试或执行 `flutter clean` 后，先构建一次：

```sh
flutter build apk --debug
```

启动应用：

```sh
flutter run -d <设备ID>
```

## 鸿蒙构建

首次构建前先用 DevEco Studio 打开 `ohos/` 工程，`File` → `Project Structure` → `Signing Configs` 勾选 `Automatically generate signature`；`ohos/build-profile.json5` 的 `signingConfigs` 入库时为空数组，签名材料不入库。`ohos/local.properties` 由 flutter 自动生成，不要手写。

```sh
flutter build hap --release --target-platform ohos-arm64
```

`--target-platform` 可选 `ohos-arm64`（默认）、`ohos-arm`、`ohos-x64`；无签名材料的环境加 `--no-codesign`。产物在 `build/ohos/hap/`（`entry-default-signed.hap` 或 `entry-default-unsigned.hap`）。设备用 `flutter devices`（ID 形如 `192.168.1.199:46992`）或 `hdc list targets` 查看，安装用 `flutter run -d <设备ID>` 或 `hdc install <hap 路径>`。

## 发布

在 Claude Code 中使用项目 [`/release` skill](../.claude/skills/release/SKILL.md)，先确认版本与渠道、审查更新日志，再批准发布。

正式版 Actions 自动生成 [`release.json` 发布清单](release-manifest.md)，提供全部安装包的下载链接与发布元信息。
