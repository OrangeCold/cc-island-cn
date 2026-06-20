# 会话列表按钮悬浮提示（Tooltip）实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为灵动岛会话列表的 3 类纯图标按钮（查看对话 / 跳转终端 / 归档会话）增加深色风格的悬浮提示，复用项目既有的 String Catalog 多语言机制（en/zh-Hans）。

**Architecture:** 改造共用组件 `IconButton`，新增可选 `tooltip: LocalizedStringKey?` 参数，用按钮自身 `.overlay` 渲染深色胶囊浮层，悬停 ≥0.4s 淡入、移出即隐。文案走标准 String Catalog（key 即英文原文），在 `Localizable.xcstrings` 补 zh-Hans 翻译。

**Tech Stack:** Swift 5 / SwiftUI / AppKit（NSPanel）；Apple String Catalog（`.xcstrings`）本地化。

## Global Constraints

- **平台**：macOS 15.6+，accessory 应用（`LSUIElement=YES`）。
- **无测试套件**：仓库无 `Tests/` 目录。UI 改动（hover 浮层、动画）无法单测，本计划用「构建通过 + 手动验证」替代 TDD 循环。
- **构建命令**：`xcodebuild -scheme CcIslandCn -configuration Debug -destination 'generic/platform=macOS' build`（以下「构建」均指此命令）。
- **本地化约定**：`sourceLanguage=en`，key 即英文原文，只需补 `zh-Hans` 翻译（不需要 en 条目）。SwiftUI 的 `Text(LocalizedStringKey)` 自动按 key 查表。
- **xcstrings 格式**：JSON，2 空格缩进，key 与 `:` 间有空格（`"key" :`）。用 Edit 精确匹配，勿重排整个文件。
- **提交时机**：遵循用户全局约定「仅在你要求时才 commit」。计划中每个 Task 末尾的 commit 步骤是建议节奏，执行时由用户确认是否提交。

## File Structure

| 文件 | 责任 | 本次改动 |
|------|------|---------|
| `CcIslandCn/Resources/Localizable.xcstrings` | 本地化文案源（String Catalog） | 新增 2 key + 补 1 key 的 zh-Hans |
| `CcIslandCn/UI/Views/ClaudeInstancesView.swift` | 会话列表视图 + `IconButton` 组件 | 改造 `IconButton` 支持 tooltip；5 处调用点接入 |
| `CLAUDE.md` | 项目级开发约定 | 新增「## 本地化（多语言）」小节 |

不改其它文件；不重构既有结构。

---

## Task 1: 补 Localizable.xcstrings 三条 tooltip 文案

**Files:**
- Modify: `CcIslandCn/Resources/Localizable.xcstrings`

**Interfaces:**
- Produces: 3 个本地化 key（`View Conversation`、`Go to Terminal`、`Archive Session`）含 zh-Hans 翻译，供 Task 3 的 `IconButton` 调用点引用。注意 `Go to Terminal` 已存在但为空条目，本任务补其 zh-Hans。

- [ ] **Step 1: 在 strings 字典开头新增 `Archive Session` 与 `View Conversation` 两个 key**

用 Edit，将：
```
  "strings" : {
    "" : {
```
替换为：
```
  "strings" : {
    "Archive Session" : {
      "localizations" : {
        "zh-Hans" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "归档会话"
          }
        }
      }
    },
    "View Conversation" : {
      "localizations" : {
        "zh-Hans" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "查看对话"
          }
        }
      }
    },
    "" : {
```

- [ ] **Step 2: 给已存在的 `Go to Terminal` 空条目补 zh-Hans 翻译**

`Go to Terminal` 当前在第 362 行附近，是空条目（key 行 + 空行 + `    },`）。用 Edit，将：
```
    "Go to Terminal" : {

    },
```
替换为：
```
    "Go to Terminal" : {
      "localizations" : {
        "zh-Hans" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "跳转到终端"
          }
        }
      }
    },
```

> 若文件中 `Go to Terminal` 空条目的实际写法与上面 old 不完全一致（如无空行、写成单行 `{}`），按实际文本匹配，目标是把空 `{ }` 替换为上面带 `localizations` 的完整结构。

- [ ] **Step 3: 校验 JSON 合法性**

Run:
```bash
python3 -c "import json; d=json.load(open('CcIslandCn/Resources/Localizable.xcstrings')); s=d['strings']; print({k: s[k].get('localizations',{}).get('zh-Hans',{}).get('stringUnit',{}).get('value') for k in ['View Conversation','Go to Terminal','Archive Session']})"
```
Expected: 输出 `{'View Conversation': '查看对话', 'Go to Terminal': '跳转到终端', 'Archive Session': '归档会话'}`。若抛 `JSONDecodeError` 说明格式破损，回查 Step 1/2 的缩进。

