# 灵动岛收起态大小可调 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在设置面板新增滑块，让用户调节收起态灵动岛大小（等比缩放 60%~150%，默认当前尺寸，连续滑块 + 行内真实预览），解决无刘海旧设备收起态偏大遮挡屏幕的问题。

**Architecture:** 用户偏好 `notchScale` 持久化于 `AppSettings`（UserDefaults），运行时镜像为 `NotchViewModel` 的 `@Published var notchScale`，作为收起态尺寸的单一真相。滑块拖动改 `notchScale` 实时驱动 `NotchView` 收起态与行内预览重画；展开态（`openedSize`）不受影响。所有依赖收起态尺寸的几何与点击判定同步使用 scaled 尺寸，保证点击穿越与视觉不错位。

**Tech Stack:** Swift 5 / SwiftUI / AppKit（NSPanel），macOS 15.6+，UserDefaults 持久化，String Catalog 本地化。

## Global Constraints

- **平台**：macOS 15.6+，Swift 5（大量 `nonisolated`/`Sendable`/`actor`，`NotchViewModel` 为 `@MainActor`）。
- **无测试套件**：仓库无 `Tests/`、无 XCTest 配置。本计划验证以 `xcodebuild build` + 手动验证为准；纯逻辑单测（`NotchGeometry`、`AppSettings`）可作为技术债后补，不阻塞主路径。
- **本地化**：新增 UI 文案必须走 `CcIslandCn/Resources/Localizable.xcstrings`（key 即英文原文，`zh-Hans` 翻译），不得硬编码中文。
- **持久化范式**：`enum AppSettings` + `UserDefaults.standard`，**不要**引入 `@AppStorage`/`@UserDefault`。
- **未启用 App Sandbox**，勿加回。
- **notchScale**：Double，范围 `0.6...1.5`，默认 `1.0`，setter 钳制。
- **构建命令**：`xcodebuild -scheme CcIslandCn -configuration Debug -destination 'generic/platform=macOS' build`
- **提交**：commit message 用中文，结尾加 `Co-Authored-By: Claude <noreply@anthropic.com>`。
- **设计依据**：`docs/superpowers/specs/2026-06-26-notch-size-setting-design.md`（含 10 项联动改动点清单）。

---

### Task 1: `AppSettings.notchScale` 持久化

**Files:**
- Modify: `CcIslandCn/Core/Settings.swift:39-43`（Keys enum）、`CcIslandCn/Core/Settings.swift:88-90`（文件末尾追加属性）

**Interfaces:**
- Consumes: 无
- Produces: `AppSettings.notchScale: Double`（get/set，默认 1.0，钳制 0.6~1.5）。Task 3 依赖。

- [ ] **Step 1: 在 `Keys` enum 加 key**

`CcIslandCn/Core/Settings.swift`，把：

```swift
    private enum Keys {
        static let notificationSound = "notificationSound"
        static let claudeDirectoryName = "claudeDirectoryName"
        static let appLanguage = "appLanguage"
    }
```

改为：

```swift
    private enum Keys {
        static let notificationSound = "notificationSound"
        static let claudeDirectoryName = "claudeDirectoryName"
        static let appLanguage = "appLanguage"
        static let notchScale = "notchScale"
    }
```

- [ ] **Step 2: 在 `AppSettings` enum 末尾（`appLanguage` 属性之后、结尾 `}` 之前）加 `notchScale` 属性**

```swift
    // MARK: - Notch Scale

    /// 收起态灵动岛缩放因子。0.6~1.5，默认 1.0（= 当前尺寸）。
    /// 未设置 key 时回退 1.0；非法/越界值钳制到范围内。
    static var notchScale: Double {
        get {
            guard let value = defaults.object(forKey: Keys.notchScale) as? Double else {
                return 1.0
            }
            return min(max(value, 0.6), 1.5)
        }
        set {
            defaults.set(min(max(newValue, 0.6), 1.5), forKey: Keys.notchScale)
        }
    }
```

> 用 `object(forKey:) as? Double` 区分「未设置」（回退 1.0）与「合法值」，避免 `double(forKey:)` 默认 0 的歧义。

- [ ] **Step 3: 构建验证**

