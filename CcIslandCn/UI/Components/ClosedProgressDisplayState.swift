//
//  ClosedProgressDisplayState.swift
//  CcIslandCn
//
//  收起态中间区域「会话进度」的显示窗口管理。
//  有会话在跑时实时跟随；全部停下后保留最终进度一段停留时间再淡出，
//  让用户看清「3 个任务跑完几个了」之后安静下来。
//

import Combine
import Foundation

@MainActor
final class ClosedProgressDisplayState: ObservableObject {
    struct Progress: Equatable {
        let completed: Int
        let total: Int
    }

    /// 当前应展示的进度（有会话在跑，或全部停下后的停留窗口内）。
    @Published var displayedProgress: Progress?

    /// displayedProgress 进入「全部停下停留」的时刻；有会话在跑时为 nil。
    private var finishedAt: Date?

    /// 全部停下后保留显示的时长（秒）。
    private let dwell: TimeInterval = 2.0

    /// 由 NotchView 在会话列表变化（及首次出现）时调用。
    /// - anyRunning 为真：实时跟随当前进度；清空停留态。
    /// - anyRunning 变假且仍有展示进度：进入停留窗口，dwell 秒后淡出。
    func update(completed: Int, total: Int, anyRunning: Bool) {
        if anyRunning {
            displayedProgress = Progress(completed: completed, total: total)
            finishedAt = nil
        } else if displayedProgress != nil, finishedAt == nil {
            finishedAt = Date()
            scheduleClear()
        }
    }

    private func scheduleClear() {
        let dwellNanos = UInt64(dwell * 1_000_000_000)
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: dwellNanos)
            guard let self else { return }
            // 仅当仍处于「全部停下停留」且窗口已过才清空；
            // 期间若有会话恢复运行，finishedAt 会被置 nil，此处跳过。
            if let finishedAt = self.finishedAt,
               Date().timeIntervalSince(finishedAt) >= self.dwell {
                self.displayedProgress = nil
                self.finishedAt = nil
            }
        }
    }
}
