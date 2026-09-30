# SideStore 安装与续签指南（Windows → iPhone 全流程）

适用产物：`EarthOnline-iOS-v1.0.4-*-unsigned.ipa`（未签名，需由 SideStore 用你的 Apple ID 现场签名）

---

## 0. 前置条件

- iPhone / iPad 已安装 SideStore，且完成过 **配对文件（pairing file）+ StosVPN** 的初始化；
- 电脑只为首次安装 SideStore 时使用，之后 installing / refresh 全程在手机上完成；
- 免费 Apple ID 两条固有上限心里有数：
  - 同一 Apple ID 名下**同时最多约 3 个**（不同机器/不同版本的说法略有差异，按最少算）自签应用；
  - 签名有效期 **7 天**，到期必须刷新。

## 1. 在 Windows 上下载云端构建出的 ipa

两种方式任选其一：

**方式 A（推荐，Artifact）**

1. 打开仓库 → Actions → 找到成功的 `iOS 未签名 ipa 构建` 运行；
2. 页面底部 Artifacts 区下载 `EarthOnline-iOS-full`（若含扩展装不上则改用 `EarthOnline-iOS-nowidget`）；
3. 解压得到 `EarthOnline-iOS-v1.0.4-1-unsigned.ipa`。

**方式 B（Release 附件）**

1. 进入仓库 Releases → 找到 iOS 版本 → Assets 里的 `.ipa`；
2. 下载到任意目录即可。

把 ipa 弄到手机上的三种路子（哪种顺手用哪种）：

- 存到 iCloud Drive / 网盘 App（如 OneDrive、坚果云），在 iPhone 上打开同一 App → 分享 → SideStore；
- 微信/QQ 发给「文件传输助手」，手机端点开 → 用 SideStore 打开；
- USB 连接 + iTunes 文件共享，把 ipa 放进 SideStore 的文件区。

## 2. 用 SideStore 安装

1. 打开 **StosVPN**，确认本地 VPN 已连接（SideStore 靠它与本机签名服务通信，不要断）；
2. 打开 SideStore → My Apps → 右上角 `+`；
3. 选择刚才传到手机的 `.ipa`；
4. 首次安装时若弹出「是否保留 App 扩展（使用主配置文件）」——**选保留**（每个扩展会额外占用一个 App ID 名额，换来小组件与灵动岛）；
5. 等待签名 + 安装完成。回到桌面即可看到「地球Online」。

装不上时的处理顺序（一次只改一个变量）：

1. 优先换 `nowidget` 变体（无扩展版），排除「扩展占名额」导致的失败；
2. 删掉一个不再用的自签应用，腾出 App ID 名额；
3. 检查 StosVPN 是否在位、飞行模式是否关闭；
4. 仍然失败 → 重新登录 SideStore 的 Apple ID（开了双重验证就用 App 专用密码）；
5. 最后手段：重启手机后重试一次，很多时候第二次就过。

## 3. 七天续签（别等弹窗）

手动：每 5~6 天做一次 —— 连上 StosVPN → 打开 SideStore → My Apps → Refresh Apps。**过期后不是刷新就能恢复的，App 会打不开，只能重装**（重装会丢本地未同步的数据，所以下面的同步务必开）。

半自动（省心）：用「快捷指令」建个人自动化：

1. 快捷指令 → 自动化 → 新建 → 选「特定时间」，比如每天上午 8:00；
2. 动作选 **Refresh Apps**（SideStore 提供的动作）；
3. 关闭「运行前询问」；
4. 注意：自动化执行时 **StosVPN 必须在位**，否则会失败。建议同时保留每周一次手动确认的习惯。

## 4. 数据安全提醒（很重要）

- iOS 端默认开启了「切后台推送」：一旦你在「设置 → WebDAV 同步」填好服务器，本地数据会同步到 `earth-online-backup.json`，和 Web / Android / Windows 共用同一条链路，**重装/续签失败都不会丢数据**；
- 没配 WebDAV 时，也可以「设置 → 导出备份」把 JSON 落到「文件 App → EarthOnline」目录，用 iTunes/访达拷到电脑；
- 清空数据会同时要求 WebDAV 下次自动拉取被跳过一次，避免刚删完又被云端数据拉回来。

## 5. 已知取舍

- **桌面小组件**：默认没有 App Group 授权，组件显示静态卡片（点击可唤起 App）。想要实时数据就得启用 App Group，免费账号大概率拿不到对应授权，因此默认关闭。
- **灵动岛实时活动**：完全可用，由 App 进程推送数据，不依赖任何特殊授权。
- **推送通知**：侧载应用拿不到远程推送；本端的到期提醒走**本地通知**，同样能在锁定中和横幅出现。
