//
//  ActivityViewController.swift
//  CellGuard
//
//  Created by Lukas Arnold on 23.01.23.
//

import UIKit
import SwiftUI

// SwiftUI on iOS 14 doesn't allow to show the share, thus we have to resort back to UIKit.
// Author: samwize (https://stackoverflow.com/a/60137973)

struct ActivityViewController: UIViewControllerRepresentable {
    
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    
    @Environment(\.presentationMode)
    var presentationMode
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<ActivityViewController>) -> UIActivityViewController {
        // Create the share controller
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        // Dismiss this view if the controller is dismissed
        controller.completionWithItemsHandler = { (activityType, completed, returnedItems, error) in
            self.presentationMode.wrappedValue.dismiss()
        }
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // Doing nothing
    }
    
}
