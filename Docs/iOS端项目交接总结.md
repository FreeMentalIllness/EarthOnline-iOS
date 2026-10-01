# iOS 端项目交接总结（EarthOnline-iOS）

> 适用：用户新开对话时，将本文件首条消息粘贴给助手，即可无缝衔接。
> 生成时间：2026-10-01。当前版本基线：v1.0.4。状态：云端构建已跑绿，双产物已产出。

---

## 1. 【角色与规则】

### 1.1 本对话角色定义
- 角色：**iOS 端开发与 CI/CD 自动化工程师（跨平台协作模式）**。
- 职责：以 SwiftUI + SwiftData 完整复刻 Web / Android / Windows 三端功能（主页、任务、背包、成就、看板、地图、AI、设置），并实现 iOS 专属能力（WidgetKit 小组件、Live Activities 灵动岛、App Intents 快捷指令）；搭建并托管 GitHub Actions 云端构建，产出未签名 .ipa 供 SideStore / AltStore 自签名安装。
- 工作模式：**全自动推进**，遇阻碍直接给方案并继续，不反问；结论先行，直击重点。
- 输出红线：**严禁展示任何代码片段或代码块**；只展示最终产物（.ipa 路径 / 云端构建状态 / 访问说明）。

### 1.2 全局自定义指令中适用于 iOS 的核心红线
- JSON 字段统一 **camelCase**，与三端保持一致；WebDAV 导入必须**按主键合并**，禁止整包覆盖。
- **地图 Key 与安全密钥仅本地内置，严禁提交到公开仓库**（Secrets.local.xcconfig 已被 gitignore 拦截，未入库）。
- **严禁执行强制推送**（git push -f）或任何重写历史的操作。
- 禁止自动发布 GitHub Release；正式发布须用户手动确认并选择版本，且必须附带 .ipa 产物（或提前告知替代方案）。
- 版本号**严格递增**，当前基线 v1.0.4。
- 禁止引入未经确认的新依赖（iOS 端已定策略：**零第三方 SwiftPM**，WebDAV 用自建 URLSession 客户端，地图默认系统 MapKit）。
- 高风险操作（删移文件 / 改 DB 结构）先列计划待确认；常规代码迭代全自动推进。

### 1.3 iOS 端特殊约束
- **用户无 Mac 环境**：无法本地编译 / 运行 / 抓真机日志，全部依赖 GitHub Actions（macos-15）云端构建。
- **SideStore 自签名约束**：产出的 .ipa 不得包含限制性 Entitlements，且必须保证无 Mac 环境下可云端构建成功（已通过关闭签名实现）。
- **免费 Apple ID 限制**：① App ID 数量有上限；② 自签应用 7 天需续签；③ 无 App Group 能力，Widget 降级为静态卡片（实时数据需付费账号解锁）。
- 仓库为**公开仓库**，任何密钥只能走 GitHub Secrets 或本地回退文件，绝不入库明文。

---

## 2. 【项目现状】

- 项目名称：**EarthOnline-iOS**
- 当前版本号：**v1.0.4**（MARKETING_VERSION=1.0.4，CURRENT_PROJECT_VERSION=1，build 号 1，故 ipa 文件名含 -1）
- 技术栈：**SwiftUI + SwiftData + WidgetKit + Live Activities + App Intents + 高德地图 iOS SDK（MapKit 降级方案）**
- 最低支持 iOS 版本：**17.0**（SwiftData 强制要求，已从最初设想的 iOS 16 主动上调并注明原因）
- 包名 / Bundle ID：**com.example.earthonline**（小组件扩展：com.example.earthonline.EarthOnlineWidgets）
- 当前 CI/CD 方案：**GitHub Actions（主，.github/workflows/ios-build.yml）**；**Codemagic（备选，codemagic.yaml 已就绪）**
- 构建产物名称与路径：
  - 设备包：**EarthOnline-iOS-v1.0.4-1-unsigned.ipa**（约 887KB，未签名，SideStore 用）
  - 模拟器包：**EarthOnline-iOS-Simulator.zip**（约 1.67MB，含 EarthOnline.app，Appetize.io 网页验证用）
  - 本地落盘路径：**D:\AI\app\EarthOnline-Backups\release_out\**
  - 云端仓库产物：GitHub Actions Artifacts（保留 30 天），Artifact 名 EarthOnline-iOS-full / EarthOnline-iOS-nowidget / EarthOnline-iOS-Simulator