Run: `xcodebuild -scheme CcIslandCn -configuration Debug -destination 'generic/platform=macOS' build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add CcIslandCn/Core/Settings.swift
git commit -m "feat(settings): 新增 AppSettings.notchScale 收起态缩放偏好

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 2: `NotchGeometry` 几何方法加 `scale` 参数（签名重构，行为不变）

把 `notchScreenRect` 由计算属性改为带默认参数的函数，`isPointInNotch` 加默认参数。**本任务不改变运行时行为**（默认 `scale = 1.0`），仅为 Task 3 注入实际 scale 做准备。默认参数让除一处外的调用点无需改动、保持编译通过。

**Files:**
- Modify: `CcIslandCn/Core/NotchGeometry.swift:17-43`
- Modify: `CcIslandCn/Core/NotchViewModel.swift:194`（`notchScreenRect` 属性→函数调用）

**Interfaces:**
- Consumes: 无
- Produces: `NotchGeometry.notchScreenRect(scale: CGFloat = 1.0) -> CGRect`、`NotchGeometry.isPointInNotch(_ point:, scale: CGFloat = 1.0) -> Bool`。Task 3 依赖。

- [ ] **Step 1: 改 `NotchGeometry`（`CcIslandCn/Core/NotchGeometry.swift`）**

把：

```swift
    /// The notch rect in screen coordinates (for hit testing with global mouse position)
    var notchScreenRect: CGRect {
        CGRect(
            x: screenRect.midX - deviceNotchRect.width / 2,
            y: screenRect.maxY - deviceNotchRect.height,
            width: deviceNotchRect.width,
            height: deviceNotchRect.height
        )
    }

    /// The opened panel rect in screen coordinates for a given size
    func openedScreenRect(for size: CGSize) -> CGRect {
        // Match the actual rendered panel size (tuned to match visual output)
        let width = size.width - 6
        let height = size.height - 30
        return CGRect(
            x: screenRect.midX - width / 2,
            y: screenRect.maxY - height,
            width: width,
            height: height
        )
    }

    /// Check if a point is in the notch area (with padding for easier interaction)
    func isPointInNotch(_ point: CGPoint) -> Bool {
        notchScreenRect.insetBy(dx: -10, dy: -5).contains(point)
    }
```

改为：

```swift
    /// The notch rect in screen coordinates (for hit testing with global mouse position).
    /// scale 用于收起态缩放（默认 1.0 = 贴合物理刘海尺寸）。
    func notchScreenRect(scale: CGFloat = 1.0) -> CGRect {
        let width = deviceNotchRect.width * scale
        let height = deviceNotchRect.height * scale
        return CGRect(
            x: screenRect.midX - width / 2,
            y: screenRect.maxY - height,
            width: width,
            height: height
        )
    }

    /// The opened panel rect in screen coordinates for a given size
    func openedScreenRect(for size: CGSize) -> CGRect {
        // Match the actual rendered panel size (tuned to match visual output)
        let width = size.width - 6
        let height = size.height - 30
        return CGRect(
            x: screenRect.midX - width / 2,
            y: screenRect.maxY - height,
            width: width,
            height: height
        )
    }

    /// Check if a point is in the notch area (with padding for easier interaction)
    func isPointInNotch(_ point: CGPoint, scale: CGFloat = 1.0) -> Bool {
        notchScreenRect(scale: scale).insetBy(dx: -10, dy: -5).contains(point)
    }
