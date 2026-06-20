# 灵动岛「部分完成」badge 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 多会话并行、部分已完成时，在灵动岛收起态 spinner 上叠加绿色对勾角标，提示「有会话完成了」。

**Architecture:** 在 `NotchView` 加 2 个派生属性（`hasCompletedSession` / `isPartiallyComplete`），并在 `headerRow` 的 spinner 分支用 `.overlay` 叠加复用的 `ReadyForInputIndicatorIcon` 角标。纯视图层，不改状态机与数据流。

**Tech Stack:** Swift 5 / SwiftUI。

## ⚠️ 设计调整说明（实现约束，执行前请确认）

spec §4.1 原选「spinner + 绿色对勾**并排** badge」。实现阶段发现 `NotchView.headerRow`（行 282-295）的 center 区是**固定宽度** `Rectangle`（行 276-278：`.frame(width: closedNotchSize.width - cornerRadiusInsets.closed.top ...)`）、右侧 spinner 区是固定 `.frame(width: sideWidth)`（行 286）。三者 frame 之和已撑满收起态宽度，**并排**再加 badge 会使 HStack 总宽溢出、布局错位。

故调整为**角标**：badge 用 `.overlay(alignment: .topTrailing)` 叠加在 `ProcessingSpinner` 容器右上角，不占额外水平宽度、零布局侵入。视觉仍是「spinner + 绿色完成标记」，符合「提示部分完成」的核心意图。

若坚持并排，需额外把 center `Rectangle` 的宽度改为动态计算（侵入较大）——执行前告知即可切换。

## Global Constraints

- **平台**：macOS 15.6+，accessory 应用。
- **无测试套件**：UI 状态改动无法单测，用「构建通过 + 手动验证」替代 TDD。
- **构建命令**：`xcodebuild -scheme CcIslandCn -configuration Debug -destination 'generic/platform=macOS' build`。
- **完成口径**：仅 `.waitingForInput` 算完成（`ended`/`idle` 不计入）。
- **仅改 `CcIslandCn/UI/Views/NotchView.swift`**：不改 `SessionPhase`、`SessionStore`、`ClaudeSessionMonitor`、`handleProcessingChange`。
- **提交时机**：遵循用户全局约定「仅在你要求时才 commit」；每个 Task 末尾 commit 步骤为建议节奏。

## File Structure

| 文件 | 责任 | 本次改动 |
|------|------|---------|
| `CcIslandCn/UI/Views/NotchView.swift` | 收起态聚合 + `headerRow` 视觉 | 加 2 个派生属性；spinner 分支叠加完成角标 |

复用既有组件（不改）：`ProcessingSpinner`（`CcIslandCn/UI/Components/ProcessingSpinner.swift`）、`ReadyForInputIndicatorIcon`（`CcIslandCn/UI/Views/NotchHeaderView.swift:134`）。

---

## Task 1: 新增「部分完成」派生属性

**Files:**
- Modify: `CcIslandCn/UI/Views/NotchView.swift:53-57`（`hasWaitingForInput` 闭合处与 `// MARK: - Sizing` 之间）

**Interfaces:**
- Consumes: `isAnyProcessing`（行 33-35，既有）、`sessionMonitor.instances`
- Produces: `hasCompletedSession: Bool`、`isPartiallyComplete: Bool`（供 Task 2 的视觉分支使用）

- [ ] **Step 1: 在 `hasWaitingForInput` 之后插入两个派生属性**

用 Edit，将：
```swift
            return false
        }
    }

    // MARK: - Sizing
```
替换为：
```swift
            return false
        }
    }

    /// 是否存在已完成（waitingForInput）的会话。无时间窗口，持续判定（区别于 hasWaitingForInput 的 30s 窗口）。
    private var hasCompletedSession: Bool {
        sessionMonitor.instances.contains { $0.phase == .waitingForInput }
    }

    /// 部分完成：有会话在跑（processing/compacting）且另有会话已完成（waitingForInput）。
    private var isPartiallyComplete: Bool {
        isAnyProcessing && hasCompletedSession
    }

    // MARK: - Sizing
```

- [ ] **Step 2: 构建确认无编译错误**

Run:
```bash
xcodebuild -scheme CcIslandCn -configuration Debug -destination 'generic/platform=macOS' build 2>&1 | grep -E "BUILD (SUCCEEDED|FAILED)|error:" | head -10
```
Expected: `** BUILD SUCCEEDED **`。此时属性已加但尚未在视图使用，行为无变化。

> SourceKit 单文件分析可能报「Cannot find type 'SessionState'...」等跨文件类型诊断，属误报，以 xcodebuild 结果为准。

- [ ] **Step 3: Commit（按用户意愿）**

```bash
git add CcIslandCn/UI/Views/NotchView.swift
git commit -m "feat(ui): NotchView 增加 hasCompletedSession/isPartiallyComplete 派生属性"
```

---

## Task 2: headerRow spinner 分支叠加完成角标

**Files:**
- Modify: `CcIslandCn/UI/Views/NotchView.swift:283-287`（`if isProcessing || hasPendingPermission` 分支内的 `ProcessingSpinner()` 块）

