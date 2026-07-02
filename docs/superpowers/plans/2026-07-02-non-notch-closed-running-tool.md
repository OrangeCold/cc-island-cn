# 非刘海屏收起态展示「正在执行的工具」实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在非刘海屏收起态中间空白区域显示一行「工具名 · 关键参数」，反映当前 running / 待审批工具。

**Architecture:** 纯 UI 层改动。`SessionState` 加一个 `currentRunningTool` 计算属性（从 `chatItems` 取最后一个 running / waitingForApproval 的 `ToolCallItem`）；`NotchView` 加跨会话聚合属性（按 `lastActivity` 取最近活跃会话的工具）；新建 `ClosedToolLabel` 子视图，在 `headerRow` 中间分支当 `!hasPhysicalNotch && currentRunningTool != nil` 时替换原黑 spacer。数据流不动。

**Tech Stack:** Swift 5 / SwiftUI / AppKit，macOS 15.6+，Xcode 16（文件系统同步工程）。

## Global Constraints

- **平台**：macOS 15.6+，`LSUIElement = YES` accessory 应用，未启用 App Sandbox。
- **验证策略（重要）**：仓库**无测试 target、无 lint**。本计划不建立测试基建（YAGNI，超范围）。每个 Task 的验证 = `xcodebuild` Debug 构建通过 +（UI 改动）手动功能验证。完整功能验证需本机装有 Claude Code CLI 并有活跃会话。
- **构建命令**：`xcodebuild -scheme CcIslandCn -configuration Debug -destination 'generic/platform=macOS' build`
- **工程文件**：项目用 `PBXFileSystemSynchronizedRootGroup`。新建 `.swift` 文件放进 `CcIslandCn/` 子目录即自动纳入 target，**不要手动编辑 `project.pbxproj`**。
- **本地化**：新增 UI 固定文案必须走 `Localizable.xcstrings`。本功能显示的是工具名（英文术语）+ `inputPreview`（用户数据 / 路径），不是固定文案，无需本地化。
- **发版约定**：实现完成后，更新 `CHANGELOG.md`（只记本方独立开发的新增/修复）+ bump `MARKETING_VERSION` 与 `CURRENT_PROJECT_VERSION`（build 每次 +1），再打 tag。未记录的版本不发。
- **当前版本**：`MARKETING_VERSION = 1.4.5`，`CURRENT_PROJECT_VERSION = 13`（`CcIslandCn.xcodeproj/project.pbxproj`）。本计划发版目标：1.4.6 / BUILD 14。
- **并发**：SwiftUI 视图体在 MainActor；计算属性只读，无并发隐患。

---

## 文件结构

| 文件 | 责任 | 操作 |
|------|------|------|
| `CcIslandCn/Models/SessionState.swift` | 加 `currentRunningTool` 计算属性：单会话内取最后一个 running / waitingForApproval 的 `ToolCallItem` | Modify |
| `CcIslandCn/UI/Components/ClosedToolLabel.swift` | 新子视图：把 `ToolCallItem` 渲染成一行 `工具名 · inputPreview`，单行截断 | Create |
| `CcIslandCn/UI/Views/NotchView.swift` | 加 `currentRunningTool` 跨会话聚合属性；改 `headerRow` 中间分支条件渲染 | Modify |
| `CHANGELOG.md` | 发版时追加 1.4.6 条目 | Modify（Task 5） |

---

### Task 1: `SessionState.currentRunningTool` 计算属性

**Files:**
- Modify: `CcIslandCn/Models/SessionState.swift`（在现有计算属性区，`lastUserMessageDate` 附近）

**Interfaces:**
- Consumes: `SessionState.chatItems: [ChatHistoryItem]`（同文件 `:34`）；`ChatHistoryItemType.toolCall(ToolCallItem)`（`Services/Chat/ChatHistoryManager.swift:124`）；`ToolCallItem.status: ToolStatus`（`.running` / `.waitingForApproval`，`Services/Chat/ChatHistoryManager.swift:202-232`）。同 target 同 module，无需 import。
- Produces: `var currentRunningTool: ToolCallItem?` —— 后续 Task 3 的聚合属性依赖此名。

- [ ] **Step 1: 阅读现有计算属性区，确定插入点**

Run: `grep -n "var lastUserMessageDate\|var displayTitle\|MARK: -" CcIslandCn/Models/SessionState.swift | head`
Expected: 看到 `:178` 附近的 `var lastUserMessageDate` 等计算属性，与 `// MARK:` 分组。把新属性插入到某个 `MARK` 分组末尾（如时间/状态相关区）。