- [ ] **Step 4: 构建确认 xcstrings 被正确编译进 bundle**

Run:
```bash
xcodebuild -scheme CcIslandCn -configuration Debug -destination 'generic/platform=macOS' build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`。

- [ ] **Step 5: Commit（按用户意愿）**

```bash
git add CcIslandCn/Resources/Localizable.xcstrings
git commit -m "feat(i18n): 补充会话列表 tooltip 文案 zh-Hans 翻译"
```

---

## Task 2: 改造 IconButton 支持 tooltip

**Files:**
- Modify: `CcIslandCn/UI/Views/ClaudeInstancesView.swift`（`IconButton` 结构体，约第 425–447 行）

**Interfaces:**
- Consumes: 无（向后兼容，`tooltip` 默认 nil）
- Produces: `IconButton(icon:tooltip:action:)`，`tooltip` 为 `LocalizedStringKey?`，默认 nil。调用方传字面量如 `tooltip: "View Conversation"` 即自动本地化。Task 3 依赖此签名。

- [ ] **Step 1: 将整个 `IconButton` 结构体替换为以下实现**

定位当前 `IconButton`（文件末尾 `// MARK: - Icon Button` 之后），整段替换为：

```swift
// MARK: - Icon Button

struct IconButton: View {
    let icon: String
    var tooltip: LocalizedStringKey? = nil
    let action: () -> Void

    @State private var isHovered = false
    @State private var showTooltip = false
    @State private var hoverDelayTask: Task<Void, Never>?

    private let tooltipDelay: UInt64 = 400_000_000 // 0.4s

    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(isHovered ? .white.opacity(0.8) : .white.opacity(0.4))
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isHovered ? Color.white.opacity(0.1) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .onHover { handleHover($0) }
        .overlay(alignment: .top) { tooltipView }
        .animation(.easeInOut(duration: 0.15), value: showTooltip)
    }

    private func handleHover(_ hovering: Bool) {
        isHovered = hovering
        hoverDelayTask?.cancel()
        guard hovering, tooltip != nil else {
            showTooltip = false
            return
        }
        hoverDelayTask = Task {
            try? await Task.sleep(nanoseconds: tooltipDelay)
            guard !Task.isCancelled else { return }
            showTooltip = true
        }
    }

    @ViewBuilder
    private var tooltipView: some View {
        if showTooltip, let tooltip {
            Text(tooltip)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.black.opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .shadow(color: .black.opacity(0.4), radius: 3)
                .offset(y: -28)
                .allowsHitTesting(false)
                .transition(.opacity)
        }
    }
}
```

实现要点（供 review）：
- `tooltip: LocalizedStringKey? = nil`：默认 nil，未传则 `tooltipView` 不渲染，向后兼容所有现有 `IconButton(icon:) { }` 调用。
- 用 `Task.sleep` + `Task.isCancelled` 实现 0.4s 延迟，避免直接读 `@State` 快照导致快速 hover 进出时的竞态（离开时 `hoverDelayTask?.cancel()` 使延迟任务作废）。
- `.allowsHitTesting(false)` + `.overlay`：浮层不拦截点击，不破坏既有点击穿越 / `onTapGesture`。
- `.offset(y: -28)`：按钮高 24，浮层浮在其上方留 4pt 间距；此值可在 Task 5 验证时微调。

- [ ] **Step 2: 构建确认改造无编译错误**

Run:
```bash
xcodebuild -scheme CcIslandCn -configuration Debug -destination 'generic/platform=macOS' build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`。若报 `Task` 相关并发警告，确认 `import` 顶部已有 `import SwiftUI`（Task 属于 `_Concurrency`，随 SwiftUI/Foundation 自动可用，无需额外 import）。

- [ ] **Step 3: 行为回归确认（无 tooltip 调用，行为应与改造前一致）**

此时 5 处调用点尚未传 `tooltip`，全部走 nil 分支，浮层不出现。构建产物运行后，会话列表按钮外观与点击行为应与改动前完全一致。

- [ ] **Step 4: Commit（按用户意愿）**

```bash
git add CcIslandCn/UI/Views/ClaudeInstancesView.swift
git commit -m "feat(ui): IconButton 支持可选悬浮提示(tooltip)"
```

---

## Task 3: 5 处调用点接入 tooltip 文案

**Files:**
- Modify: `CcIslandCn/UI/Views/ClaudeInstancesView.swift`（5 处 `IconButton(...)` 调用）

**Interfaces:**
- Consumes: Task 1 的 3 个本地化 key；Task 2 的 `IconButton(icon:tooltip:action:)` 签名。
- Produces: 会话列表按钮实际显示本地化悬浮提示。

依赖：Task 1（key 存在）、Task 2（IconButton 支持 tooltip）。

- [ ] **Step 1: 常规态两处按钮接入**

