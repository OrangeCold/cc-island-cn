//
//  LanguagePickerRow.swift
//  CcIslandCn
//
//  语言选择行：跟随系统 / 简体中文 / English。选中后写偏好并提示重启生效。
//

import SwiftUI

struct LanguagePickerRow: View {
    @State private var isExpanded: Bool = false
    @State private var isHovered: Bool = false
    @State private var selection: AppLanguage = AppSettings.appLanguage
    @State private var showRelaunchAlert: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "globe")
                        .font(.system(size: 12))
                        .foregroundColor(textColor)
                        .frame(width: 16)

                    Text("Language")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(textColor)

                    Spacer()

                    displayNameView(selection)
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
                    ForEach(AppLanguage.allCases, id: \.self) { language in
                        LanguageOptionRow(
                            language: language,
                            isSelected: selection == language
                        ) {
                            choose(language)
                        }
                    }
                }
                .padding(.leading, 28)
                .padding(.top, 4)
            }
        }
        .onAppear { selection = AppSettings.appLanguage }
        .alert("Language changes take effect after restart", isPresented: $showRelaunchAlert) {
            Button("Restart Now") {
                AppLanguage.relaunch { ok in
                    if !ok {
                        print("Relaunch failed — user should restart manually")
                    }
                }
            }
            Button("Later", role: .cancel) {}
        } message: {
            Text("Restart the app to apply the new language.")
        }
    }

    private var textColor: Color {
        .white.opacity(isHovered ? 1.0 : 0.7)
    }

    private func choose(_ language: AppLanguage) {
        selection = language
        AppSettings.appLanguage = language
        language.apply()
        isExpanded = false
        showRelaunchAlert = true
    }

    /// 语言名：Follow System 走本地化；简体中文 / English 固定显示（语言名用各自语言是语言选择器惯例）。
    @ViewBuilder
    private func displayNameView(_ language: AppLanguage) -> some View {
        switch language {
        case .system: Text("Follow System")
        case .zhHans: Text(verbatim: "简体中文")
        case .en: Text(verbatim: "English")
        }
    }
}

private struct LanguageOptionRow: View {
    let language: AppLanguage
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Circle()
                    .fill(isSelected ? TerminalColors.green : Color.white.opacity(0.2))
                    .frame(width: 6, height: 6)

                displayName
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

    @ViewBuilder
    private var displayName: some View {
        switch language {
        case .system: Text("Follow System")
        case .zhHans: Text(verbatim: "简体中文")
        case .en: Text(verbatim: "English")
        }
    }
}
