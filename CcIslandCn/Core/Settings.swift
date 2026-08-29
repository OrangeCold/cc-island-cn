//
//  Settings.swift
//  CcIslandCn
//
//  App settings manager using UserDefaults
//

import Foundation

/// Available notification sounds
enum NotificationSound: String, CaseIterable {
    case none = "None"
    case pop = "Pop"
    case ping = "Ping"
    case tink = "Tink"
    case glass = "Glass"
    case blow = "Blow"
    case bottle = "Bottle"
    case frog = "Frog"
    case funk = "Funk"
    case hero = "Hero"
    case morse = "Morse"
    case purr = "Purr"
    case sosumi = "Sosumi"
    case submarine = "Submarine"
    case basso = "Basso"

    /// The system sound name to use with NSSound, or nil for no sound
    var soundName: String? {
        self == .none ? nil : rawValue
    }
}

/// 收起态中间区域的显示内容（二选一）
enum ClosedDisplayMode: String, CaseIterable {
    /// 工具摘要：正在执行的工具名与关键参数（默认）
    case runningTool = "runningTool"
    /// 会话进度：已完成会话数 / 存活会话总数（如 1/3）
    case sessionProgress = "sessionProgress"
}

enum AppSettings {
    private static let defaults = UserDefaults.standard

    // MARK: - Keys

    private enum Keys {
        static let notificationSound = "notificationSound"
        static let claudeDirectoryName = "claudeDirectoryName"
        static let appLanguage = "appLanguage"
        static let notchScale = "notchScale"
        static let autoExpand = "autoExpand"
        static let closedDisplayMode = "closedDisplayMode"
    }

    // MARK: - Notification Sound

    /// The sound to play when Claude finishes and is ready for input
    static var notificationSound: NotificationSound {
        get {
            guard let rawValue = defaults.string(forKey: Keys.notificationSound),
                  let sound = NotificationSound(rawValue: rawValue) else {
                return .pop // Default to Pop
            }
            return sound
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.notificationSound)
        }
    }

    // MARK: - Claude Directory

    /// The name of the Claude config directory under the user's home folder.
    /// Defaults to ".claude" (standard Claude Code installation).
    /// Change to ".claude-internal" (or similar) for enterprise/custom distributions.
    static var claudeDirectoryName: String {
        get {
            let value = defaults.string(forKey: Keys.claudeDirectoryName) ?? ""
            return value.isEmpty ? ".claude" : value
        }
        set {
            defaults.set(newValue.trimmingCharacters(in: .whitespaces), forKey: Keys.claudeDirectoryName)
        }
    }

    // MARK: - App Language

    /// 用户语言选择。未知值（旧版无 key / 手改 plist 的非法值）回退 `.system`（跟随系统）。
    static var appLanguage: AppLanguage {
        get {
            guard let rawValue = defaults.string(forKey: Keys.appLanguage) else {
                return .system
            }
            return AppLanguage(rawValue: rawValue) ?? .system
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.appLanguage)
        }
    }

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

    // MARK: - Closed Display Mode

    /// 收起态中间区域显示「工具摘要」还是「会话进度」（已完成会话数 / 存活会话总数）。
    /// 默认工具摘要；未知值（旧版无 key / 手改 plist 的非法值）回退默认。
    static var closedDisplayMode: ClosedDisplayMode {
        get {
            guard let rawValue = defaults.string(forKey: Keys.closedDisplayMode) else {
                return .runningTool
            }
            return ClosedDisplayMode(rawValue: rawValue) ?? .runningTool
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.closedDisplayMode)
        }
    }

    // MARK: - Auto Expand

    /// 会话「需要注意」（完成 / 权限请求）时，是否自动从收起态展开灵动岛面板。
    /// 默认 false（不自动展开）；用户主动的点击 / 悬停展开不受此开关影响。
    static var autoExpand: Bool {
        get {
            defaults.object(forKey: Keys.autoExpand) == nil
                ? false
                : defaults.bool(forKey: Keys.autoExpand)
        }
        set {
            defaults.set(newValue, forKey: Keys.autoExpand)
        }
    }
}