- 地图后端开关：**EO_MAP_BACKEND = mapkit**（默认系统 MapKit；置 amap 并注入 AMAP_KEY 后切高德）

---

## 3. 【已完成的工作】

### 3.1 目录结构与文件清单（本地 D:\AI\app\EarthOnline-iOS，共 64 文件）
- 工程生成：project.yml（含 Widget 完整版）、project.nowidget.yml（无小组件降级版，用于装不上的兜底）
- 配置：xcconfig/Common.xcconfig、Debug.xcconfig、Release.xcconfig、Secrets.local.template.xcconfig（密钥模板，不入库）
- 资源：Resources/Assets.xcassets（AppIcon / AccentColor / LaunchBackground）、Resources/Info.template.json（App 元信息唯一权威源，26 键）、Resources/Info.plist（Xcode 自用）、Resources/WidgetInfo.plist、Resources/Entitlements/（EarthOnline.entitlements、EarthOnline.shared.entitlements、EarthOnlineWidget.entitlements）
- 脚本：Scripts/build_unsigned_ipa.sh、Scripts/build_simulator_app.sh、Scripts/verify_ipa.sh
- 源码（39 个 Swift 文件，分目录）：
  - Sources/App：EarthOnlineApp、RootView、OnboardingView、Model/Models、Domain（LifeEngine、XpRules、AchievementCatalog、Enums、AppSettings）、Data（Repository、BackupService、BackupDTO、LocalFileStore）、Net（SyncManager、WebDavClient）、Persist（AppContainer）、Services（AiService、AppSession、LiveActivityManager、NotificationService、WidgetBridge）、Theme（Theme）、Views（Home / Tasks / Backpack / Achievements / Stats / Map / AI / Settings / Discover / Components）
  - Sources/Shared：SharedStore（主 App 与 Widget 共享数据通道）
  - Sources/Widgets：EarthOnlineWidgetBundle（WidgetKit 扩展）
  - Sources/Activities：ActivityAttributes、StatusLiveActivity（灵动岛）
  - Sources/Intents：AppIntents（快捷指令）
- 文档：README.md、CHANGELOG_v1.0.4.md、Docs/SideStore_安装与续签指南.md、Docs/AMap_集成说明.md

### 3.2 已实现的 iOS 专属功能
- **WidgetKit 小组件**：EarthOnlineWidgetBundle，因无 App Group 降级为**静态卡片**（付费账号解锁实时数据）。
- **Live Activities 灵动岛**：ActivityAttributes + StatusLiveActivity + LiveActivityManager，灵动岛开关键 NSSupportsLiveActivities=true。
- **App Intents 快捷指令**：AppIntents.swift，数据操作统一收进 @MainActor / MainActor.run。
- **WebDAV 同步**：SyncManager + WebDavClient（自建 URLSession，PROPFIND / GET / PUT / MKCOL），导入按主键合并。
- **高德地图适配层**：AMapMapView + MapScreen，用 #if canImport(MAMapKit) 整文件包裹；Key 从 Info.plist 读、由 xcconfig / Secrets.local.xcconfig 注入。当前默认 MapKit。

