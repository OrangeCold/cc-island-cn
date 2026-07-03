# 非刘海屏收起态展示「正在执行的工具」

- 日期：2026-07-02
- 状态：设计稿（待实现）
- 类型：新功能（UI 层）

## 背景与动机

cc-island-cn 在刘海屏 MacBook 上，收起态中间区域被物理刘海覆盖，视觉无缝。但在**没有物理刘海的屏幕**（外接显示器、老款 MacBook）上，收起态中间是一块按刘海宽度渲染的空白占位矩形（透明或纯黑），因没有物理黑条遮挡，用户看到的是一条「中间空洞」的悬浮横条。

当前应用在非刘海屏上即使无活动也强制保持可见（`hasPhysicalNotch == false` 时 `isVisible` 永远为 true），作为可悬停 / 点击的交互入口，但这块中间空白未被利用。

本功能在不破坏刘海屏现有体验的前提下，把非刘海屏收起态的中间空白用于展示**当前正在执行的工具调用**（如 `Read · NotchView.swift`、`Bash · npm test`、`Grep · notchScale`），让用户不展开灵动岛也能一眼看到 Claude Code 正在做什么。

## 目标

- 非刘海屏收起态中间区域，在有 running / 待审批工具时，显示一行「工具名 · 关键参数」。
- 复用现有数据（`chatItems` 里的 `ToolCallItem`）与文案逻辑（`inputPreview`、`MCPToolFormatter`），不新增数据流。
- 刘海屏体验完全不变（中间被物理刘海盖住）。

## 非目标

- 不做轮播 / 多命令列表（只显示最近一个）。
- 不改造展开态、会话列表、权限审批 UI。
- 不加设置开关（非刘海屏自动启用）。
- 不改窗口层级、点击穿越、命中区域逻辑。

## 产品决策（已确认）

| 决策点 | 选择 |
|--------|------|
| 展示形态 | 当前单个 running 工具，单行「工具名 · 关键参数」 |
| 退化（无 running 工具） | 工具完成后停留 ~2 秒再淡出，之后留空（避免快速工具一闪而过） |
| 待审批工具（waitingForApproval） | 也显示，与 running 同格式 |
| 多会话 | 取最近开始的那一个，不轮播 |
| 适用屏幕 | 仅 `!hasPhysicalNotch`（刘海屏不变） |
| 设置开关 | 不加（YAGNI） |

## 现状分析（接入点）

收起态由 `NotchView.headerRow`（`UI/Views/NotchView.swift:254-313`）的三段式 `HStack` 渲染：

- 左：螃蟹图标 + 可选待审批指示（`showClosedActivity` 时）
- 中（`NotchView.swift:272-286`）：
  - `status == .opened` → `openedHeaderContent`
  - `!showClosedActivity` → 透明 `Rectangle`（`width = closedNotchSize.width - 20*scale`）
  - `else`（有活动）→ 纯黑 `Rectangle`（`width = closedNotchSize.width - cornerRadiusInsets.closed.top*scale (+ bounce)`）← **本次改动点**
- 右：spinner / 对勾（`showClosedActivity` 时）

数据已就绪：

- `NotchView` 持有 `@StateObject sessionMonitor = ClaudeSessionMonitor()`，`sessionMonitor.instances: [SessionState]` 即所有会话。
- `SessionState.chatItems: [ChatHistoryItem]`（`Models/SessionState.swift:34`），`ChatHistoryItem.type` 含 `.toolCall(ToolCallItem)`（`Services/Chat/ChatHistoryManager.swift:124`）。
- `ToolCallItem`（`ChatHistoryManager.swift:130`）含 `name`、`input: [String:String]`、`status: ToolStatus`；`status == .running` / `.waitingForApproval`（`ChatHistoryManager.swift:202-232`）。
- `PreToolUse` hook 触发时 `SessionStore.processToolTracking` 已在 `chatItems` 插入 `status == .running` 的占位项；`PostToolUse` / JSONL `.toolCompleted` 时改为 `.success`。UI 自动随 `@Published` 刷新。
- 文案现成：`ToolCallItem.inputPreview`（`ChatHistoryManager.swift:153`，按 `file_path → command 首行 → pattern → query → url` 优先级返回关键参数）；`MCPToolFormatter.formatToolName(_:)` 美化工具名（MCP 工具去 `mcp__` 前缀等）。
- 物理刘海判定：`NSScreen.hasPhysicalNotch`（`Core/Ext+NSScreen.swift:50`，`safeAreaInsets.top > 0`）；`NotchViewModel.hasPhysicalNotch: Bool`（`let`，构造时定死）。

