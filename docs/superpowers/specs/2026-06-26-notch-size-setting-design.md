# 灵动岛收起态大小可调 —— 设计文档

- 日期：2026-06-26
- 分支：`feat/feat_island_size`
- 状态：待实现

## 1. 背景与目标

cc-island-cn 在没有物理刘海的旧款 Mac 上，收起态灵动岛 fallback 为固定尺寸 `224×38`（`CcIslandCn/Core/Ext+NSScreen.swift:12-16`），对部分用户而言偏大、遮挡屏幕顶部内容。

本功能在设置面板中新增一个**滑块**，让用户调节**收起态**灵动岛的大小，默认等于当前尺寸，拖动时**实时预览**，方便判断是否合适。

### 非目标

- 不调展开态（chat / menu / instances 大面板）。
- 不调字体 / padding（收起态无文字内容）。
- 不加重置入口（用户可拖回 100%）。
- 不做设备分支（有物理刘海的设备也允许自由调）。

## 2. 需求决策（已与用户确认）

| # | 决策点 | 结论 |
|---|--------|------|
| 1 | 调节对象 | 只调**收起态**，展开态保持不变 |
| 2 | 调节维度 | **等比缩放**（宽高同比例，一个滑块） |
| 3 | 实时观察方式 | 设置面板内**真实尺寸预览**（1:1，随滑块实时缩放） |
| 4 | 缩放范围 | **60% ~ 150%**，默认 100% |
| 5 | 滑块粒度 | **连续**（不设 step，逐像素丝滑）；存储实际浮点值，百分比显示 round 到整数 |
| 6 | 设备行为 | 全局自由调（有刘海设备默认贴合刘海，调小则岛窄于刘海、调大覆盖部分菜单栏，交用户自负） |
| 7 | 重置入口 | 不加 |
| 8 | 实现路线 | 路线 A：scale 镜像在 `NotchViewModel`，几何方法显式接收 scale |

## 3. 方案概述（路线 A）

引入用户偏好 `notchScale`（Double，0.6~1.5，默认 1.0），作为收起态尺寸的缩放因子：

- **持久化**：`AppSettings.notchScale`（UserDefaults）。
- **运行时单一真相**：`NotchViewModel.notchScale`（`@Published`），`init` 时从 `AppSettings` 读入。
- **渲染**：`NotchView.closedNotchSize = deviceNotchRect.size × notchScale`，收起态圆角同步 `× notchScale`。
- **实时**：滑块拖动改 `viewModel.notchScale` → `@Published` 触发 `NotchView` 与行内预览重画。
- **几何/点击联动**：所有依赖收起态尺寸的几何与 hit-test 点同步使用 scaled 尺寸。
- **展开态不动**：`openedSize` 不引用 `notchScale`。

**为什么 scale 放 `NotchViewModel` 而非 `AppSettings` 直接驱动**：`AppSettings` 是 `enum` 静态属性，非 `ObservableObject`，无法直接驱动 SwiftUI 实时重画。`NotchViewModel` 是 `@MainActor ObservableObject`，已是 `NotchView` 的 `@ObservedObject`，`@Published notchScale` 天然实时。`AppSettings` 只负责持久化，`viewModel` 负责运行时镜像——与项目现有「selector 镜像」范式（`observeSelectors()`）一致。

## 4. 架构与组件

改动集中在 6 个文件，无新模块、不重建窗口：

| 文件 | 改动 |
|------|------|
| `Core/Settings.swift` | 加 `AppSettings.notchScale`（get/set UserDefaults，key `"notchScale"`，默认 1.0，钳制 0.6~1.5） |
| `Core/NotchViewModel.swift` | 加 `@Published var notchScale`；`init` 读入；新增 `scaledNotchSize` 计算属性；hit-test 调用处传 scale |
| `Core/NotchGeometry.swift` | `notchScreenRect` / `isPointInNotch` 增加 `scale` 参数（默认 1.0 向后兼容），保持 Sendable 值类型 |
| `UI/Views/NotchView.swift` | `closedNotchSize` 改用 `viewModel.scaledNotchSize`；收起态圆角 `× notchScale` |
| `UI/Window/NotchViewController.swift` | `hitTestRect` 收起分支改用 scaled 尺寸 |
| `UI/Views/NotchMenuView.swift` | 新增 `NotchSizeSliderRow`（含行内真实预览），插入外观区 |