- [ ] **Step 2: 添加计算属性**

在 `SessionState` 内插入（建议放在 `lastUserMessageDate` 等计算属性附近）：

```swift
/// 当前正在执行 / 待审批的工具：chatItems 里最后一个 running 或 waitingForApproval 的 ToolCallItem。
/// 跨会话聚合时由调用方按 `lastActivity` 取最近活跃会话。
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

- [ ] **Step 3: 构建验证**

Run: `xcodebuild -scheme CcIslandCn -configuration Debug -destination 'generic/platform=macOS' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`。若报 `ToolCallItem` / `ChatHistoryItem` 未识别，确认文件在 `CcIslandCn/` target 内（应自动可见）。

- [ ] **Step 4: Commit**

```bash
git add CcIslandCn/Models/SessionState.swift
git commit -m "feat: SessionState 增加 currentRunningTool 计算属性"
```

---

### Task 2: `ClosedToolLabel` 子视图

**Files:**
- Create: `CcIslandCn/UI/Components/ClosedToolLabel.swift`

**Interfaces:**
- Consumes: `ToolCallItem`（`Services/Chat/ChatHistoryManager.swift:130`，含 `name: String`、`input: [String:String]`、`inputPreview: String`）；`MCPToolFormatter.formatToolName(_ toolId: String) -> String`（`static func`，`Utilities/MCPToolFormatter.swift:45`）。
- Produces: `struct ClosedToolLabel: View`，init `init(tool: ToolCallItem)` —— Task 3 使用。

- [ ] **Step 1: 新建文件**

创建 `CcIslandCn/UI/Components/ClosedToolLabel.swift`：

```swift
//
//  ClosedToolLabel.swift
//  CcIslandCn
//
//  收起态中间区域：把当前 running / 待审批工具渲染成一行「工具名 · 关键参数」。
//  仅用于非刘海屏（刘海屏中间被物理刘海盖住，不触发）。
//

import SwiftUI

struct ClosedToolLabel: View {
    let tool: ToolCallItem

    var body: some View {
        let name = MCPToolFormatter.formatToolName(tool.name)
        let preview = tool.inputPreview
        let text = preview.isEmpty ? name : "\(name) · \(preview)"
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.white.opacity(0.78))
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
```

- [ ] **Step 2: 确认文件已纳入 target（文件系统同步）**

Run: `ls CcIslandCn/UI/Components/ClosedToolLabel.swift`
Expected: 文件存在。工程用 `PBXFileSystemSynchronizedRootGroup`，无需编辑 `project.pbxproj`。

- [ ] **Step 3: 构建验证**

Run: `xcodebuild -scheme CcIslandCn -configuration Debug -destination 'generic/platform=macOS' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`。此时新视图尚未被任何地方引用，构建通过即说明类型/签名正确。

- [ ] **Step 4: Commit**

```bash
git add CcIslandCn/UI/Components/ClosedToolLabel.swift
git commit -m "feat: 新增 ClosedToolLabel 子视图"
```

---

### Task 3: `NotchView` 聚合属性 + 中间分支条件渲染

**Files:**
- Modify: `CcIslandCn/UI/Views/NotchView.swift` —— 加聚合属性；改 `headerRow` 中间分支（`:281-286`）。

**Interfaces:**
- Consumes: Task 1 的 `SessionState.currentRunningTool`；Task 2 的 `ClosedToolLabel`；`sessionMonitor.instances: [SessionState]`（同文件 `:24`）；`SessionState.lastActivity: Date`（`Models/SessionState.swift:58`）；`viewModel.hasPhysicalNotch: Bool`（同文件已用，如 `:201`）；`closedNotchSize`、`cornerRadiusInsets`、`viewModel.notchScale`、`isBouncing`（同文件已用）。
- Produces: 无新对外接口（私有属性 + 内部渲染改动）。

- [ ] **Step 1: 添加跨会话聚合属性**

在 `NotchView` 内（`hasWaitingForInput`、`isAnyProcessing` 等私有计算属性附近，约 `:40-70` 区间）插入：

```swift
/// 跨所有会话取「最近活跃」且当前有 running / 待审批工具的那个工具。
/// 用于非刘海屏收起态中间区域展示。多会话不轮播，只取最近一个。
private var currentRunningTool: ToolCallItem? {
    sessionMonitor.instances
        .filter { $0.currentRunningTool != nil }
        .max(by: { $0.lastActivity < $1.lastActivity })?
        .currentRunningTool
}
```

- [ ] **Step 2: 阅读中间分支现状**

Run: `sed -n '276,286p' CcIslandCn/UI/Views/NotchView.swift`
Expected: 看到 `} else if !showClosedActivity {`（透明 Rectangle 分支）与 `} else {`（黑 spacer 分支，`:281-286`）。本次只改 `} else {` 分支。

- [ ] **Step 3: 改造中间分支（黑 spacer 分支）**

将 `NotchView.swift:281-286` 的：

```swift
            } else {
                // Closed with activity: black spacer (with optional bounce)
                Rectangle()
                    .fill(.black)
                    .frame(width: closedNotchSize.width - cornerRadiusInsets.closed.top * viewModel.notchScale + (isBouncing ? 16 : 0))
            }