定位约第 289–305 行（常规态 `else` 分支内的 `bubble.left` 与 `eye` / `archivebox`）。将：
```swift
                    HStack(spacing: 8) {
                        // Chat icon - always show
                        IconButton(icon: "bubble.left") {
                            onChat()
                        }

                        // Focus icon (only for tmux instances with yabai)
                        if session.isInTmux && isYabaiAvailable {
                            IconButton(icon: "eye") {
                                onFocus()
                            }
                        }

                        // Archive button - only for idle or completed sessions
                        if session.phase == .idle || session.phase == .waitingForInput {
                            IconButton(icon: "archivebox") {
                                onArchive()
                            }
                        }
                    }
```
替换为：
```swift
                    HStack(spacing: 8) {
                        // Chat icon - always show
                        IconButton(icon: "bubble.left", tooltip: "View Conversation") {
                            onChat()
                        }

                        // Focus icon (only for tmux instances with yabai)
                        if session.isInTmux && isYabaiAvailable {
                            IconButton(icon: "eye", tooltip: "Go to Terminal") {
                                onFocus()
                            }
                        }

                        // Archive button - only for idle or completed sessions
                        if session.phase == .idle || session.phase == .waitingForInput {
                            IconButton(icon: "archivebox", tooltip: "Archive Session") {
                                onArchive()
                            }
                        }
                    }
```

- [ ] **Step 2: 交互式工具审批态的 chat 按钮接入**

定位约第 266 行（`isWaitingForApproval && isInteractiveTool` 分支内的 `bubble.left`）。将：
```swift
                    IconButton(icon: "bubble.left") {
                        onChat()
                    }
```
替换为：
```swift
                    IconButton(icon: "bubble.left", tooltip: "View Conversation") {
                        onChat()
                    }
```
> 该 `bubble.left` 单行调用在文件中共出现 3 次（行 266、289、373），Step 1 已改 289 行那处；本步与 Step 3 改其余两处。若 Edit 因多处匹配报错，用 `replace_all: false` 并补充上下文行精确定位。

- [ ] **Step 3: InlineApprovalButtons 内的 chat 按钮接入**

定位约第 373 行（`InlineApprovalButtons` 内的 `bubble.left`）。将：
```swift
            // Chat button
            IconButton(icon: "bubble.left") {
                onChat()
            }
            .opacity(showChatButton ? 1 : 0)
```
替换为：
```swift
            // Chat button
            IconButton(icon: "bubble.left", tooltip: "View Conversation") {
                onChat()
            }
            .opacity(showChatButton ? 1 : 0)
```

- [ ] **Step 4: 构建确认**

Run:
```bash
xcodebuild -scheme CcIslandCn -configuration Debug -destination 'generic/platform=macOS' build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`。

- [ ] **Step 5: Commit（按用户意愿）**

```bash
git add CcIslandCn/UI/Views/ClaudeInstancesView.swift
git commit -m "feat(ui): 会话列表图标按钮接入本地化悬浮提示"
```

---

## Task 4: CLAUDE.md 补充本地化约定

**Files:**
- Modify: `CLAUDE.md`

**Interfaces:** 无（文档）。

- [ ] **Step 1: 在「## CI/CD 与发布」之后、「## 约定」之前插入新小节**

用 Edit，将：
```markdown
## 约定

- 所有交互、注释、文档使用简体中文，技术术语保留英文。
```
替换为：
```markdown
## 本地化（多语言）

项目已具备本地化基建，新增 UI 文案**必须**走本地化，不要硬编码中英文字符串。

- **机制**：标准 Apple String Catalog。源文件 `CcIslandCn/Resources/Localizable.xcstrings`，`sourceLanguage = en`——**key 即英文原文**，`zh-Hans` 为翻译。SwiftUI 的 `Text("English Text")` 会自动按 key 查表。
- **语言切换**：`CcIslandCn/Core/AppLanguage.swift` 提供 `system / zh-Hans / en` 三选，通过写 `AppleLanguages` UserDefaults + 重启 App 生效（非运行时热切）。`knownRegions = en, zh-Hans`。
- **新增文案约定**：
  - SwiftUI 直接渲染优先 `Text("English key")`（LocalizedStringKey 自动本地化）。
  - 需把文案作为参数传递时（如传入自定义组件），参数类型用 `LocalizedStringKey`，或取值用 `String(localized: "key")`。
  - 同步在 `Localizable.xcstrings` 补该 key 的 `zh-Hans` 翻译（Xcode 构建会自动提取 key，翻译需手填）。
- **现状技术债**：部分早期文案（如 `ClaudeInstancesView` 的 `Processing...`/`Ready`/`Deny`/`Allow`）尚未接入本地化、仅显示英文，改动到时可顺手补。

## 约定

- 所有交互、注释、文档使用简体中文，技术术语保留英文。
```

