# EarthOnline iOS 端

地球Online 的第四端，与 Web / Android / Windows 共用同一份数据契约 `earth-online-backup.json`。

- 版本基线：**v1.0.4**（四端统一，AppDelegate/bundleVersion 由 xcconfig 的 MARKETING_VERSION=1.0.4 / CURRENT_PROJECT_VERSION=1 驱动）
- Bundle ID：`com.example.earthonline`；小组件扩展：`com.example.earthonline.EarthOnlineWidgets`
- 展示名：`地球Online`
- URL Scheme：`earthonline://`（home / tasks / backpack / achievements / map / stats / ai / settings）

---

## 一、工程结构

| 目录 / 文件 | 作用 |
| --- | --- |
| `project.yml` | xcodegen 工程描述（主 App + 小组件扩展） |
| `project.nowidget.yml` | 变体：只有主 App，无 Extension（SideStore 安装失败时的兜底） |
| `xcconfig/` | 编译设置：Common / Debug / Release；Secrets.local.xcconfig 存放本地高德 Key（不入库） |
| `Resources/` | Info.plist、WidgetInfo.plist、Entitlements、Assets.xcassets |
| `Sources/App/EarthOnlineApp.swift` | 入口，`@main` |
| `Sources/App/Views/` | UI：主页 / 任务 / 背包 / 成就 / 数据看板 / 足迹地图 / AI / 设置 / 引导 |
| `Sources/App/Model/` | SwiftData 模型（ProfileItem / TaskItem / MemoItem / BagItem / AchievementItem / CollectionItem / LocationPin / ActivityItem / BagCategoryItem / XpEventItem） |
| `Sources/App/Data/` | Repository（读写）、BackupDTO（备份契约）、BackupService（导出/按主键导入合并）、LocalFileStore |
| `Sources/App/Net/` | WebDavClient（URLSession 实现）、SyncManager（先拉后推） |
| `Sources/App/Domain/` | AppSettings、XpRules、AchievementCatalog、LifeEngine、Enums/DateUtils |
| `Sources/App/Services/` | AppSession（依赖总线）、NotificationService、AiService、WidgetBridge、LiveActivityManager |
| `Sources/Shared/` | 主 App 与小组件共用的快照结构（尽力而为的 App Group 读写） |
| `Sources/Widgets/` | WidgetBundle + 状态小组件 |
| `Sources/Activities/` | ActivityAttributes + 灵动岛/锁屏实时活动 UI |
| `Sources/Intents/` | App Intents（写日志 / 新建任务 / 今日战报）+ 快捷指令短语 |
| `Scripts/` | build_unsigned_ipa.sh、verify_ipa.sh |
| `.github/workflows/ios-build.yml` | GitHub Actions：macOS 云端构建未签名 ipa |
| `codemagic.yaml` | Codemagic 备选流水线 |
| `Docs/` | SideStore 安装与续签指南、高德 SDK 集成说明 |

## 二、数据契约（不可违背）

备份文件 `earth-online-backup.json`，字段命名全 camelCase，与 Android `BackupRepository.Payload` / Web `backup.js` 一一对齐：

`version`、`exportedAt`、`profile`、`tasks`、`memos`、`items`、`achievements`、`collections`、`locations`、`activities`

两条硬规则：

1. **导入按主键合并**（`model.recordId == dto.id` 命中即更新字段，未命中才插入），永不整包覆盖。
2. 兼容两种包装：Web 内部的 `{ state: {...} }` 与 Android 的裸字段格式，均能识别。
   （注意：`id` 是 SwiftData `PersistentModel` 保留的可识别主键，实体里统一使用 `recordId` 存放业务主键。）

## 三、本地构建（需要 Mac）

```bash
brew install xcodegen
xcodegen generate --spec project.yml
open EarthOnline.xcodeproj
```

无 Mac 时走云端构建：推送到 GitHub 即触发 Actions，产物为 **未签名 ipa**，下载后用 SideStore 自签名安装。

## 四、为什么这样取舍（与原始需求的偏差，逐条说明）

1. **最低系统 iOS 17 而非 iOS 16**：SwiftData 是 iOS 17 才有的框架，iOS 16 上无法使用。二选一时优先保证技术栈统一（SwiftUI + SwiftData）。若将来必须支持 iOS 16，需要把持久层降级为 Core Data，工作量集中在 Model/Repository 两层。
2. **WebDAV 用 URLSession 自建最小实现，不引 SwiftPM 第三方包**：Cloudinary/Nuxeo 那类 WebDAV 包维护活跃度参差，且引入后 CI 需要联网拉包、失败面变大。当前实现覆盖 PROPFIND / GET / PUT / MKCOL，与 Android WebDavService 一一对应，零外部依赖，云端构建必然可复现。
3. **高德 SDK 走"可选集成"而非 SwiftPM**：高德 iOS SDK 官方目前只提供 .framework 包与 CocoaPods 分发，没有官方 SwiftPM 源（社区存在非官方适配，且老版本 MAMapKit 无 modulemap，需桥接）。因此默认用系统 **MapKit**（零依赖、免 Key、侧载可用），高德适配层已写好（`Views/Map/AMapMapView.swift`，整文件由 `#if canImport(MAMapKit)` 包住），集成后把 Info.plist 的 `EO_MAP_BACKEND` 改成 `amap` 即自动切换。Key 只从 Info.plist 读取，由本地 `Secrets.local.xcconfig` 注入，仓库无明文。详见 `Docs/AMap_集成说明.md`。
4. **默认不带任何 Entitlements**：App Group / iCloud / Push / HealthKit 都不启用，规避 SideStore 自签名失败。代价是桌面小组件读不到实时数据，会展示静态卡片 + 深链回 App（README 与组件 UI 上都说清楚）。可选 App Group 授权文件已备好在 `Resources/Entitlements/EarthOnline.shared.entitlements`，启用方法写在文件注释里。
5. **Live Activity（灵动岛）不受影响**：实时活动的数据由 App 进程主动 push，天然读到最新内容，是本方案下体验最完整的 iOS 专属能力。
6. **ATS 与文件共享**：`NSAllowsArbitraryLoads = YES`（自建 http WebDAV 与自定义 AI 接口地址需要），`UIFileSharingEnabled = YES`（可在「文件 App」里直接取出备份 JSON）。仅上架 App Store 时需按实际情况收紧。

## 五、产物

云端构建产物命名：`EarthOnline-iOS-v1.0.4-<build>-unsigned.ipa`
下载方式见 `Docs/SideStore_安装与续签指南.md`。