## 设计方案

### 1. 数据层：纯计算属性（零新状态）

**`SessionState.currentRunningTool`**（`Models/SessionState.swift`，新增计算属性）：

```swift
/// 当前正在执行 / 待审批的工具（chatItems 里最后一个 running 或 waitingForApproval 的 ToolCallItem）。
/// 跨会话聚合时由调用方比较各会话最近活动时间取最新。
var currentRunningTool: ToolCallItem? {
    for item in chatItems.reversed() {
        if case .toolCall(let tool) = item.type,
           tool.status == .running || tool.status == .waitingForApproval {
            return tool
        }
    }
    return nil
}
```

> 把 `.waitingForApproval` 也纳入（用户决策「待审批也显示」）。单会话内取最后一个（chatItems 按时间顺序追加，最后一个即最近开始的）。

**`NotchView.currentRunningTool`**（新增私有计算属性，跨会话聚合）：

遍历 `sessionMonitor.instances`，取「最近开始」的那一个。比较依据：优先用 `session.toolTracker.inProgress` 中最大的 `ToolInProgress.startTime`；若该字典为空（极端：占位项已插入但 tracker 未同步），回退为「`instances` 里第一个命中 session 的当前工具」。

> `ToolCallItem` 自身无时间戳，「最近开始」靠 `toolTracker.inProgress`（`Models/SessionState.swift` 的 `ToolTracker` / `ToolInProgress`，含 `startTime`）。实现时以 `toolTracker.inProgress` 排序为准。

### 2. UI 层：`ClosedToolLabel` + 显示窗口管理

**新建 `ClosedToolDisplayState`**（`UI/Components/ClosedToolDisplayState.swift`，`@MainActor` `ObservableObject`）：管理中间区域显示窗口。`update(running:)` 由 NotchView 在 `currentRunningTool` 变化及 `onAppear` 时调用——`running` 非空则实时跟随并清空完成态；`running` 变空且当前仍有展示工具时，进入 ~2 秒停留窗口，到期后清空。停留期内若有新 `running` 进入，自动重置窗口切换到新工具。

**新建 `ClosedToolLabel: View`**（`UI/Components/ClosedToolLabel.swift`）：

```swift
struct ClosedToolLabel: View {
    let tool: ToolCallItem

    var body: some View {
        let name = MCPToolFormatter.formatToolName(tool.name)
        let preview = tool.inputPreview
        let text = preview.isEmpty ? name : "\(name) · \(preview)"
        return Text(text)
            .font(.system(size: 11, weight: .medium))      // 起点值，实现时与螃蟹图标/spinner 视觉量级对齐
            .foregroundStyle(.white.opacity(0.78))
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
```

**修改 `NotchView.headerRow` 中间分支**（`NotchView.swift:281-286`）：

```swift
} else {  // Closed with activity
    if !viewModel.hasPhysicalNotch, let tool = effectiveClosedTool {
        // effectiveClosedTool = currentRunningTool ?? closedDisplay.displayedTool
        ClosedToolLabel(tool: tool)
            .frame(width: 中间可用宽度)   // closedNotchSize.width 减去左右图标位与 padding
            .transition(.opacity)
    } else {
        // 维持现状：刘海屏（被物理刘海盖住）/ 无 running 工具且不在停留窗口（留空）
        Rectangle()
            .fill(.black)
            .frame(width: closedNotchSize.width
                   - cornerRadiusInsets.closed.top * viewModel.notchScale
                   + (isBouncing ? 16 : 0))
    }
}
```

中间可用宽度 = `closedNotchSize.width - 左侧图标宽 - 右侧 spinner 宽 - 水平 padding`（与现有 `expansionWidth` / `sideWidth` 计算保持一致风格）。

### 3. 文案与样式

- 文案：`{formatToolName(name)} · {inputPreview}`；`inputPreview` 为空时仅显示工具名。
- 例：
  - Read → `Read · NotchView.swift`
  - Bash → `Bash · npm test`（command 首行；过长由 `.truncationMode(.tail)` 截断）
  - Grep → `Grep · notchScale`
  - WebSearch → `WebSearch · <query>`
  - MCP 工具 → 经 `MCPToolFormatter` 美化（如 `Server · Tool`）
