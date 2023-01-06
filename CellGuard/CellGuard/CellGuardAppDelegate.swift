//
//  CellGuardAppDelegate.swift
//  CellGuard
//
//  Created by Lukas Arnold on 02.01.23.
//

import Foundation
import UIKit

class CellGuardAppDelegate : NSObject, UIApplicationDelegate {
    
    // https://www.hackingwithswift.com/quick-start/swiftui/how-to-add-an-appdelegate-to-a-swiftui-app
    
    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        if let launchOptions = launchOptions {
            // https://developer.apple.com/documentation/corelocation/cllocationmanager/1423531-startmonitoringsignificantlocati
            if launchOptions[.location] != nil {
                _ = LocationDataManger(extact: false)
            }
        }
        
        // TODO: Implement background tasks for fetching the data https://developer.apple.com/documentation/uikit/app_and_environment/scenes/preparing_your_ui_to_run_in_the_background/using_background_tasks_to_update_your_app
        
        // Notifications? https://www.hackingwithswift.com/books/ios-swiftui/scheduling-local-notifications
        
        return true
    }
    
}
