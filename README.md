<h1 align="center">
	<img src="assets\ic_launcher.png" style="zoom: 33%;" />
</h1>

<p align="center"><strong>kira 鸿蒙版（HarmonyOS / OpenHarmony）</strong></p>

本分支是 [caolib/kira](https://github.com/caolib/kira) 的鸿蒙 Flutter 移植分支，仓库托管在
[HelloZeroNick/kira](https://github.com/HelloZeroNick/kira) 的 `ohos` 分支。

> [!WARNING]
> 本分支只做一件事：把 kira 客户端适配到鸿蒙。
>
> - 产品功能、界面与行为以 [上游仓库](https://github.com/caolib/kira) 为准，鸿蒙侧不新增产品功能、不改变上游行为；
> - 除鸿蒙平台相关内容（`ohos/` 平台目录与鸿蒙构建产物）之外，其余代码应尽量与上游保持一致，以便后续继续同步上游；
> - 目前仅保证 HarmonyOS 目标可编译、可运行到主要流程（漫画、轻小说）。

## 提 issue 注意事项

- 请先查看[是否已存在类似 issue](https://github.com/HelloZeroNick/kira/issues?q=is%3Aissue)，
  并确保问题属于**鸿蒙版特有问题**（即上游/Android 版本没有该问题）。
- 与鸿蒙无关的功能问题请提到 [上游仓库](https://github.com/caolib/kira)。

## 编译运行

1. 使用鸿蒙 Flutter SDK：[CPF-Flutter/flutter_flutter](https://gitcode.com/CPF-Flutter/flutter_flutter) 的 `oh-3.47.9-dev` 分支，本机 `flutter --version` 为 `3.47.7+ohos-0.0.1-canary`。
2. 安装 DevEco Studio 与 HarmonyOS SDK（本机为 API 26），并把 SDK 路径配置到 `DEVECO_SDK_HOME` 环境变量。
3. 安装依赖并构建 HAP：

   ```sh
   flutter pub get --enforce-lockfile
   flutter build hap --release --target-platform ohos-arm64
   ```

   产物在 `build/ohos/hap/`：`entry-default-signed.hap`（已签名）或 `entry-default-unsigned.hap`（未签名）。`--target-platform` 可选 `ohos-arm64`（默认）、`ohos-arm`、`ohos-x64`。
4. 首次构建前先在 DevEco Studio 中打开 `ohos/` 工程，`File` → `Project Structure` → `Signing Configs` 勾选 `Automatically generate signature`。未配置签名时 `flutter build hap` 会提示「请通过DevEco Studio打开ohos工程后配置调试签名」。`ohos/build-profile.json5` 的 `signingConfigs` 入库时为空数组，签名材料不入库；CI 等无签名材料的环境改用 `flutter build hap --no-codesign`。
5. 运行：`flutter devices` 列出 ohos 设备（ID 形如 `192.168.1.199:46992`）后执行 `flutter run -d <设备ID>`；也可用 `hdc list targets` 查看设备、`hdc install <hap 路径>` 直接安装。

`ohos/local.properties` 由 flutter 自动生成（含 `hwsdk.dir`、`flutter.sdk`、`flutter.versionName`、`flutter.versionCode`），不要手写。不要设置 `PUB_HOSTED_URL`。

## 发布

CI 只构建鸿蒙：推 `v*` tag 或手动触发 `Build HarmonyOS (ohos)` 工作流，构建 arm64 HAP 并创建/更新 GitHub Release，把 `kira-<版本>-ohos-arm64-unsigned.hap` 作为 Release 资产提供（应用内检查更新从这里取包）。CI 产物未签名，安装前需用 DevEco Studio 签名。

<p align="center">
  <img src="https://skills.syvixor.com/api/icons?perline=15&i=flutter,dart,materialdesign,android,windows"/>
</p>

<p align="center">
  <img alt="GitHub License" src="https://img.shields.io/github/license/HelloZeroNick/kira">
  <img alt="GitHub Issues or Pull Requests" src="https://img.shields.io/github/issues/HelloZeroNick/kira">
  <img src="https://img.shields.io/github/stars/HelloZeroNick/kira" alt="Stars"/>
  <img src="https://img.shields.io/github/downloads/HelloZeroNick/kira/latest/total">
  <a href="https://qm.qq.com/q/rezw7xWuK4"><img src="https://img.shields.io/badge/%E4%BA%A4%E6%B5%81%E7%BE%A4-white?logo=QQ" alt="QQ Group"/></a>
</p>

## 简介

一个拷贝漫画、热辣漫画的第三方客户端，支持漫画、轻小说

[![](https://files.seeusercontent.com/2026/11/06/bGa0/20261106180342267.png)](https://kirakira.dpdns.org/)



<details>
  <summary>查看更多截图</summary>
<table>
  <tr>
    <td><img src="https://files.seeusercontent.com/2026/10/26/yPa3/1.jpg"/></td>
    <td><img src="https://files.seeusercontent.com/2026/10/26/hMo3/2.jpg"/></td>
  </tr>
  <tr>
    <td><img src="https://files.seeusercontent.com/2026/10/26/j3jM/3.jpg"/></td>
    <td><img src="https://files.seeusercontent.com/2026/10/26/gMh0/4.jpg"/></td>
  </tr>
</table>
</details>

## 开发

[开发指南](docs/development.md)

## 感谢

- [caolib/kira](https://github.com/caolib/kira) 上游作者
- [CPF-Flutter/flutter_flutter](https://gitcode.com/CPF-Flutter/flutter_flutter) 提供鸿蒙 Flutter SDK
- 所有开发者和贡献者

## 免责声明

> **请在使用本应用前仔细阅读以下声明：**
>
> - 本应用为非官方第三方客户端，仅基于第三方平台提供的接口或公开可访问资源进行内容展示与访问。
> - 本应用不生产、上传、编辑、修改或预先审查具体展示内容，相关内容均来源于第三方返回结果，开发者无法对其进行完全控制。
> - 下载的图片、文字等资源请在下载后 24 小时内自行删除，不得未经授权传播或用于商业用途。
> - 本应用展示的内容中，可能包含成人内容或其他不适宜未成年人浏览的信息；如您未满 18 周岁，或您所在地法律法规禁止访问相关内容，请立即停止使用本应用。
> - 用户应自行判断相关内容是否适合浏览，并确保其使用行为符合所在地法律法规。
> - 如第三方内容存在侵权、违法、违规或其他不当情形，相关责任原则上由内容提供方承担；开发者将在收到有效通知后，根据实际情况采取必要处理措施。
>
> ✅**继续使用本应用，即表示您已阅读、理解并同意上述说明；如您不同意，请立即停止使用并卸载本应用。**