**数据流**（单一真相源 = `viewModel.notchScale`）：

```
滑块拖动 ──▶ viewModel.notchScale(@Published) ──┬─▶ NotchView.closedNotchSize 重算（真实岛，收起时可见）
                                                ├─▶ NotchSizeSliderRow 行内预览重画（展开时可见）
                                                └─▶ onChange 写回 AppSettings.notchScale（持久化）
AppSettings.notchScale ──▶ viewModel.init 读入（换屏重建时保持一致）
```

## 5. 联动改动点清单（漏一处即点击/视觉错位）

收起态尺寸从 `deviceNotchRect.size` 变为 `deviceNotchRect.size × notchScale`，下游依赖点：

| # | 位置 | 改动 | 自动跟随? |
|---|------|------|-----------|
| 1 | `NotchView.closedNotchSize` (69-74) | 改用 `viewModel.scaledNotchSize` | 手动改 |
| 2 | `NotchView.topCornerRadius` / `bottomCornerRadius` (121-131) | 收起态值 `× notchScale`（默认 1.0 无变化；防缩小后圆角占比过大变形） | 手动改 |
| 3 | `NotchView` 外层 horizontal padding (155-160) | 收起态 `cornerRadiusInsets.closed.bottom × notchScale` | 手动改 |
| 4 | `NotchView` 静止态 spacer (283) | `closedNotchSize.width - 20` → `- 20 * notchScale` | 手动改 |
| 5 | `NotchView` 活动态 spacer (288) | `closedNotchSize.width - cornerRadiusInsets.closed.top` → `× notchScale` | 手动改 |
| 6 | `NotchView.expansionWidth` / `sideWidth` (77-103, 318-320) | 基于已缩放的 `closedNotchSize.height`，大致跟随；公式偏移常数（-12 / +20 / +10）不缩放，活动扩张在小尺度下比例略大，可接受 | 大致自动 |
| 7 | `NotchView.headerRow.frame` height (236 / 315) | 读 `closedNotchSize.height`；236 行 `max(24, ...)` 在 scale < 0.63 时钳到 24pt | 自动（带上限） |
| 8 | `NotchViewController.hitTestRect` 收起分支 (64-74) | 宽高改用 `× notchScale`（**点击穿越约定**） | 手动改 |
| 9 | `NotchGeometry.notchScreenRect` / `isPointInNotch` (18-43) | 加 `scale: CGFloat = 1.0` 参数，内部 `× scale`（默认 1.0 向后兼容） | 手动改 |
| 10 | `NotchViewModel.handleMouseMove` / `handleMouseDown` (160, 194, 201) | 调用 `isPointInNotch` / `notchScreenRect` 时传 `notchScale` | 手动改 |

> 第 3-5 项是收起态宽度的固定内边距 / spacer 常数。`NotchView` 收起态是「spacer 凑宽度 + 固定 padding」的 ad-hoc 布局，这些常数不缩放会导致调小后实际宽度不按比例变化、与行内预览（精确 `frame(scaledSize)`）不一致，必须同步 `× notchScale`。

不受影响（确认不动）：`openedSize`、`isPointInOpenedPanel`、`handleStatusChange` 的 `hasPhysicalNotch` 隐藏逻辑、boot 动画逻辑。

## 6. 关键代码片段

### 6.1 `AppSettings.notchScale`（`Core/Settings.swift`）

