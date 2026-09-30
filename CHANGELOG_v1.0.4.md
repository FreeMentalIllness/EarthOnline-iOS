# iOS 端变更记录

## v1.0.4（首版，与三端对齐）

数据契约：
- 备份文件 `earth-online-backup.json`，字段 `version / exportedAt / profile / tasks / memos / items / achievements / collections / locations / activities`，全部 camelCase；
- 导入严格按主键合并（`recordId == id` 命中即更新，未命中才插入），不做整包覆盖；
- 兼容 Web 内部的 `{ state: {...} }` 与 Android 的裸字段两种包装；
- `locations` 同时支持 `tagsJson` 与 `tags` 数组两种写法。

功能：
- 主页：问候语、等级卡（周岁 / XP / 距下一生日进度）、六宫格速览、世界日志速记、人生时间轴（自动里程碑 + 自定义）、最近动态（可设条数）；
- 任务：主线 / 支线 / ToDo 三分类，隐藏已完成，详情可改状态与进度，到期本地提醒，左滑删除；
- 背包：物品 / 收藏夹双 Tab，自定义分类管理，分类删除后条目回落「未分类」，全字段搜索；
- 成就：任务 / 背包 / 收藏 / 足迹 / 日志 / 成长 / 综合 / 彩蛋 / 自定义 9 类，规则与 Android 同名同 key，彩蛋未解锁打码，支持手动成就；
- 数据看板：概览九宫格、XP 来源明细、近 7 天日志柱状图、任务分布（全 0 走空状态）；
- 足迹地图：系统 MapKit 打点（可选切高德），经纬度录入 / 当前定位 / 标签 / 备注；
- AI 助手：兼容 OpenAI `/v1/chat/completions`，快捷提示词，接口地址与密钥只存本机；
- 设置：主题、壁纸与不透明度、通知、隐藏已完成、动态条数、自定义称号、WebDAV 同步（测试 / 拉取 / 推送 / 自动同步）、备份导出导入、清空数据、关于。

iOS 专属：
- WidgetKit 小组件（systemSmall / systemMedium）：未启用 App Group 时降级为静态卡片 + 深链；
- 灵动岛 / 锁屏实时活动（ActivityKit）：由 App 进程推送数据，无需任何特殊授权；
- App Intents：写世界日志、新建任务、今日战报，含「快捷指令」短语。

工程与 CI：
- 零第三方依赖（WebDAV 自建 URLSession 实现），xcodegen 生成工程；
- GitHub Actions / Codemagic 双流水线，产出未签名 ipa 并自动校验无限制性 Entitlements；
- 默认 Entitlements 为空，避免 SideStore 自签名失败；提供 `nowidget` 兜底变体。