- [ ] **Step 2: Commit（按用户意愿）**

```bash
git add CLAUDE.md
git commit -m "docs: CLAUDE.md 补充本地化(多语言)约定"
```

---

## Task 5: 手动验证 + 条件性 P1 定位兜底

**Files:**
- 条件性 Modify: `CcIslandCn/UI/Views/ClaudeInstancesView.swift`（仅当 Step 2 发现第一项 tooltip 被裁才改）

依赖：Task 1–3 完成、app 可运行、本机有 Claude Code 活跃会话（否则会话列表为空无法验证；可临时 `claude` 起一个会话）。

- [ ] **Step 1: 构建 Debug 产物并运行**

Run:
```bash
xcodebuild -scheme CcIslandCn -configuration Debug -destination 'generic/platform=macOS' build 2>&1 | tail -3
open "$(xcodebuild -scheme CcIslandCn -showBuildSettings 2>/dev/null | awk '/BUILT_PRODUCTS_DIR/{print $3}' | head -1)/CcIslandCn.app"
```
Expected: app 启动，刘海区出现灵动岛。

- [ ] **Step 2: 逐项验证 tooltip 行为**

展开会话列表后逐项核对：
1. 悬停「查看对话」(气泡) 按钮 ≥0.4s → 深色胶囊浮层淡入，文案当前语言正确；移开立即淡出。
2. 悬停「跳转到终端」(眼睛) 按钮（需该会话在 tmux 且装了 yabai）→ 文案正确。
3. 悬停「归档会话」(归档盒) 按钮（需会话处于 idle/waitingForInput）→ 文案正确。
4. 悬停期间点击按钮 → tooltip 不拦截，按钮功能正常（打开对话 / 跳转 / 归档）。
5. **列表第一项**悬停 → 重点观察：tooltip 是否被灵动岛面板顶边裁掉一部分。

- [ ] **Step 3: 中英切换验证**

app 设置里切换语言为 English / 简体中文 → 重启 → 确认 tooltip 文案随之变为 `View Conversation` / `Go to Terminal` / `Archive Session` 或对应中文。

- [ ] **Step 4: 条件性 P1 兜底——仅当 Step 2 第 5 项发现第一项 tooltip 被裁才执行**

若第一项 tooltip 完整可见，**跳过本步**（spec §5「先简后繁」）。若被裁，按下方方案实现「第一项 tooltip 改为向下显示」：

(a) `ClaudeInstancesView.instancesList` 的 `ForEach` 中，给首项传标记。将：
```swift
                ForEach(sortedInstances) { session in
                    InstanceRow(
                        session: session,
                        onFocus: { focusSession(session) },
```
改为（新增 `isTopRow` 参数，首项为 true）：
```swift
                ForEach(Array(sortedInstances.enumerated()), id: \.element.stableId) { index, session in
                    InstanceRow(
                        session: session,
                        isTopRow: index == 0,
                        onFocus: { focusSession(session) },
```

(b) `InstanceRow` 增加字段并把 tooltip 位置传给 `IconButton`。在 `struct InstanceRow` 的属性区加：
```swift
    var isTopRow: Bool = false
```
并把常规态的 `IconButton(icon: "bubble.left", tooltip: "View Conversation")` 改造为带位置参数——这需要 `IconButton` 再加一个 `tooltipBelow: Bool = false` 参数，使 overlay 的 `alignment` 与 `offset` 方向切换：
```swift
        .overlay(alignment: tooltipBelow ? .bottom : .top) { tooltipView }
```
并在 `tooltipView` 中把 `.offset(y: -28)` 改为 `.offset(y: tooltipBelow ? 28 : -28)`。调用点传 `tooltipBelow: isTopRow`。

> 本步为条件触发，涉及 `InstanceRow` 与 `IconButton` 签名联动；若需执行，建议单独提一个细化任务。

- [ ] **Step 5: 若做了兜底改动，构建 + 回归验证 + Commit（按用户意愿）**

```bash
xcodebuild -scheme CcIslandCn -configuration Debug -destination 'generic/platform=macOS' build 2>&1 | tail -3
```
Expected: `** BUILD SUCCEEDED **`；确认第一项 tooltip 改向下后完整可见，其余项仍向上且无回归。
```bash
git add CcIslandCn/UI/Views/ClaudeInstancesView.swift
git commit -m "fix(ui): 列表首项 tooltip 改向下避免被面板顶边裁剪"
```

---

## 完成判据

- Task 1–4 全部完成，`** BUILD SUCCEEDED **`。
- Task 5 Step 2 的 1–4 项、Step 3 验证通过。
- 悬停 3 类按钮均显示对应文案，中英随语言切换，不拦截点击。
- CLAUDE.md 已含「## 本地化（多语言）」小节。
