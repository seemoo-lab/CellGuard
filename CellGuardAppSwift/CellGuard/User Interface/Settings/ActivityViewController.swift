//
//  ActivityViewController.swift
//  CellGuard
//
//  Created by Lukas Arnold on 23.01.23.
//

import UIKit
import SwiftUI

// Present sharing automatically after an asynchronous export completes.
// Author: samwize (https://stackoverflow.com/a/60137973)

struct ActivityViewController: UIViewControllerRepresentable {

    var activityItems: [Any]
    var applicationActivities: [UIActivity]?

    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: UIViewControllerRepresentableContext<ActivityViewController>) -> UIActivityViewController {
        // Create the share controller
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        // Dismiss this view if the controller is dismissed
        controller.completionWithItemsHandler = { (_, _, _, _) in
            self.dismiss()
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // Doing nothing
    }

}