### 3.3 已配置的 CI/CD 工作流
- **GitHub Actions**：.github/workflows/ios-build.yml（macos-15 + setup-xcode latest-stable + brew install xcodegen → build_unsigned_ipa.sh → verify_ipa.sh 校验 Entitlements → upload-artifact；并增量 build_simulator_app.sh → 上传模拟器 zip）。触发方式：workflow_dispatch（可选变体 full / nowidget、是否上传、是否构建模拟器）、push 到 main、pull_request。
- **Codemagic**：codemagic.yaml 已就绪，作为备选云端方案。

### 3.4 已生成的 SideStore 安装与续签指南
- 文档：**Docs/SideStore_安装与续签指南.md**，覆盖 SideStore / AltStore 自签名安装、7 天续签、免费账号限制说明。
- 高德集成说明：**Docs/AMap_集成说明.md**（Key 注入步骤，待用户执行）。

### 3.5 是否已成功云端构建并产出 .ipa
- **是。** 流水线已跑绿（run 36760136348）。产出 EarthOnline-iOS-v1.0.4-1-unsigned.ipa，本地校验通过：含 Payload/EarthOnline.app 主二进制、26 键元信息、含 Widget 扩展 appex、无签名痕迹。已落 D:\AI\app\EarthOnline-Backups\release_out\。

### 3.6 是否已通过 Appetize.io 模拟器验证主流程 UI
- **模拟器包已产出并本地校验通过**（EarthOnline-iOS-Simulator.zip，x86_64+arm64 双架构、CFBundleSupportedPlatforms=iPhoneSimulator、无 PlugIns、zip 顶层 EarthOnline.app/）。Appetize.io 网页端可验证主流程 UI，但网页版**跑不了小组件 / 灵动岛 / WebDAV**，只能验证主界面。

---

## 4. 【已知限制与遗留问题】

### 4.1 环境限制
- 无 Mac 环境，无法本地编译，依赖云端构建（已验证可行）。

### 4.2 免费 Apple ID 限制
- App ID 数量上限；自签应用 7 天续签；Widget 无 App Group 降级为静态卡片（实时数据需付费账号）。

### 4.3 地图方案
- 当前默认 **MapKit 降级**；高德 SDK 适配层已写好，但**未注入 AMAP_KEY**，待用户在 Secrets.local.xcconfig 或 GitHub Secrets(AMAP_KEY) 中提供。

### 4.4 尚未真机验证的项（需用户真机反馈）
- 地图渲染（MapKit 与高德均需真机走查）
- 灵动岛 / Live Activities 实机表现
- Widget 实机刷新与卡片展示
- WebDAV 同步端到端（与三端主键合并语义）
- SwiftData 模型迁移（首装 / 升级场景）
- AI 服务调用链路

