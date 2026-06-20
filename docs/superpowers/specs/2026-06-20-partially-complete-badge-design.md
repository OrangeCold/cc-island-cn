# 灵动岛「部分完成」badge 设计

> 日期：2026-06-20 ｜ 状态：待用户复核

## 1. 背景与目标

当多个 Claude Code 会话同时运行、其中部分已完成（转入 `waitingForInput`）时，灵动岛收起态只要还有 1 个会话在 `processing`，spinner 就一直转——用户无法感知「已有会话完成了」。

本次在收起态 spinner 旁增加绿色对勾 badge，提示「部分会话已完成」，让用户在多会话并行时知道有可处理的完成项。

## 2. 现状（探索结论）

聚合核心在 `CcIslandCn/UI/Views/NotchView.swift`（非 `NotchViewModel`），用三个布尔 `contains` 判定整体状态：

- `isAnyProcessing`（行 33-35）：有 `processing` / `compacting`
- `hasPendingPermission`（行 38-40）：有 `waitingForApproval`
- `hasWaitingForInput`（行 43-55）：有 `waitingForInput` 且在 30s 窗口内

**bug 根因**：只要 1 个会话 `processing`，`isAnyProcessing` 永远为 true，spinner 永转，已完成会话的信号被短路（`handleProcessingChange` 行 381-404 以 `isProcessing` 优先）。

`SessionPhase.isActive` = `processing` / `compacting`；`waitingForInput` 属「完成」侧。

## 3. 范围

**仅改 `NotchView.swift`**：加 2 个派生属性 + `headerRow` 一个条件视觉分支。

**不改**：`SessionPhase`、`SessionStore`、`ClaudeSessionMonitor`、`handleProcessingChange`（badge 是纯视觉叠加，不影响 `visible` / `showActivity` 逻辑）。

## 4. 设计决策

### 4.1 形态：spinner + 绿色对勾 badge（不显示数字）
在 spinner 右侧叠加绿色对勾，复用现有 `ReadyForInputIndicatorIcon` 组件，语义与现有「完成待输入」态一致（「有完成」）。

### 4.2 完成口径：仅 `waitingForInput`
「跑完等输入」算完成。`ended` / `idle` 不计入（`ended` 通常已从列表消失，`idle` 语义模糊）。

### 4.3 触发条件：`isAnyProcessing && hasCompletedSession`
有会话在跑 + 有会话已完成，二者并存。

## 5. 实现

### 5.1 派生属性（`NotchView.swift` 第 33-55 行三个属性旁）

```swift
/// 是否存在已完成（waitingForInput）的会话。无时间窗口，持续判定。
private var hasCompletedSession: Bool {
    sessionMonitor.instances.contains { $0.phase == .waitingForInput }
}

/// 部分完成：有会话在跑且另有会话已完成。
private var isPartiallyComplete: Bool {
    isAnyProcessing && hasCompletedSession
}
```

### 5.2 视觉分支（`headerRow` 第 282-295 行的 spinner 分支内）

在现有 `if isProcessing || hasPendingPermission { ... ProcessingSpinner() ... }` 分支内，当 `isPartiallyComplete` 为真，在 `ProcessingSpinner()` 右侧叠加 `ReadyForInputIndicatorIcon()`，用 `.transition(.opacity)` 淡入淡出。

### 5.3 生命周期（纯状态驱动）

- **显示**：`isPartiallyComplete`（有 `processing`/`compacting` 且有 `waitingForInput`）
- **隐藏**：无在跑会话（→ 切到现有「全完成」绿色对勾整态，`isPartiallyComplete` 为 false）或无完成会话
- **不做「已读」消失语义**

## 6. 涉及文件

| 文件 | 改动 |
|------|------|
| `CcIslandCn/UI/Views/NotchView.swift` | 加 `hasCompletedSession` / `isPartiallyComplete` 派生属性；`headerRow` spinner 分支内条件叠加完成 badge |

## 7. 验证

无单测基建，手动验证：
1. 2 个会话：1 个 `processing` + 1 个 `waitingForInput` → spinner + 绿色对勾 badge 同时出现。
2. 全部 `waitingForInput`（无 `processing`）→ 现有「全完成」对勾整态，**无** badge（`isPartiallyComplete` 为 false）。
3. 仅 1 个 `processing`、无完成 → 仅 spinner，无 badge。
4. 会话从 `processing` 转为 `waitingForInput`（另一会话仍在跑）→ badge 淡入出现；反向则淡出。

## 8. 不做（YAGNI）

- 不显示完成数量
- 不做「已读」消失语义
- 不在展开列表额外标记（列表已有 phase 排序 + 状态点）
- 不做 badge 点击交互（收起态点击行为已有）
