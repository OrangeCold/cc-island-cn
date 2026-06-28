# 变更日志

cc-island-cn 基于 [vibe-notch](https://github.com/farouqaldori/vibe-notch)（Apache-2.0）二次开发。本文件记录**本方独立开发的新增功能与重要修复**，不含从上游选择性同步的 bug fix。

> 与原版的整体差异概览见 [README.md](README.md#与原版-vibe-notch-的差异)；上游同步的运维记录见 [上游同步手册.md](上游同步手册.md)。

## [1.4.5] - 2026-06-28

### 修复
- **多屏下点击屏幕其他位置鼠标向下偏移**：展开灵动岛后点击面板外部时，应用会用 `CGEvent` 把这次点击重投递给下层窗口。坐标翻转此前误用 `NSScreen.main`（key window 所在屏）的高度，而 `NSEvent.mouseLocation` 与 CGEvent 坐标都锚定主屏（带菜单栏的 `screens[0]`）；多屏下面板失焦后 `NSScreen.main` 漂到外接屏，翻转高度取错，导致重投递点击向下偏移（偏移量 = 错用屏与主屏的高度差）。改为统一取主屏高度，`repostClickAt` 与 `repostMouseEvent` 两处同步修正。

## [1.4.4] - 2026-06-27

### 修复
- **会话列表支持 `/rename` 自定义标题**：Claude Code 新版 `/rename` 改用 `{type:"custom-title"}` 行存储会话名（不再写入 `type:"summary"` 行）；`ConversationParser` 此前只解析 summary 行，导致用户手动命名的会话在灵动岛列表显示不出自定义名。新增 `customTitle` 字段解析 custom-title 行，`displayTitle` 优先级改为「自定义标题 > 摘要 > 首条用户消息 > 目录名」。

## [1.4.3] - 2026-06-26

### 新增
- **灵动岛收起态大小可调**：设置页外观区新增 60%–150% 连续缩放滑块，配行内 1:1 真实预览，拖动即持久化。
- 收起态小条按 `notchScale` 等比缩放；命中区域（`hitTestRect`）与刘海几何判断随缩放尺寸联动。

### 修复
- 记录「刘海屏机型收起态调大后可能不可见」的已知限制。

## [1.4.2] - 2026-06-20

### 新增
- **收起态「部分完成」角标**：多会话并行、部分已进入等待输入（waitingForInput）时，spinner 右上角叠加绿色对勾角标，无需展开即可知进度。
- 会话列表图标按钮新增本地化悬浮提示（tooltip）。
- 聊天输入框 placeholder 接入本地化。

### 修复
- Release DMG 启用 create-dmg 拖拽布局，提供 Applications 快捷方式。

## [1.4.1] - 2026-06-20

### 修复
- **状态机修复**：recap / 后台 subagent 完成时，不再误把已停止的会话重新拉回「运行中」状态。

## [1.4.0] - 2026-06-19

### 新增
- **中英双语国际化**：基于 String Catalog 搭建本地化骨架，新增 `zh-Hans` 区域；原版仅英文。
- **设置页语言切换**：新增 `AppLanguage`（系统默认 / 简体中文 / English），切换后重启 App 生效。
- 全量 `zh-Hans` 翻译：设置菜单、ChatView、ToolResultViews。
- 菜单文案改用 `LocalizedStringKey`，确保语言切换后正确重载。

### 修复
- CI 签名链路：archive 改用 Manual signing + 显式 Developer ID Application；用 shell 选择最新 Xcode 替换失效的第三方 action。

## [1.3.2] - 2026-06-19（二次开发起点）

### 变更
- **工程重塑**：统一工程名为 `CcIslandCn`，启用独立 Bundle ID（`com.celestial.CcIslandCn`）与发布渠道。

### 移除
- **彻底移除 Mixpanel 埋点**：原版 vibe-notch 内置的用户数据上报在二次开发时完全移除，cc-island-cn 不收集任何用户数据。

### 新增
- **GitHub Actions 全自动发版**：push `v*` tag 即自动完成 构建 / 公证 / DMG / Sparkle 签名 / 发布 Release / 回推 appcast。
- **Sparkle 自动更新**：独立 EdDSA 签名密钥；自定义 `NotchUserDriver` 将更新交互融入灵动岛 UI 而非系统弹窗。
- README 中文化，新增上游同步手册（记录上游同步基线与 cherry-pick 流程）。
