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