```

- [ ] **Step 2: 同步改 `NotchViewModel` 中唯一的 `notchScreenRect` 属性调用（`CcIslandCn/Core/NotchViewModel.swift:194`）**

把：

```swift
            } else if geometry.notchScreenRect.contains(location) {
```

改为（用默认 scale 1.0，行为不变）：

```swift
            } else if geometry.notchScreenRect().contains(location) {
```

> `isPointInNotch` 因新增默认参数，其调用点（`:160`、`:201`）无需改动。

- [ ] **Step 3: 构建验证**

Run: `xcodebuild -scheme CcIslandCn -configuration Debug -destination 'generic/platform=macOS' build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`（行为与改动前完全一致）

- [ ] **Step 4: Commit**

```bash
git add CcIslandCn/Core/NotchGeometry.swift CcIslandCn/Core/NotchViewModel.swift
git commit -m "refactor(geometry): notchScreenRect/isPointInNotch 增加 scale 参数

签名重构，默认 scale=1.0 保持现有行为不变，为收起态缩放做准备。

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 3: `NotchViewModel` 注入 `notchScale` 与 `scaledNotchSize`，hit-test 传 scale

把 `notchScale` 作为收起态尺寸的运行时单一真相，并让所有收起态 hit-test 使用 scaled 尺寸。完成后 `notchScale` 默认 1.0，运行时行为仍不变（Task 4 才让其真正影响渲染）。

**Files:**
- Modify: `CcIslandCn/Core/NotchViewModel.swift:44-47`（@Published 区）、`:57-63`（geometry 区）、`:107-116`（init）、`:160`/`:194`/`:201`（hit-test 调用）

**Interfaces:**
- Consumes: `AppSettings.notchScale`（Task 1）、`NotchGeometry` scale 参数（Task 2）
- Produces: `NotchViewModel.notchScale: Double`（@Published）、`NotchViewModel.scaledNotchSize: CGSize`。Task 4/5/6 依赖。

- [ ] **Step 1: 加 `@Published var notchScale`**

`CcIslandCn/Core/NotchViewModel.swift`，把：

```swift
    // MARK: - Published State

    @Published var status: NotchStatus = .closed
    @Published var openReason: NotchOpenReason = .unknown
    @Published var contentType: NotchContentType = .instances
    @Published var isHovering: Bool = false
```

改为：

```swift
    // MARK: - Published State

    @Published var status: NotchStatus = .closed
    @Published var openReason: NotchOpenReason = .unknown
    @Published var contentType: NotchContentType = .instances
    @Published var isHovering: Bool = false
    /// 收起态灵动岛缩放因子（运行时单一真相，从 AppSettings 读入）。0.6~1.5，默认 1.0。
    /// 用 CGFloat 避免与几何运算的频繁类型转换；AppSettings 边界处再转 Double。
    @Published var notchScale: CGFloat = 1.0
```

- [ ] **Step 2: 在 geometry 区加 `scaledNotchSize` 计算属性**

把：

```swift
    var deviceNotchRect: CGRect { geometry.deviceNotchRect }
    var screenRect: CGRect { geometry.screenRect }
    var windowHeight: CGFloat { geometry.windowHeight }
```

改为：

```swift
    var deviceNotchRect: CGRect { geometry.deviceNotchRect }
    var screenRect: CGRect { geometry.screenRect }
    var windowHeight: CGFloat { geometry.windowHeight }

    /// 收起态缩放后的尺寸（NotchView 渲染与 hit-test 共用的单一真相）
    var scaledNotchSize: CGSize {
        CGSize(
            width: deviceNotchRect.width * notchScale,
            height: deviceNotchRect.height * notchScale
        )
    }
```

- [ ] **Step 3: `init` 内读入持久化值**

把：

```swift
        self.geometry = NotchGeometry(
            deviceNotchRect: deviceNotchRect,
            screenRect: screenRect,
            windowHeight: windowHeight
        )
        self.hasPhysicalNotch = hasPhysicalNotch
        setupEventHandlers()
        observeSelectors()
```

改为：

```swift
        self.geometry = NotchGeometry(
            deviceNotchRect: deviceNotchRect,
            screenRect: screenRect,
            windowHeight: windowHeight
        )
        self.hasPhysicalNotch = hasPhysicalNotch
        self.notchScale = CGFloat(AppSettings.notchScale)
        setupEventHandlers()
        observeSelectors()
```

- [ ] **Step 4: hit-test 调用传 `notchScale`**

把 `handleMouseMove` 中的：

```swift
        let inNotch = geometry.isPointInNotch(location)
```

改为：

```swift
        let inNotch = geometry.isPointInNotch(location, scale: notchScale)
```

把 `handleMouseDown` opened 分支中的：

```swift
            } else if geometry.notchScreenRect().contains(location) {
```

改为：

```swift
            } else if geometry.notchScreenRect(scale: notchScale).contains(location) {
```

把 `handleMouseDown` closed/popping 分支中的：

```swift
            if geometry.isPointInNotch(location) {
```

改为：

```swift
            if geometry.isPointInNotch(location, scale: notchScale) {
```

- [ ] **Step 5: 构建验证**

Run: `xcodebuild -scheme CcIslandCn -configuration Debug -destination 'generic/platform=macOS' build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`（`notchScale` 默认 1.0，行为不变）

- [ ] **Step 6: Commit**

```bash
git add CcIslandCn/Core/NotchViewModel.swift
git commit -m "feat(viewmodel): 注入 notchScale 单一真相与 scaledNotchSize

收起态 hit-test 改用 scaled 尺寸，默认 1.0 行为不变。

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 4: `NotchView` 收起态等比缩放（6 处）

让收起态小条、圆角、内边距、spacer 全部按 `notchScale` 等比缩放，保证真实小条与行内预览一致。

**Files:**
- Modify: `CcIslandCn/UI/Views/NotchView.swift:69-74`、`:121-131`、`:155-160`、`:283`、`:288`

**Interfaces:**
- Consumes: `viewModel.scaledNotchSize`、`viewModel.notchScale`（Task 3）
- Produces: 收起态等比缩放的渲染（Task 6 预览与之对照）

- [ ] **Step 1: `closedNotchSize` 改用 `scaledNotchSize`（`:69-74`）**

把：

```swift
    private var closedNotchSize: CGSize {
        CGSize(
            width: viewModel.deviceNotchRect.width,
            height: viewModel.deviceNotchRect.height
        )
    }
```

改为：

```swift
    private var closedNotchSize: CGSize {
        viewModel.scaledNotchSize
    }
```

- [ ] **Step 2: 收起态圆角 `× notchScale`（`:121-131`）**

把：

```swift
    private var topCornerRadius: CGFloat {
        viewModel.status == .opened
            ? cornerRadiusInsets.opened.top
            : cornerRadiusInsets.closed.top
    }

    private var bottomCornerRadius: CGFloat {
        viewModel.status == .opened
            ? cornerRadiusInsets.opened.bottom
            : cornerRadiusInsets.closed.bottom
    }
```

改为：

```swift
    private var topCornerRadius: CGFloat {
        viewModel.status == .opened
            ? cornerRadiusInsets.opened.top
            : cornerRadiusInsets.closed.top * viewModel.notchScale
    }

    private var bottomCornerRadius: CGFloat {
        viewModel.status == .opened
            ? cornerRadiusInsets.opened.bottom
            : cornerRadiusInsets.closed.bottom * viewModel.notchScale
    }
```

- [ ] **Step 3: 外层 horizontal padding 收起态 `× notchScale`（`:155-160`）**

把：

```swift
                    .padding(
                        .horizontal,
                        viewModel.status == .opened
                            ? cornerRadiusInsets.opened.top
                            : cornerRadiusInsets.closed.bottom
                    )
```

改为：

```swift
                    .padding(
                        .horizontal,
                        viewModel.status == .opened
                            ? cornerRadiusInsets.opened.top
                            : cornerRadiusInsets.closed.bottom * viewModel.notchScale
                    )
```

- [ ] **Step 4: 静止态 spacer `× notchScale`（`:283`）**

把：

```swift
                    .frame(width: closedNotchSize.width - 20)
```

改为：

```swift
                    .frame(width: closedNotchSize.width - 20 * viewModel.notchScale)
```

- [ ] **Step 5: 活动态 spacer `× notchScale`（`:288`）**

把：

```swift
                    .frame(width: closedNotchSize.width - cornerRadiusInsets.closed.top + (isBouncing ? 16 : 0))
```

改为：

```swift
                    .frame(width: closedNotchSize.width - cornerRadiusInsets.closed.top * viewModel.notchScale + (isBouncing ? 16 : 0))
```

> `expansionWidth`、`sideWidth`、`headerRow.frame(height:)` 均基于 `closedNotchSize.height`，已自动跟随，无需改动。

- [ ] **Step 6: 构建验证**

Run: `xcodebuild -scheme CcIslandCn -configuration Debug -destination 'generic/platform=macOS' build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 7: 手动验证（缩放生效）**

临时在 `NotchViewModel.init` 把 `self.notchScale = AppSettings.notchScale` 改为 `self.notchScale = 0.7`，运行 app：收起态小条应明显变小且形状保持。**验证后改回 `AppSettings.notchScale`**，不要提交临时改动。

- [ ] **Step 8: Commit**

```bash
git add CcIslandCn/UI/Views/NotchView.swift
git commit -m "feat(notch): 收起态小条按 notchScale 等比缩放

同步缩放尺寸、圆角、外层内边距与 spacer 常数，保证与预览一致。

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 5: `NotchViewController.hitTestRect` 收起分支缩放（点击穿越约定）

收起态点击判定区随 scaled 尺寸变化，否则岛变小后点击区仍停在原刘海位置（CLAUDE.md「三个核心约定」之一）。

**Files:**
- Modify: `CcIslandCn/UI/Window/NotchViewController.swift:64-75`

**Interfaces:**
- Consumes: `vm.notchScale`（Task 3，闭包内已有 `let vm = self.viewModel`）
- Produces: 与视觉一致的收起态 hit-test 区

- [ ] **Step 1: 收起分支改用 scaled 尺寸**

把：

```swift
            case .closed, .popping:
                // When closed, use the notch rect
                let notchRect = geometry.deviceNotchRect
                let screenWidth = geometry.screenRect.width
                // Add some padding for easier interaction
                return CGRect(
                    x: (screenWidth - notchRect.width) / 2 - 10,
                    y: windowHeight - notchRect.height - 5,
                    width: notchRect.width + 20,
                    height: notchRect.height + 10
                )
```

改为：

```swift
            case .closed, .popping:
                // When closed, use the scaled notch rect
                let scaledWidth = geometry.deviceNotchRect.width * vm.notchScale
                let scaledHeight = geometry.deviceNotchRect.height * vm.notchScale
                let screenWidth = geometry.screenRect.width
                // Add some padding for easier interaction
                return CGRect(
                    x: (screenWidth - scaledWidth) / 2 - 10,
                    y: windowHeight - scaledHeight - 5,
                    width: scaledWidth + 20,
                    height: scaledHeight + 10
                )
```

- [ ] **Step 2: 构建验证**

Run: `xcodebuild -scheme CcIslandCn -configuration Debug -destination 'generic/platform=macOS' build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add CcIslandCn/UI/Window/NotchViewController.swift
git commit -m "fix(notch): 收起态 hitTestRect 随 scaled 尺寸变化

保持点击穿越区与缩放后的小条一致。

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 6: 设置面板新增滑块 + 行内真实预览 + 本地化

新增 `NotchSizeSliderRow`（含 `NotchSizePreview`），插入设置面板外观区，并补本地化 key。这是用户可见的入口。

**Files:**
- Modify: `CcIslandCn/UI/Views/NotchMenuView.swift:42-45`（外观区插入行）、文件末尾（新增两个 struct）
- Modify: `CcIslandCn/Resources/Localizable.xcstrings`（加 `"Notch Size"` key）

**Interfaces:**
- Consumes: `viewModel.notchScale`、`viewModel.deviceNotchRect.size`（Task 3）、`AppSettings.notchScale`（Task 1）
- Produces: 用户可交互的滑块入口

- [ ] **Step 1: 外观区插入 `NotchSizeSliderRow`（`CcIslandCn/UI/Views/NotchMenuView.swift`）**

把：

```swift
                // Appearance settings
                ScreenPickerRow(screenSelector: screenSelector)
                SoundPickerRow(soundSelector: soundSelector)
                ClaudeDirPickerRow()
                LanguagePickerRow()
```

改为：

```swift
                // Appearance settings
                ScreenPickerRow(screenSelector: screenSelector)
                SoundPickerRow(soundSelector: soundSelector)
                ClaudeDirPickerRow()
                LanguagePickerRow()
                NotchSizeSliderRow(viewModel: viewModel)
```

- [ ] **Step 2: 在文件末尾（`MenuToggleRow` struct 之后）新增 `NotchSizePreview` 与 `NotchSizeSliderRow`**

```swift
// MARK: - Notch Size Slider Row

/// 行内真实尺寸预览：随 scale 实时缩放的收起态小条（1:1 基准尺寸）
struct NotchSizePreview: View {
    let scale: CGFloat
    let baseSize: CGSize          // = viewModel.deviceNotchRect.size

    private var scaledSize: CGSize {
        CGSize(width: baseSize.width * scale, height: baseSize.height * scale)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.06))          // 模拟菜单栏背景
            NotchShape(
                topCornerRadius: 6 * scale,
                bottomCornerRadius: 14 * scale
            )
            .fill(.black)
            .frame(width: scaledSize.width, height: scaledSize.height)
        }
        .frame(height: 64)
        .padding(.horizontal, 12)
    }
}

struct NotchSizeSliderRow: View {
    @ObservedObject var viewModel: NotchViewModel

    var body: some View {
        VStack(spacing: 8) {
            NotchSizePreview(scale: viewModel.notchScale, baseSize: viewModel.deviceNotchRect.size)

            HStack(spacing: 10) {
                Image(systemName: "aspectratio")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 16)

                Text("Notch Size")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))

                Slider(
                    value: Binding(
                        get: { viewModel.notchScale },
                        set: { viewModel.notchScale = $0 }
                    ),
                    in: 0.6...1.5                      // 连续，无 step
                )
                .tint(.white.opacity(0.5))

                Text("\(Int((viewModel.notchScale * 100).rounded()))%")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
                    .frame(width: 36, alignment: .trailing)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .onChange(of: viewModel.notchScale) { _, newValue in
            AppSettings.notchScale = Double(newValue)  // 持久化（setter 内钳制 0.6~1.5）
        }
    }
}
```

- [ ] **Step 3: 加本地化 key（`CcIslandCn/Resources/Localizable.xcstrings`）**

在 `"strings"` 对象内，按字母位置加入（位置不影响功能，Xcode 会重排）。可手动编辑 JSON 加入：

```json
    "Notch Size" : {
      "localizations" : {
        "zh-Hans" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "灵动岛大小"
          }
        }
      }
    },
```

或在 Xcode 打开 `Localizable.xcstrings` → 点 「+」 → key 填 `Notch Size` → zh-Hans 填 `灵动岛大小`。

- [ ] **Step 4: 构建验证**

Run: `xcodebuild -scheme CcIslandCn -configuration Debug -destination 'generic/platform=macOS' build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: 手动验证（完整功能）**

运行 app → 打开灵动岛 → 切到菜单（设置）页，核对：
1. 外观区出现「灵动岛大小」行，下方有真实尺寸黑色小条预览。
2. 拖动滑块：预览小条逐像素实时变大变小；右侧百分比随之变化（60%~150%）。
3. 收起灵动岛：真实小条尺寸与预览趋势一致（调小→更小、遮挡更少）。
4. 退出并重启 app：上次尺寸保持（持久化生效）。
5. 收起态点击小条→展开；展开态点击岛外→关闭并穿透下层（点击穿越正常）。

- [ ] **Step 6: Commit**

```bash
git add CcIslandCn/UI/Views/NotchMenuView.swift CcIslandCn/Resources/Localizable.xcstrings
git commit -m "feat(settings): 新增收起态大小滑块与行内真实预览

设置面板外观区新增 NotchSizeSliderRow，连续滑块 60%~150%，
行内 1:1 预览实时反映收起态尺寸，拖动即持久化。

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 7: 版本号 build +1

按 CI/CD 约定，用户可见功能每次 build 号 +1。

**Files:**
- Modify: `CcIslandCn.xcodeproj/project.pbxproj:283`、`:318`（两处 `CURRENT_PROJECT_VERSION`）

**Interfaces:**
- Consumes: 无
- Produces: build 号 9 → 10

- [ ] **Step 1: `CURRENT_PROJECT_VERSION` 9 → 10（Debug 与 Release 两处）**

把两处（约 `:283` 与 `:318`）的：

```
				CURRENT_PROJECT_VERSION = 9;
```

改为：

```
				CURRENT_PROJECT_VERSION = 10;
```

> `MARKETING_VERSION` 是否升 minor（如 1.4.2 → 1.5.0）由发版时决定，本任务只 +1 build。

- [ ] **Step 2: 构建验证**

Run: `xcodebuild -scheme CcIslandCn -configuration Debug -destination 'generic/platform=macOS' build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add CcIslandCn.xcodeproj/project.pbxproj
git commit -m "chore: 升 build 到 10

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## 验收清单（全部任务完成后回归）

对照 spec 第 9 节，理想环境：无刘海旧设备 + Claude Code 活跃会话。

- [ ] 无刘海设备：调小→收起态变小、遮挡减少；预览实时跟手；点击区跟手。
- [ ] 有刘海设备：默认贴合；调小两侧露菜单栏；调大覆盖菜单栏。
- [ ] 百分比显示正确（60%~150%）。
- [ ] 重启 app：scale 持久化生效。
- [ ] 换屏/多屏：重建 `viewModel`，scale 从 `AppSettings` 读入一致。
- [ ] 收起态有活动（processing/permission/waiting）：缩放后 crab/spinner/checkmark 仍正常。
- [ ] 点击穿越不破：收起态点岛→展开；展开态点岛外→关闭并穿透下层。
