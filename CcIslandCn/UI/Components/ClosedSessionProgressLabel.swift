//
//  ClosedSessionProgressLabel.swift
//  CcIslandCn
//
//  收起态中间区域：把会话进度渲染成「清单图标 + 已完成/存活总数」（如 1/3）。
//  分母 = 存活会话总数，分子 = 已完成（waitingForInput）会话数。
//  与 ClosedToolLabel 同为中间区域的互斥内容，由用户配置二选一。
//

import SwiftUI

struct ClosedSessionProgressLabel: View {
    let completed: Int
    let total: Int

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "checklist")
                .font(.system(size: 10, weight: .semibold))
            Text("\(completed)/\(total)")
                .font(.system(size: 11, weight: .medium).monospacedDigit())
        }
        .foregroundStyle(.white.opacity(0.78))
        .lineLimit(1)
        .truncationMode(.tail)
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