```

替换为：

```swift
            } else {
                // Closed with activity
                if !viewModel.hasPhysicalNotch, let tool = currentRunningTool {
                    // 非刘海屏：中间展示当前工具摘要（刘海屏此处被物理刘海盖住，走 spacer）
                    ClosedToolLabel(tool: tool)
                        .frame(width: closedNotchSize.width - cornerRadiusInsets.closed.top * viewModel.notchScale + (isBouncing ? 16 : 0))
                } else {
                    // 刘海屏 / 无 running 工具：维持原黑 spacer
                    Rectangle()
                        .fill(.black)
                        .frame(width: closedNotchSize.width - cornerRadiusInsets.closed.top * viewModel.notchScale + (isBouncing ? 16 : 0))
                }
            }
```

> 说明：`ClosedToolLabel` 内部 `maxWidth: .infinity` + `lineLimit(1)` + `truncationMode(.tail)`，外层 `frame(width:)` 与原 spacer 同宽，保证收起态总宽度与左右图标位不变，不影响命中区域。

- [ ] **Step 4: 构建验证**

Run: `xcodebuild -scheme CcIslandCn -configuration Debug -destination 'generic/platform=macOS' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`。

- [ ] **Step 5: Commit**

```bash
git add CcIslandCn/UI/Views/NotchView.swift
git commit -m "feat: 非刘海屏收起态中间展示正在执行的工具"
```

---

### Task 4: 手动功能验证（验证 gate，不改代码）

**Files:** 无改动。

**前提**：本机已装 Claude Code CLI，且 `cc-island-cn` 已按 hook 安装约定把 `claude-island-state.py` 注册到 `~/.claude/hooks/`（应用启动时 `HookInstaller.installIfNeeded` 自动处理）。需一台非刘海屏（外接显示器或老款 MacBook），以及（如可得）一台刘海屏 MacBook 验证回归。

- [ ] **Step 1: 启动 app**

在 Xcode 中 Run（`open CcIslandCn.xcodeproj` 后 ⌘R），或构建产物直接双击。app 出现在菜单栏刘海 / 非刘海屏顶部。

- [ ] **Step 2: 非刘海屏 + running 工具**

在 Claude Code 会话里触发工具（如让 Claude 读一个文件、跑 `git status`、grep 一个词）。观察灵动岛收起态中间显示：
- `Read · <文件名>`
- `Bash · <command 首行>`
- `Grep · <pattern>`

Expected: 文字随工具切换实时变化；单行超出尾部截断；左右螃蟹图标与 spinner 不受影响。

- [ ] **Step 3: 非刘海屏 + 待审批工具**

触发一个需要审批的工具（如修改 `settings.json` 外的文件，或首次 Bash 命令按配置需审批）。
Expected: 中间显示该待审批工具摘要（同格式）+ 右侧橙色 `PermissionIndicatorIcon`。

- [ ] **Step 4: 非刘海屏 + 无 running 工具**

会话空闲，或模型正在生成文本（思考中、未调用工具）。
Expected: 中间回到空白黑 spacer（与改动前一致）。

- [ ] **Step 5: 多会话**

同时开两个 Claude Code 会话并都触发工具。
Expected: 中间始终显示 `lastActivity` 最近那个会话的当前工具（不轮播）。

- [ ] **Step 6: 刘海屏回归**

若有刘海屏 MacBook，把 app 切到该屏（或主屏即刘海屏）。
Expected: 收起态中间仍被物理刘海盖住，行为与改动前完全一致；不出现文字错位/穿透异常。

- [ ] **Step 7: 点击穿越与悬停展开回归**

非刘海屏收起态：鼠标悬停应正常 1 秒后展开；点击应正常穿透到下层（`repostClickAt`）。
Expected: 中间放文字未破坏点击穿越与悬停展开。

> 若任一步骤不符合预期，回到对应 Task 修正后再验证。全部通过后再进入 Task 5。

---

### Task 5: 发版准备（CHANGELOG + 版本 bump）

**Files:**
- Modify: `CcIslandCn.xcodeproj/project.pbxproj`（两处 `MARKETING_VERSION` + 两处 `CURRENT_PROJECT_VERSION`，Debug/Release 各一对）
- Modify: `CHANGELOG.md`

> 注意：实际打 tag / push 由用户决定时机，本 Task 只把仓库准备好。`MARKETING_VERSION` 与 `CURRENT_PROJECT_VERSION` 在 `project.pbxproj` 中各出现 2 次（Debug config + Release config），共 4 处需同步。

- [ ] **Step 1: bump 版本**

把 `project.pbxproj` 中所有 `MARKETING_VERSION = 1.4.5;` 改为 `MARKETING_VERSION = 1.4.6;`，所有 `CURRENT_PROJECT_VERSION = 13;` 改为 `CURRENT_PROJECT_VERSION = 14;`。

Run: `grep -n "MARKETING_VERSION\|CURRENT_PROJECT_VERSION" CcIslandCn.xcodeproj/project.pbxproj`
Expected: 改后看到 4 行，两处 `1.4.6`、两处 `14`。

- [ ] **Step 2: 构建验证版本号生效**

Run: `xcodebuild -scheme CcIslandCn -configuration Debug -destination 'generic/platform=macOS' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`。

- [ ] **Step 3: 追加 CHANGELOG**

在 `CHANGELOG.md` 顶部（最新版本区）按既有格式追加 1.4.6 条目，例如：

```markdown
## 1.4.6 (BUILD 14)

