//
//  ClosedDisplayModePickerRow.swift
//  CcIslandCn
//
//  收起态显示内容选择行：执行命令 / 会话进度。切换即时生效（无需重启）。
//

import SwiftUI

struct ClosedDisplayModePickerRow: View {
    @ObservedObject var viewModel: NotchViewModel
    @State private var isExpanded: Bool = false
    @State private var isHovered: Bool = false
    @State private var selection: ClosedDisplayMode = AppSettings.closedDisplayMode

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "rectangle.inset.filled")
                        .font(.system(size: 12))
                        .foregroundColor(textColor)
                        .frame(width: 16)

                    Text("Closed Display")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(textColor)

                    Spacer()

                    closedDisplayModeNameView(selection)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))
                        .lineLimit(1)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isHovered ? Color.white.opacity(0.08) : Color.clear)
                )
            }
            .buttonStyle(.plain)
            .onHover { isHovered = $0 }

            if isExpanded {
                VStack(spacing: 2) {
                    ForEach(ClosedDisplayMode.allCases, id: \.self) { mode in
                        ClosedDisplayModeOptionRow(
                            mode: mode,
                            isSelected: selection == mode
                        ) {
                            choose(mode)
                        }
                    }
                }
                .padding(.leading, 28)
                .padding(.top, 4)
            }
        }
        .onAppear { selection = AppSettings.closedDisplayMode }
    }

    private var textColor: Color {
        .white.opacity(isHovered ? 1.0 : 0.7)
    }

    private func choose(_ mode: ClosedDisplayMode) {
        selection = mode
        AppSettings.closedDisplayMode = mode
        // 运行时单一真相同步，收起态中间区域立即切换
        viewModel.closedDisplayMode = mode
        isExpanded = false
    }
}

private struct ClosedDisplayModeOptionRow: View {
    let mode: ClosedDisplayMode
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Circle()
                    .fill(isSelected ? TerminalColors.green : Color.white.opacity(0.2))
                    .frame(width: 6, height: 6)

                closedDisplayModeNameView(mode)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(isHovered ? 1.0 : 0.7))

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(TerminalColors.green)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? Color.white.opacity(0.06) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

/// 选项显示名（走本地化，key 即英文原文）
@ViewBuilder
fileprivate func closedDisplayModeNameView(_ mode: ClosedDisplayMode) -> some View {
    switch mode {
    case .runningTool: Text("Running Tool")
    case .sessionProgress: Text("Session Progress")
    }
}
