<p align="center">
  <img src="assets/ic_launcher.png" width="120" alt="Kira"/>
</p>

<h1 align="center">Kira · 鸿蒙版</h1>

<p align="center">拷贝漫画、热辣漫画的第三方客户端，同时支持轻小说</p>

<p align="center">
  <img alt="GitHub License" src="https://img.shields.io/github/license/HelloZeroNick/kira">
  <img alt="GitHub Issues or Pull Requests" src="https://img.shields.io/github/issues/HelloZeroNick/kira">
  <img src="https://img.shields.io/github/stars/HelloZeroNick/kira" alt="Stars"/>
  <img src="https://img.shields.io/github/downloads/HelloZeroNick/kira/latest/total">
  <a href="https://qm.qq.com/q/rezw7xWuK4"><img src="https://img.shields.io/badge/%E4%BA%A4%E6%B5%81%E7%BE%A4-white?logo=QQ" alt="QQ Group"/></a>
</p>

<p align="center">
  <a href="https://github.com/HelloZeroNick/kira/releases/latest"><strong>⬇️ 下载鸿蒙版（.hap）</strong></a>
</p>

> **本项目是非官方第三方客户端，与漫画平台无关联。** 请先阅读应用内的免责声明再使用。
>
> 本仓库是 [caolib/kira](https://github.com/caolib/kira) 的鸿蒙移植分支；产品功能与上游一致，鸿蒙侧只做平台适配。

## 特色

- **漫画 + 轻小说**：一个应用读完两种内容，各自独立的书架与阅读器。
- **阅读体验可调**：翻页 / 滚动、连续阅读、长按放大、自动滚动；小说可调字号、行距、段距、字体与阅读主题。
- **离线可用**：漫画按章节、小说按分卷下载到本地。
- **进度不丢**：自动记录阅读位置，随时从上次的地方继续。
- **隐私优先**：账号与偏好保存在本机；备份支持本地文件或你自己的 WebDAV，并可加密。
- **自带 AI 配置**：接入你自己的 AI 服务，用于章节总结等辅助功能。

## 功能

**漫画**

- 首页推荐、分类浏览、排行榜（总榜 / 男生 / 女生 / 主题 / 作者）
- 搜索、详情、章节列表与评论区
- 阅读器：翻页 / 滚动模式、连续阅读、长按放大、自动滚动、亮度与留白调节
- 收藏到书架、阅读进度续读、书签、浏览历史
- 下载到本地离线阅读，支持批量下载与下载中心管理

**轻小说**

- 独立的小说首页、书架、搜索与分类筛选
- 阅读器：字号 / 行距 / 段距 / 正文宽度 / 字体，阅读主题（纸张 / 夜间 / 白底 / 护眼绿 / 灰，可自定义配色）
- 仿真翻页、专注模式、阅读时屏幕常亮
- 收藏、书签、阅读记录，分卷离线下载

**通用**

- 深色模式、多套主题配色、可更换应用图标
- 阅读统计（阅读时长与达成情况）
- 备份与恢复：本地文件或 WebDAV，支持备份加密
- 通知中心、日志导出、镜像源选择

## 截图

[![](https://files.seeusercontent.com/2026/11/06/bGa0/20261106180342267.png)](https://kira.caolib.qzz.io/)

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

## 下载与安装

在 [Releases](https://github.com/HelloZeroNick/kira/releases/latest) 下载最新的
`kira-<版本>-ohos-arm64-unsigned.hap`（仅 arm64）。

CI 产物为 **release 模式、未签名** 的 HAP（不持有签名材料），无法直接安装到正式设备。
需要用 DevEco Studio 打开 `ohos/` 工程完成签名，再执行：

```sh
hdc install <hap 路径>
```

## 开发

开发和构建说明集中在次级文档：

- [鸿蒙开发指南](docs/harmonyos.md) —— 鸿蒙环境、HAP 构建、签名、调试、CI 与常见问题
- [开发指南](docs/development.md) —— 通用开发约定
- [架构说明](docs/architecture.md)、[轻小说](docs/novel.md)、[组件](docs/widgets.md)、
  [持久化与缓存](docs/persistence-and-cache.md)、[平台构建](docs/platform-build.md)

## 反馈

- 鸿蒙版特有问题 → [HelloZeroNick/kira/issues](https://github.com/HelloZeroNick/kira/issues)
- 与鸿蒙无关的功能问题 → [上游 caolib/kira](https://github.com/caolib/kira/issues)

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