```swift
private enum Keys {
    static let notificationSound = "notificationSound"
    static let claudeDirectoryName = "claudeDirectoryName"
    static let appLanguage = "appLanguage"
    static let notchScale = "notchScale"          // 新增
}

// MARK: - Notch Scale

/// 收起态灵动岛缩放因子。0.6~1.5，默认 1.0（= 当前尺寸）。
/// 未设置 key 时回退 1.0；非法值钳制到范围内。
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

> 用 `object(forKey:) as? Double` 区分「未设置」与「合法值」，避免 `double(forKey:)` 默认 0 的歧义。

### 6.2 `NotchViewModel`（`Core/NotchViewModel.swift`）

```swift
// 与现有 @Published 并列
@Published var notchScale: Double

// init 内（读入持久化值）
self.notchScale = AppSettings.notchScale

/// 收起态缩放后的尺寸（单一真相，供 NotchView 与 hit-test 使用）
var scaledNotchSize: CGSize {
    CGSize(
        width: deviceNotchRect.width * notchScale,
        height: deviceNotchRect.height * notchScale
    )
}
```

hit-test 调用处传 scale：

```swift
// handleMouseMove
let inNotch = geometry.isPointInNotch(location, scale: notchScale)

// handleMouseDown opened 分支（点击刘海区关闭）
} else if geometry.notchScreenRect(scale: notchScale).contains(location) { ... }

// handleMouseDown closed/popping 分支
if geometry.isPointInNotch(location, scale: notchScale) { ... }
```

### 6.3 `NotchGeometry`（`Core/NotchGeometry.swift`）

`notchScreenRect` 由计算属性改为带默认参数的函数（默认 1.0 向后兼容）：

```swift
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

func isPointInNotch(_ point: CGPoint, scale: CGFloat = 1.0) -> Bool {
    notchScreenRect(scale: scale).insetBy(dx: -10, dy: -5).contains(point)
}
```

### 6.4 `NotchView`（`UI/Views/NotchView.swift`）

```swift
private var closedNotchSize: CGSize {
    viewModel.scaledNotchSize
}

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

此外，收起态宽度的内边距与 spacer 常数（位于 `body` 内，非计算属性）也需同步 `× notchScale`，否则实际宽度不按比例变化、与预览不符（联动清单第 3-5 项）：

```swift
// 外层 horizontal padding（NotchView.swift:155-160）
.padding(
    .horizontal,
    viewModel.status == .opened
        ? cornerRadiusInsets.opened.top
        : cornerRadiusInsets.closed.bottom * viewModel.notchScale
)

// 静止态 spacer（NotchView.swift:283）
.frame(width: closedNotchSize.width - 20 * viewModel.notchScale)

// 活动态 spacer（NotchView.swift:288）；bounce 偏移 16 是动画量，不缩放
.frame(width: closedNotchSize.width - cornerRadiusInsets.closed.top * viewModel.notchScale + (isBouncing ? 16 : 0))
```

### 6.5 `NotchViewController.hitTestRect`（`UI/Window/NotchViewController.swift`）

收起分支改用 scaled 尺寸（闭包内已有 `vm = self.viewModel`，可读 `vm.notchScale`）：

```swift
case .closed, .popping:
    let scaledWidth = geometry.deviceNotchRect.width * vm.notchScale
    let scaledHeight = geometry.deviceNotchRect.height * vm.notchScale
    let screenWidth = geometry.screenRect.width
    return CGRect(
        x: (screenWidth - scaledWidth) / 2 - 10,
        y: windowHeight - scaledHeight - 5,
        width: scaledWidth + 20,
        height: scaledHeight + 10
    )
```

### 6.6 新组件 `NotchSizeSliderRow` + 预览（`UI/Views/NotchMenuView.swift`）

```swift
/// 行内真实尺寸预览：随 scale 实时缩放的收起态小条
struct NotchSizePreview: View {
    let scale: Double
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
            AppSettings.notchScale = newValue          // 持久化（setter 内钳制）
        }
    }
}
```

`NotchMenuView` 外观区插入位置（`LanguagePickerRow()` 之后）：

```swift
ScreenPickerRow(screenSelector: screenSelector)
SoundPickerRow(soundSelector: soundSelector)
ClaudeDirPickerRow()
LanguagePickerRow()
NotchSizeSliderRow(viewModel: viewModel)              // 新增
```