### 新增
- 非刘海屏（外接显示器 / 老款 MacBook）收起态中间区域展示当前正在执行的工具摘要（如 `Read · 文件名`、`Bash · 命令`、`Grep · 关键词`）；刘海屏体验不变。
```

（实际文案以仓库 `CHANGELOG.md` 既有风格为准，只记本方独立开发的新增。）

- [ ] **Step 4: Commit**

```bash
git add CcIslandCn.xcodeproj/project.pbxproj CHANGELOG.md
git commit -m "chore: 升版本到 1.4.6 (BUILD 14)"
```

- [ ] **Step 5: 交由用户打 tag 发版（不在本计划内自动执行）**

提示用户：版本已准备好，确认后执行 `git tag v1.4.6 && git push origin v1.4.6` 触发 CI（公证 + DMG + Sparkle appcast）。

---

## Self-Review

**1. Spec coverage：**
- 展示形态「工具名 · 关键参数」→ Task 2 `ClosedToolLabel`。✓
- 数据层 `SessionState.currentRunningTool` → Task 1。✓
- 跨会话聚合取最近 → Task 3 聚合属性（用 `lastActivity`，优于 spec 初步设想的 `inProgress.startTime`，因 `lastActivity` 同时覆盖 waitingForApproval）。✓
- UI 中间分支条件渲染 → Task 3 Step 3。✓
- 退化（无工具留空）→ Task 3 `else` 分支维持 spacer。✓
- 待审批同格式 → Task 1 把 `.waitingForApproval` 纳入；Task 4 Step 3 验证。✓
- 刘海屏不变 → Task 3 `!viewModel.hasPhysicalNotch` 守卫；Task 4 Step 6 回归。✓
- 不加设置开关 → 计划无设置项。✓
- 不改窗口/命中/数据流 → 计划仅改视图体计算属性与中间分支渲染。✓
- 文案无固定本地化串 → Global Constraints 说明。✓
- CHANGELOG + 版本 bump → Task 5。✓

**2. Placeholder scan：** 无 TBD / TODO / "适当处理"。CHANGELOG 文案给了具体示例并注明以既有风格为准（属合理指引，非占位）。✓

**3. Type consistency：** `currentRunningTool: ToolCallItem?` 在 Task 1（`SessionState`）与 Task 3（`NotchView`，私有同名）一致；`ClosedToolLabel(tool: ToolCallItem)` 在 Task 2 定义、Task 3 使用一致；`formatToolName(_:)`、`inputPreview`、`lastActivity`、`hasPhysicalNotch` 均已对照源码确认。✓

**4. 无测试 target 处理：** Global Constraints 已声明验证策略，每个 Task 用构建 + 手动验证替代单测，未超范围建测试基建。✓
