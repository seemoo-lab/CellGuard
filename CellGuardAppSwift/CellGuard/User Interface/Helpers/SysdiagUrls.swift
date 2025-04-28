//
//  SysdiagUrls.swift
//  CellGuard
//
//  Created by Lukas Arnold on 26.04.25.
//

import Foundation
import UIKit
import OSLog

struct SysdiagUrls {

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: SysdiagUrls.self)
    )

    static func open(sysdiagnose fileName: String?) {
        let urlString: String

        if UserDefaults.standard.bool(forKey: UserDefaultsKeys.shortcutInstalled.rawValue) {
            if let fileName = fileName {
                guard let fileNameEncoded = fileName.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) else {
                    Self.logger.warning("Cannot encode sysdiagnose file name: \(fileName)")
                    return
                }

                // See: https://support.apple.com/de-de/guide/shortcuts/apd624386f42/ios
                urlString = "shortcuts://run-shortcut?name=Open%20Sysdiagnose&input=text&text=\(fileNameEncoded)"
            } else {
                urlString = "shortcuts://run-shortcut?name=Open%20Sysdiagnose"
            }
        } else {
            #if JAILBREAK
            // For jailbreaks <= iOS 18: https://github.com/FifiTheBulldog/ios-settings-urls/blob/master/settings-urls.md
            if let fileName = fileName {
                urlString = "App-prefs:Privacy&path=PROBLEM_REPORTING/DIAGNOSTIC_USAGE_DATA/\(fileName)"
            } else {
                urlString = "App-prefs:Privacy&path=PROBLEM_REPORTING/DIAGNOSTIC_USAGE_DATA/"
            }
            #else
            // Use UIApplication.openSettingsURLString if App Store validation should fail.
            // However this is more inconvenient for users as it always navigates to the app's settings page.
            urlString = "App-prefs:"
            #endif
        }

        guard let url = URL(string: urlString) else {
            Self.logger.warning("Cannot create shortcut URL to sysdiagnose: \(urlString)")
            return
        }

        guard UIApplication.shared.canOpenURL(url) else {
            Self.logger.warning("Cannot open shortcut URL to sysdiagnose: \(urlString)")
            return
        }

        Self.logger.debug("Opening shortcut for sysdiagnose: \(fileName ?? "nil") - \(url)")
        UIApplication.shared.open(url)
    }

    static func installShortcut() {
        // Lukas' shortcut to open a sysdiagnose in Preferences.app.
        // Until iOS 17, CellGuard could also use the same deep link schema, but
        // - the App Review Guidelines §2.5.1 forbids using internal APIs
        // - this has ceased working with iOS 18
        // See: https://dev.seemoo.tu-darmstadt.de/apple/cell-guard/-/issues/111
        // See: https://developer.apple.com/forums/thread/761314
        //
        // The shortcut works in four steps:
        // 1. Reset the Preferences.app by opening PROBLEM_REPORTING
        // 2. Load the recent diagnostic usage data by opening DIAGNOSTIC_USAGE_DATA
        // 3. Wait 2s until the content has loaded
        // 4. Open the targeted sysdiagnose (if its name was provided)
        //
        // We have to include the URL actions as required by iOS 14
        let urlString = "https://www.icloud.com/shortcuts/f61eaf9ab6c64d8c9de8dfbc57d92fcd"
        guard let url = URL(string: urlString) else {
            Self.logger.warning("Cannot create URL to install shortcut: \(urlString)")
            return
        }

        guard UIApplication.shared.canOpenURL(url) else {
            Self.logger.warning("Cannot open URL to install shortcut: \(urlString)")
            return
        }

        UIApplication.shared.open(url)
    }

}