> 预览宽度上限：`224 × 1.5 = 336pt`，小于 menu 面板内宽（~440pt），1:1 真实尺寸可完整容纳，不会溢出。

## 7. 边界情况

1. **设备行为**：无刘海旧设备（fallback `224×38`）调小→减少遮挡（核心场景）；有刘海设备默认贴合、调小露菜单栏、调大覆盖菜单栏。不做分支，全局自由调。
2. **动画**：预览即时跟手（无 spring 延迟）；真实岛收起态变化由现有 `.animation(...value: notchSize)`（`NotchView.swift:180`）自然过渡，无需新增动画代码。
3. **性能**：拖动高频触发 `NotchView` 重画，但展开态只重画 `NotchMenuView`（含预览），内容轻，可接受。列为观察项，必要时对持久化写加 throttle。
4. **钳制**：`AppSettings.notchScale` setter 钳到 `0.6~1.5`；Slider `in: 0.6...1.5` 同步约束。
5. **`hasPhysicalNotch` 可见性逻辑不变**：无刘海设备缩放后仍保持可见可点（`hitTestRect` 已用 scaled 尺寸保证可点）。
6. **收起态有活动**（processing / permission / waiting）：缩放后 crab / spinner / checkmark 图标尺寸固定（14pt），可能略挤，可接受。
7. **高度下限**：`headerRow.frame(height: max(24, closedNotchSize.height))`（`NotchView.swift:236`）在 scale < 0.63 时高度钳到 24pt（默认 38pt × 0.6 = 22.8pt → 实际 24pt，差 ≤1.2pt），可忽略。
8. **预览与真实的固定偏差**：预览用 `frame(scaledNotchSize)` 渲染基准尺寸；真实小条因布局固有内边距比 `deviceNotchRect` 略宽（约 +8pt × scale）。两者不会同屏对比，趋势与比例一致，不影响「观察是否合适」。

## 8. 本地化

新增 1 个 key 到 `CcIslandCn/Resources/Localizable.xcstrings`：

- `"Notch Size"` → `zh-Hans`: `"灵动岛大小"`

预览区无文字；百分比是纯数字 + `%`，无需本地化。遵循项目约定：`Text("Notch Size")` 自动按 key 查表。

## 9. 验证

项目无 `Tests/`，手动验证为主，可选补单测。

### 建议补但不阻塞（纯逻辑，易测）

- `NotchGeometry` scaled 几何：给定 `deviceNotchRect` + `scale`，断言 `notchScreenRect(scale:)` 居中且尺寸 = 原始 × scale；`isPointInNotch` 边界正确。
- `AppSettings.notchScale` 钳制：未设置→1.0；set `0.3`→`0.6`；set `2.0`→`1.5`；set `1.0`→`1.0`。

### 手动验证清单（理想环境：无刘海旧设备 + Claude Code 活跃会话）

1. 无刘海设备：调小→收起态变小、遮挡减少；预览实时跟手；点击区跟手。
2. 有刘海设备：默认贴合；调小两侧露菜单栏；调大覆盖菜单栏。
3. 百分比显示正确（60%~150%）。
4. 重启 app：scale 持久化生效。
5. 换屏 / 多屏：重建 `viewModel`，scale 从 `AppSettings` 读入一致。
6. 收起态有活动：缩放后 crab / spinner / checkmark 仍正常。
7. **点击穿越不破**（三个核心约定之一）：收起态点岛→展开；展开态点岛外→关闭并穿透下层；缩放后均正常。

## 10. 风险

- **主要风险**：联动 6 处，漏一处即点击 / 视觉错位 → 已列清单（第 5 节）+ 验收项（第 9 节）覆盖。
- **次要风险**：滑块拖动时真实岛不实时变（被展开态遮住）→ 已由行内真实预览解决。
- **发版**：用户可见功能，实现时 `CURRENT_PROJECT_VERSION` build +1；`MARKETING_VERSION` 是否升 minor 视当时版本定。

## 11. 后续

本 spec 经用户审查通过后，交由 `writing-plans` skill 生成实现计划。
