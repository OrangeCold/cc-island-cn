//
//  ClosedToolDisplayState.swift
//  CcIslandCn
//
//  收起态中间区域「正在执行的工具」的显示窗口管理。
//  running 时实时跟随当前工具；工具完成后保留摘要一段停留时间再淡出，
//  避免快速工具（Read / Grep / Edit）一闪而过、用户看不清。
//

import Combine
import Foundation

@MainActor
final class ClosedToolDisplayState: ObservableObject {
    /// 当前应展示的工具（running 中，或完成后停留窗口内）。
    @Published var displayedTool: ToolCallItem?

    /// displayedTool 进入「完成停留」的时刻；running 中为 nil。
    private var finishedAt: Date?

    /// 工具完成后保留显示的时长（秒）。
    private let dwell: TimeInterval = 2.0

    /// 由 NotchView 在 currentRunningTool 变化（及首次出现）时调用。
    /// - running 非空：实时跟随；清空完成态。
    /// - running 变空且当前仍有展示工具：进入停留窗口，dwell 秒后淡出。
    func update(running: ToolCallItem?) {
        if let tool = running {
            displayedTool = tool
            finishedAt = nil
        } else if displayedTool != nil, finishedAt == nil {
            finishedAt = Date()
            scheduleClear()
        }
    }

    private func scheduleClear() {
        let dwellNanos = UInt64(dwell * 1_000_000_000)
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: dwellNanos)
            guard let self else { return }
            // 仅当仍处于「完成停留」且窗口已过才清空；
            // 期间若有新 running 进入，finishedAt 会被置 nil，此处跳过。
            if let finishedAt = self.finishedAt,
               Date().timeIntervalSince(finishedAt) >= self.dwell {
                self.displayedTool = nil
                self.finishedAt = nil
            }
        }
    }
}
