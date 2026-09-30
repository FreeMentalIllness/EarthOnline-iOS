# 高德地图 iOS SDK 集成说明

## 现状：默认走系统 MapKit

默认后端是 **系统 MapKit**：

- 零第三方依赖，云端 CI 必然可复现；
- 不需要任何 Key，也没有沉睡签名问题；
- 侧载环境下地图、标注、缩放全部正常。

切换开关在 Info.plist：`EO_MAP_BACKEND`（`mapkit` / `amap`）。

## 为什么默认没有用 SwiftPM 引入高德

高德官方 **目前只提供 .framework 包和 CocoaPods 分发**，没有官方 SwiftPM 源。社区存在非官方适配，而且老版本 `MAMapKit` 不带 `module.modulemap`，直接 SwiftPM 接入时无法被 Swift 正确 import，必须额外配桥接头与 linker flags。因此对"云端无人值守构建"来说，把地图依赖做成**可选项**是更稳的选择。

## 想切到高德，怎么做

1. 到 lbs.amap.com 控制台创建 iOS 应用，拿到 **新版 Key**（V2.3.0 起必须用新版 Key）；
2. 下载 **基础包 AMapFoundationKit** + **3D 地图 MAMapKit**（两者都要，缺一会初始化失败）；
3. 二选一集成：
   - 手动：把两个 framework 拖进工程 → Build Settings 里加 `CoreLocation / CoreTelephony / QuartzCore / Security / SystemConfiguration` 与 `libc++ / libz`；若 framework 无 modulemap，加 Objective-C 桥接头 import 对应头文件；
   - CocoaPods：`pod 'AMapLocation'` 之类沿用官方 podspec，注意 CocoaPods 会改变 CI 构建流程（需跑 pod install 并改用 .xcworkspace）；
4. 把 Info.plist 的 `EO_MAP_BACKEND` 改成 `amap`；
5. Key 注入（**严禁写进仓库**）：
   ```bash
   cp xcconfig/Secrets.local.template.xcconfig xcconfig/Secrets.local.xcconfig
   # 在该文件里写：AMAP_KEY = 你的key
   ```
   `Secrets.local.xcconfig` 已被 .gitignore 忽略；CI 如需用 amap 后端，在 GitHub 仓库 Settings → Secrets 里配 `AMAP_KEY`，工作流会自动写入同名文件。
6. 代码侧无需改动：`Views/Map/AMapMapView.swift` 整文件由 `#if canImport(MAMapKit)` 包住，集成后自动进入编译。

## 运行时注意事项（与 Android 端踩过的坑一致）

- 顺序必须是：**先声明隐私合规，再创建地图视图**，否则白屏：
  `updatePrivacyShow(.didShow, privacyInfo: .didContain)` → `updatePrivacyAgree(.didAgree)` → 才 setKey / 建图。
- Key 为空时不要调用 setKey，否则控制台会刷无效鉴权日志。
- Info.plist 里已配置 `NSLocationWhenInUseUsageDescription`；如需定位，务必先在设置里授权。
