import 'package:flutter/foundation.dart' show defaultTargetPlatform;

/// 当前是否运行在鸿蒙（HarmonyOS / OpenHarmony）上。
///
/// 刻意用**字符串**判断，而不是 `Platform.isOhos` 或 `TargetPlatform.ohos`：
///
/// - `Platform.isOhos` 只有 CPF-Flutter 的鸿蒙 Dart SDK 才提供，
///   官方 Dart SDK 的 `dart:io` 里没有这个成员；
/// - `TargetPlatform.ohos` 这个枚举值同样只有鸿蒙分支的 Flutter 才有。
///
/// 本仓库的 Android / Windows 发布构建跑的是官方 Flutter（版本见
/// `.flutter-version`），引用上面任意一个都会在官方 SDK 上直接编译失败。
/// 而 `defaultTargetPlatform.toString()` 在两侧都恒存在：鸿蒙运行时给出
/// `"TargetPlatform.ohos"`，官方 SDK 的六个平台永远不等于这个串，于是同一份
/// 源码在官方 SDK 上安全地判定为「非鸿蒙」。
///
/// 注意：`toString()` 依赖类型名，若将来给发布构建加 `--obfuscate`，应改用
/// 不受混淆影响的 `defaultTargetPlatform.name == 'ohos'`（语义等价）。
bool isOhosPlatform() =>
    defaultTargetPlatform.toString() == 'TargetPlatform.ohos';
