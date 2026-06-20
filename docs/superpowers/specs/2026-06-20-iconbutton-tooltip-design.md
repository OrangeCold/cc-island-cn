# 会话列表按钮悬浮提示（Tooltip）设计

> 日期：2026-06-20 ｜ 状态：待用户复核

## 1. 背景与目标

灵动岛会话列表（`ClaudeInstancesView` → `InstanceRow`）右侧的纯图标按钮（`IconButton`）目前只有图标、无文字说明，用户难以判断其功能。本次为其中的 3 类图标按钮增加悬浮提示（tooltip），并复用项目既有的 String Catalog 多语言机制，使提示文案支持简体中文 / English。

## 2. 范围

**包含**：`ClaudeInstancesView.swift` 中 `IconButton` 的 5 处调用点（3 种含义）——`bubble.left`×3（查看对话）、`eye`（跳转终端）、`archivebox`（归档会话）。

**不包含**（YAGNI）：
- 带文字标签的按钮（`Deny` / `Allow` / `Terminal` / `CompactTerminal`）——已有文字
- tooltip 跟随鼠标移动
- 其它既有未接入本地化的文案（见 §6 技术债）

## 3. 实现方式：自定义 SwiftUI 浮层

**结论**：自定义 SwiftUI 浮层，不使用系统原生 `.help()`。

**理由**：
- 灵动岛是自定义 `NSPanel`（层级 `mainMenu + 3`、深色半透明美学）。系统原生 tooltip 为浅黄底黑字、与深色 UI 反差大、出现有 ~2s 延迟，且能否稳定浮在该高层级面板之上需实测，效果不可控。
- 自定义浮层视觉可控、与灵动岛风格统一。`NotchWindow` 已配置 `allowsToolTipsWhenApplicationIsInactive = true`，但本次仍选自定义以获得样式与节奏控制权。

## 4. 组件改造

- `IconButton` 新增可选参数 `tooltip: LocalizedStringKey?`；未传则不渲染浮层（向后兼容）。
- 浮层用按钮自身 `.overlay(alignment: .top)` 渲染（不新建独立 View 文件，改动集中）。
- 浮层设 `.allowsHitTesting(false)`，绝不拦截点击，不破坏既有点击穿越 / `onTapGesture` 逻辑。
- 复用 `IconButton` 现有 `isHovered` 状态驱动显示，零额外事件接入。

## 5. 视觉与交互

**视觉**（贴合灵动岛深色美学）：
- 背景 `Color.black.opacity(0.85)` + 轻微阴影，胶囊 `cornerRadius: 6`
- 文字白 `opacity(0.9)`，字号 11 / medium，内边距水平 8、垂直 3
- 显隐动画 `easeInOut 0.15s`

**交互**：
- 悬停 **≥ 0.4s** 淡入（避免鼠标扫过频繁闪烁）
- 鼠标移出按钮**立即淡出**

**定位（方案 P1）**：
- 默认浮在按钮**上方**。
- 已知风险：列表**第一项**的按钮上方可能贴近面板顶边被裁。
- 处理：先按「默认向上」实现；实测确认第一项被裁后，再加「该行是否处于列表可视顶部、是则改向下」的判断。先简后繁。

## 6. 多语言

**复用标准 String Catalog 机制**，不另建方案：
- `IconButton.tooltip` 参数类型为 `LocalizedStringKey`，内部 `Text(tooltip)` 自动本地化（与项目 `sourceLanguage = en` 一致）。
- 在 `CcIslandCn/Resources/Localizable.xcstrings` 补 3 个 key 的 `en`（即 key 本身）+ `zh-Hans` 翻译：

| 按钮 | key（英文原文） | zh-Hans |
|------|----------------|---------|
| `bubble.left` | `View Conversation` | 查看对话 |
| `eye` | `Go to Terminal` | 跳转到终端 |
| `archivebox` | `Archive Session` | 归档会话 |

> 语言切换经 `AppLanguage`（`system / zh-Hans / en`，写 `AppleLanguages` + 重启）生效，`Text(LocalizedStringKey)` 会遵循。

**现状技术债**：`ClaudeInstancesView` 等处部分早期文案（`Processing...`/`Ready`/`Deny`/`Allow` 等）尚未接入本地化、仅显示英文。本次不处理，但会在 CLAUDE.md 中记录此约定与技术债。

## 7. 涉及文件

| 文件 | 改动 |
|------|------|
| `CcIslandCn/UI/Views/ClaudeInstancesView.swift` | `IconButton` 增加 `tooltip` 参数与浮层渲染；5 处调用点传 key；`InlineApprovalButtons` 内 `bubble.left` 同步 |
| `CcIslandCn/Resources/Localizable.xcstrings` | 新增 3 个 key（en + zh-Hans） |
| `CLAUDE.md` | 新增「## 本地化（多语言）」约定小节（见 §8） |

## 8. CLAUDE.md 补充内容（交付物）

在 `CLAUDE.md` 的「## CI/CD 与发布」之后、「## 约定」之前，新增小节：

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
```

## 9. 验证

无单测基建，手动验证：
- Debug 构建 → 灵动岛展开会话列表 → 依次悬停 3 类按钮，确认：tooltip 在 ~0.4s 后淡入、文案正确、移出即隐。
- 切换语言（设置 → zh-Hans / English）重启，确认文案随语言变化。
- 悬停期间点击按钮，确认 tooltip 不拦截点击、按钮功能正常。
- 列表第一项悬停，确认 tooltip 不被面板顶边裁剪（若裁剪则按 §5 触发 P1 兜底）。