- 待审批工具与 running 同格式（不额外加前缀；右侧橙色 `PermissionIndicatorIcon` 已区分状态）。
- 不引入需要本地化的固定文案：工具名是英文术语，参数是用户数据 / 路径。若后续加入「正在执行…」之类固定中文，须走 `Localizable.xcstrings`。

## 边界行为

| 场景 | 行为 |
|------|------|
| 非刘海屏 + 有 running 工具 | 中间显示 `工具 · 参数` |
| 非刘海屏 + 待审批工具 | 中间显示该工具（同格式）+ 右侧橙色图标 |
| 非刘海屏 + 工具刚完成（~2 秒内） | 中间继续显示该工具摘要，2 秒后淡出留空 |
| 非刘海屏 + processing 但无 running 工具（模型思考中 / 停留窗口外） | 维持黑 spacer，中间留空 |
| 非刘海屏 + 空闲 / 已完成（waitingForInput） | 维持黑 spacer，中间留空 |
| 多会话同时有 running 工具 | 取最近开始的那一个 |
| 刘海屏（任意状态） | 永远走 spacer 分支，无变化 |
| `status == .opened` | 走 `openedHeaderContent`，中间分支不触发 |

## 不改动的内容

- 窗口行为：`NotchWindow.ignoresMouseEvents`、`level`、collectionBehavior、点击穿越、`repostClickAt`。
- 命中区域：`NotchViewController` 的 hit-test rect（中间放文字不影响左右图标与整体可点击区；文字本身不响应点击——收起态本就点击穿透 / 悬停展开）。
- 左右两侧组件：螃蟹图标、`ProcessingSpinner`、`ReadyForInputIndicatorIcon`、`PermissionIndicatorIcon`。
- `showClosedActivity` / `isAnyProcessing` 等判定。
- 数据流：`SessionStore.process(_:)`、socket、JSONL 解析。
- 尺寸计算：`scaledNotchSize`、`notchScale`、`expansionWidth`。

## 测试与验证

仓库无测试套件。以下为可选纯逻辑单测点（仓库尚未建立测试基建，标「可选」）：

- `SessionState.currentRunningTool`：给定含多个 toolCall 的 chatItems，返回最后一个 running / waitingForApproval 的 ToolCallItem；无则 nil。
- `NotchView` 跨会话聚合：给定多 session，返回 `toolTracker.inProgress.startTime` 最大的那个。

**功能验证**（必须，依赖本机 Claude Code CLI + 活跃会话）：

1. 在非刘海屏（外接显示器或老款 Mac）上运行 app。
2. 触发一个 Claude Code 会话执行工具（Read / Edit / Bash / Grep），观察收起态中间显示对应 `工具 · 参数`，并随工具切换实时变化。
3. 触发需要审批的工具，确认中间显示该工具 + 右侧橙色图标。
4. 会话空闲 / 思考中时，确认中间回到空白。
5. 在刘海屏 MacBook 主屏上重复，确认中间仍被物理刘海盖住、行为不变。
6. 多会话同时跑工具，确认中间始终显示最近开始的那个。

## 发版

按 `CLAUDE.md`：实现完成后，更新 `CHANGELOG.md`（新增条目记本功能），bump `MARKETING_VERSION` 与 `CURRENT_PROJECT_VERSION`（build +1），再打 tag 触发 CI。

## 触及文件清单

| 文件 | 改动 |
|------|------|
| `CcIslandCn/Models/SessionState.swift` | 新增 `currentRunningTool` 计算属性 |
| `CcIslandCn/UI/Components/ClosedToolLabel.swift` | **新建** 子视图 |
| `CcIslandCn/UI/Components/ClosedToolDisplayState.swift` | **新建** 显示窗口管理（@MainActor ObservableObject） |
| `CcIslandCn/UI/Views/NotchView.swift` | 新增 `currentRunningTool` / `effectiveClosedTool`；改 `headerRow` 中间分支条件渲染；接入 `closedDisplay`（onAppear/onChange 同步 + opacity 过渡） |
| `CcIslandCn.xcodeproj` | 工程用 `PBXFileSystemSynchronizedRootGroup`，新文件自动纳入，无需手动编辑 |
| `CHANGELOG.md` | 发版时追加条目 |
