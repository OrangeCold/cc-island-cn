//
//  AppLanguage.swift
//  CcIslandCn
//
//  用户语言选择：跟随系统 / 简体中文 / English。
//  apply() 写 AppleLanguages；切换需重启 App 才生效，由 relaunch() 完成。
//

import AppKit
import Foundation
import os

private let logger = Logger(subsystem: "com.claudeisland", category: "AppLanguage")

/// 用户可选的语言。`.system` 表示跟随系统语言（不写 AppleLanguages）。
enum AppLanguage: String, CaseIterable {
    case system
    case zhHans = "zh-Hans"
    case en

    /// 按选择写或清 AppleLanguages。需重启 App 后由 Bundle 重新读取生效。
    func apply() {
        let defaults = UserDefaults.standard
        switch self {
        case .system:
            defaults.removeObject(forKey: "AppleLanguages")
        case .zhHans:
            defaults.set(["zh-Hans"], forKey: "AppleLanguages")
        case .en:
            defaults.set(["en"], forKey: "AppleLanguages")
        }
    }

    /// 重启自身。成功启动新实例后终止当前进程并回调 true；失败回调 false（调用方提示手动重启）。
    /// completion is called on the main thread.
    static func relaunch(completion: @escaping (Bool) -> Void) {
        let bundleURL = URL(fileURLWithPath: Bundle.main.bundlePath)
        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: bundleURL, configuration: configuration) { _, error in
            let result: Bool
            if let error {
                logger.error("Relaunch failed: \(error.localizedDescription)")
                result = false
            } else {
                DispatchQueue.main.async { NSApp.terminate(nil) }
                result = true
            }
            DispatchQueue.main.async { completion(result) }
        }
    }
}
