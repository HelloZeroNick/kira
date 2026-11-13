# 鸿蒙开发指南

本仓库是 [caolib/kira](https://github.com/caolib/kira) 的鸿蒙 Flutter 移植分支，仓库托管在
[HelloZeroNick/kira](https://github.com/HelloZeroNick/kira) 的 `ohos` 分支（当前为默认分支）。

面向构建、修改和调试鸿蒙版本的开发者。用户使用说明见 [README](../README.md)，通用开发规范见
[development.md](development.md)。

> [!WARNING]
> 本分支只做一件事：把 kira 客户端适配到鸿蒙。
>
> - 产品功能、界面与行为以 [上游仓库](https://github.com/caolib/kira) 为准，鸿蒙侧不新增产品功能、不改变上游行为；
> - 除鸿蒙平台相关内容（`ohos/` 平台目录与鸿蒙构建产物）之外，其余代码应尽量与上游保持一致，以便后续继续同步上游；
> - 目前仅保证 HarmonyOS 目标可编译、可运行到主要流程（漫画、轻小说）。

## 环境

| 项 | 说明 |
| --- | --- |
| 鸿蒙 Flutter SDK | [CPF-Flutter/flutter_flutter](https://gitcode.com/CPF-Flutter/flutter_flutter) 的 `oh-3.47.9-dev` 分支（本机 `flutter --version` 为 `3.47.7+ohos-0.0.1-canary`） |
| DevEco Studio | 用于打开 `ohos/` 工程、配置签名、安装调试 |
| HarmonyOS SDK | 本机为 API 26；SDK 路径配置到 `DEVECO_SDK_HOME` |
| Java | 17（CI 与本地一致） |

Android / Windows 主目标仍使用 `.flutter-version` 指向的官方 Flutter，两套 SDK 并存、互不影响。

## 安装依赖

```sh
flutter pub get --enforce-lockfile
```

依赖源固定为 pub.dev，**不要设置 `PUB_HOSTED_URL`**：`pubspec.lock` 里的 hosted 依赖都钉在
`https://pub.dev`，指向镜像会让每个条目都对不上，`--enforce-lockfile` 直接失败。

鸿蒙相关的依赖是 gitcode 上的 CPF-Flutter fork（`shared_preferences`、`path_provider`、
`url_launcher`、`flutter_inappwebview`、`sqflite`、`package_info_plus`、`share_plus`、
`connectivity_plus_ohos`、`permission_handler_ohos`、`wakelock_plus_ohos`、
`flutter_foreground_task`、`cryptography_flutter`、`flex_color_picker` 等），已在 `pubspec.yaml`
里按分支固定，不要手工改回 pub 版本。

## 构建 HAP

首次构建前先用 DevEco Studio 打开 `ohos/` 工程，`File` → `Project Structure` →
`Signing Configs` 勾选 `Automatically generate signature`。未配置签名时 `flutter build hap`
会提示「请通过DevEco Studio打开ohos工程后配置调试签名」。

```sh
flutter build hap --release --target-platform ohos-arm64
```

- `--target-platform` 可选 `ohos-arm64`（默认）、`ohos-arm`、`ohos-x64`。
- 无签名材料的环境（如 CI）加 `--no-codesign`，产物为 unsigned。
- 产物在 `build/ohos/hap/`：`entry-default-signed.hap` 或 `entry-default-unsigned.hap`；
  Hvigor 的原始输出在 `ohos/entry/build/default/outputs/default/` 下同名。

`ohos/build-profile.json5` 的 `signingConfigs` 入库时为空数组，**签名材料不入库**；
`ohos/local.properties` 由 flutter 自动生成（含 `hwsdk.dir`、`flutter.sdk`、
`flutter.versionName`、`flutter.versionCode`），不要手写。

## 运行与调试

```sh
flutter devices                       # 列出设备，ohos 设备 ID 形如 192.168.1.199:46992
flutter run -d <设备ID>
```

```sh
hdc list targets                      # 查看设备
hdc install <hap 路径>                 # 安装已签名的 HAP
hdc hilog                             # 查看设备日志（-x 非阻塞扫一遍）
```

`.vscode/tasks.json` 里已提供对应的 `ohos:` 任务（devices / build release / build debug /
run / install / hilog / clean），`.vscode/launch.json` 里有 `Debug - OHOS` 与 `Profile - OHOS`
调试配置，需要先填设备 ID。

## 通知中心

应用内「检查更新」指向 `HelloZeroNick/kira` 的 Release；「通知中心」仍走上游
`cdn.caolib.qzz.io` 的公告源，不随本仓库改动 —— 那是上游统一维护的内容，与谁发安装包无关。

## 常见问题

| 现象 | 处理 |
| --- | --- |
| `flutter pub get --enforce-lockfile` 报 `Unable to satisfy pubspec.yaml using pubspec.lock` | 检查是否设置了 `PUB_HOSTED_URL` 或 `FLUTTER_STORAGE_BASE_URL`，清掉后重试 |
| `Parse ohos module.json5 error: Can not found module.json5 at <pub 缓存>/<插件>/ohos/...` | 本机 pub 缓存里该插件的 `ohos/` 源码被删（多半是 `flutter clean` 或缓存清理留下的），`git -C <该缓存目录> checkout -- .` 恢复 |
| `请通过DevEco Studio打开ohos工程后配置调试签名` | 见上文「构建 HAP」的签名步骤 |
| `hdc install` 报 `error: failed to install bundle. code:9568320 error: no signature file` | 装的是 unsigned HAP，先签名 |
| CI 报 `ld.lld: error while loading shared libraries: libxml2.so.2` | runner 镜像必须是 `ubuntu-24.04`；Ubuntu 25.10+ 把 libxml2 的 soname 换成 `.so.16`，SDK 自带的 `ld.lld` 仍要 `.so.2` |

## 发布

CI 只构建鸿蒙（`.github/workflows/ohos.yml`），不再有 Android / Windows 的 Actions 构建：

- 推 `v*` tag：构建 arm64 HAP，并创建/更新对应 GitHub Release，上传
  `kira-<pubspec 版本>-ohos-arm64-unsigned.hap`。资产名必须带 `+<build>` 构建号 ——
  `lib/utils/app_update.dart` 的 `_parseVersionFromName` 依赖它比较新旧版本。
- 手动 dispatch：`tag_name` 留空只产出 Actions artifact；填了版本号才创建 Release。

CI 以 `--no-codesign` 构建，产物未签名，安装或分发前需用 DevEco Studio 完成签名。
发布内容的人工确认仍走项目 [`/release` skill](../.claude/skills/release/SKILL.md)。

[`release.json` 发布清单](release-manifest.md) 协议与脚本仍在仓库中，但当前没有工作流会生成它。

## 提 issue 注意事项

- 请先查看[是否已存在类似 issue](https://github.com/HelloZeroNick/kira/issues?q=is%3Aissue)，
  并确保问题属于**鸿蒙版特有问题**（即上游 / Android 版本没有该问题）。
- 与鸿蒙无关的功能问题请提到 [上游仓库](https://github.com/caolib/kira)。