**Interfaces:**
- Consumes: Task 1 的 `isPartiallyComplete`、既有 `ProcessingSpinner` / `ReadyForInputIndicatorIcon` / `TerminalColors.green`
- Produces: 收起态 spinner 右上角的条件完成角标

依赖：Task 1。

- [ ] **Step 1: 改造 ProcessingSpinner 块，叠加角标 overlay**

用 Edit，将：
```swift
                if isProcessing || hasPendingPermission {
                    ProcessingSpinner()
                        .matchedGeometryEffect(id: "spinner", in: activityNamespace, isSource: showClosedActivity)
                        .frame(width: viewModel.status == .opened ? 20 : sideWidth)
                        .padding(.trailing, viewModel.status == .opened ? 0 : 4)
                }
```
替换为：
```swift
                if isProcessing || hasPendingPermission {
                    ProcessingSpinner()
                        .matchedGeometryEffect(id: "spinner", in: activityNamespace, isSource: showClosedActivity)
                        .frame(width: viewModel.status == .opened ? 20 : sideWidth)
                        .overlay(alignment: .topTrailing) {
                            if isPartiallyComplete {
                                ReadyForInputIndicatorIcon(size: 10, color: TerminalColors.green)
                                    .transition(.scale.combined(with: .opacity))
                                    .offset(x: 4, y: -4)
                            }
                        }
                        .animation(.easeInOut(duration: 0.2), value: isPartiallyComplete)
                        .padding(.trailing, viewModel.status == .opened ? 0 : 4)
                }
```

实现要点：
- `.overlay` 在 `.frame` 之后：角标定位在 spinner 容器（`sideWidth` 宽）的 `topTrailing`，不改变容器尺寸、不影响 `matchedGeometryEffect` 与 center 区布局。
- `if isPartiallyComplete`：角标仅部分完成时出现。
- `.transition(.scale.combined(with: .opacity))` + `.animation(value: isPartiallyComplete)`：角标弹入/淡出。
- `size: 10`、`offset(x: 4, y: -4)`：小号对勾略探出容器右上角，角标感；具体像素在 Task 3 实测微调。

- [ ] **Step 2: 构建确认**

Run:
```bash
xcodebuild -scheme CcIslandCn -configuration Debug -destination 'generic/platform=macOS' build 2>&1 | grep -E "BUILD (SUCCEEDED|FAILED)|error:" | head -10
```
Expected: `** BUILD SUCCEEDED **`。

- [ ] **Step 3: Commit（按用户意愿）**

```bash
git add CcIslandCn/UI/Views/NotchView.swift
git commit -m "feat(ui): 收起态 spinner 叠加部分完成角标"
```

---

## Task 3: 手动验证

依赖：Task 2 完成、app 可运行、本机有多个 Claude Code 会话（至少 1 个 processing + 1 个 waitingForInput）。

- [ ] **Step 1: 构建 Debug 产物并重启 app**

Run:
```bash
xcodebuild -scheme CcIslandCn -configuration Debug -destination 'generic/platform=macOS' build 2>&1 | grep -E "BUILD (SUCCEEDED|FAILED)|error:" | head -3
APP="$(xcodebuild -scheme CcIslandCn -showBuildSettings 2>/dev/null | grep BUILT_PRODUCTS_DIR | head -1 | cut -d= -f2 | xargs)/CcIslandCn.app"
pkill -x CcIslandCn 2>/dev/null; sleep 1; open "$APP"
```
Expected: app 启动，刘海区出现灵动岛。

- [ ] **Step 2: 多场景验证**

制造场景（多开几个 `claude` 会话，让一部分跑任务、一部分已跑完等输入），逐项核对收起态：

1. **部分完成**：1+ 个 `processing` + 1+ 个 `waitingForInput` → spinner 正常转，且 spinner 右上角出现**绿色对勾角标**。
2. **全完成**：无 `processing`、有 `waitingForInput` → 现有「全完成」绿色对勾整态（右侧整位对勾），**无**角标（`isPartiallyComplete` 为 false）。
3. **无完成**：仅 `processing`、无 `waitingForInput` → 仅 spinner，**无**角标。
4. **动态**：一个 `processing` 会话跑完转 `waitingForInput`（另一会话仍在跑）→ 角标弹入出现；反向（完成态会话又开始跑）→ 角标淡出。
5. **审批态共存**：1 个 `waitingForApproval` + 1 个 `processing` + 1 个 `waitingForInput` → spinner（审批也走 spinner 分支）+ 角标。

- [ ] **Step 3: 视觉微调（若需要）**

若角标位置/大小不理想（如探出被刘海圆角裁掉、或太小看不清），回到 Task 2 Step 1 调整 `size`（10 → 12/14）与 `offset`（`x: 4, y: -4` → 更小或 0），重新构建验证。常见折中：`size: 11`、`offset(x: 3, y: -3)`。

- [ ] **Step 4: 回归确认**

确认角标出现/消失不影响既有行为：spinner 转动、crab 图标、审批 amber 指示、点击展开列表、完成态对勾切换均正常。

---

## 完成判据

- Task 1–2 完成，`** BUILD SUCCEEDED **`。
- Task 3 Step 2 的场景 1、2、3、4 验证通过：角标在「部分完成」时出现、其它场景不出现或切换正确。
- 角标不破坏收起态既有布局（center 区不被挤压）。