### 4.5 其他剩余问题
- 当前**无未解决的 CI 报错、无 Entitlements 冲突**（verify_ipa.sh 已校验通过）。
- 唯一历史阻塞（gh OAuth token 缺 workflow scope，推不动 .github/workflows/*）已通过用户一次 device flow 授权（gh auth refresh -h github.com -s workflow）解决，不再复现。

---

## 5. 【下一步待办】

优先级从高到低：
1. **注入高德 Key（可选）**：若要用高德地图，在 CI 注入 Secrets.AMAP_KEY（workflow 已支持），或本地填 xcconfig/Secrets.local.xcconfig；否则保持 MapKit 默认。参考 Docs/AMap_集成说明.md。
2. **真机验证主流程**：用 SideStore 安装 EarthOnline-iOS-v1.0.4-1-unsigned.ipa，走查地图 / 灵动岛 / Widget / WebDAV 同步 / SwiftData 迁移；首次安装或 Appetize 走查后回报问题。
3. **Appetize.io 网页验证**：上传 EarthOnline-iOS-Simulator.zip 验证主界面 UI（不覆盖真机验证）。
4. **正式发布（待用户下令）**：命中红线——禁止自动 gh release；需用户手动确认版本并选产物；当前可先把 Artifact 作为分发渠道（保留 30 天），或用户决定挂 Release。
5. **付费账号升级（可选）**：如需 Widget 实时数据 / 更长续签，指导用户切付费开发者账号并放宽 Entitlements。

尚未完成的脚本 / 配置：**无**——ipa 与模拟器双链路脚本、yml、文档均已落地并验证。

---

## 6. 【关键文件与路径清单】

本地工程根目录：**D:\AI\app\EarthOnline-iOS**
云端仓库：**https://github.com/FreeMentalIllness/EarthOnline-iOS（公开）**
部署密钥：**C:\Users\FMI\.ssh\id_ed25519_ios**（SSH :22，Write 权限，不入库不外发）
发布产物本地目录：**D:\AI\app\EarthOnline-Backups\release_out\**（含 EarthOnline-iOS-v1.0.4-1-unsigned.ipa 与 EarthOnline-iOS-Simulator.zip）

工程生成与配置：
- D:\AI\app\EarthOnline-iOS\project.yml（含 Widget 完整版）
- D:\AI\app\EarthOnline-iOS\project.nowidget.yml（无小组件降级版）
- D:\AI\app\EarthOnline-iOS\xcconfig\Common.xcconfig（版本与地图后端开关）
- D:\AI\app\EarthOnline-iOS\xcconfig\Secrets.local.template.xcconfig（密钥模板）

资源与元信息：
- D:\AI\app\EarthOnline-iOS\Resources\Info.template.json（App 元信息唯一权威源，26 键）
- D:\AI\app\EarthOnline-iOS\Resources\Info.plist（Xcode 自用）
- D:\AI\app\EarthOnline-iOS\Resources\Entitlements\（EarthOnline / shared / Widget 三份）

构建脚本：
- D:\AI\app\EarthOnline-iOS\Scripts\build_unsigned_ipa.sh（xcodegen 生成 → xcodebuild 关签名 → python3 重写二进制 plist）
- D:\AI\app\EarthOnline-iOS\Scripts\build_simulator_app.sh（模拟器 fat 包 → 剥离 PlugIns 与签名 → ditto 打 zip）
- D:\AI\app\EarthOnline-iOS\Scripts\verify_ipa.sh（校验无限制性 Entitlements）

CI/CD：
- D:\AI\app\EarthOnline-iOS\.github\workflows\ios-build.yml（主，macos-15）
- D:\AI\app\EarthOnline-iOS\codemagic.yaml（备选）

文档：
- D:\AI\app\EarthOnline-iOS\Docs\SideStore_安装与续签指南.md
- D:\AI\app\EarthOnline-iOS\Docs\AMap_集成说明.md
- D:\AI\app\EarthOnline-iOS\README.md
- D:\AI\app\EarthOnline-iOS\CHANGELOG_v1.0.4.md

记忆（供助手跨会话参考）：
- D:\AI\app\.workbuddy\memory\MEMORY.md（含 iOS 端长期约定）
- D:\AI\app\.workbuddy\memory\2026-10-01.md（本轮完整日志，含 gh workflow scope 坑与模拟器适配细节）

---

## 附：新对话首条消息可直接复制的极简版

> 我是「地球Online」iOS 端助手。工程在 D:\AI\app\EarthOnline-iOS，云端仓库 https://github.com/FreeMentalIllness/EarthOnline-iOS（公开，deploy key=id_ed25519_ios）。当前 v1.0.4，技术栈 SwiftUI+SwiftData+WidgetKit+Live Activities+App Intents，最低 iOS 17.0，地图默认 MapKit（高德适配层已写好待注入 AMAP_KEY）。CI 用 GitHub Actions（ios-build.yml）已跑绿，产出 EarthOnline-iOS-v1.0.4-1-unsigned.ipa（落 D:\AI\app\EarthOnline-Backups\release_out\）与 EarthOnline-iOS-Simulator.zip。红线：不展示代码、不强制推送、不自动发 Release、密钥不入库。详细交接见 Docs/iOS端项目交接总结.md。请继续按全自动模式推进。
