//
//  AlertHelper.swift
//
//  grovs
//

import Foundation
import UIKit

/// A struct representing an action button for an alert, containing a title and an optional action closure.
struct ButtonAction {
    let title: String                 // The title of the action button.
    let action: GrovsEmptyClosure? // The closure to be executed when the button is tapped.
}

/// A helper class for displaying alerts in the application.
class AlertHelper {

    /// Displays a generic error message on top of all other content.
    ///
    /// This method shows a default error alert with the message "Something went wrong, please try again!" and the title "Ooops!".
    static func showGenericError() {
        dismissAllNotifications()
        displayMessageOnTopOfEverything("Something went wrong, please try again!", title: "Ooops!")
    }

    /// Displays a message alert on top of all other content.
    ///
    /// - Parameters:
    ///   - message: The message to be displayed in the alert.
    ///   - title: The title of the alert.
    ///   - completion: An optional closure to be executed after the alert is dismissed.
    static func displayMessageOnTopOfEverything(_ message: String, title: String, completion: GrovsEmptyClosure? = nil) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .cancel) { _ in
            // Hide and remove the custom window used for the alert.
            alertController.xxx_window?.isHidden = true
            alertController.xxx_window = nil

            // Execute the completion closure, if provided.
            completion?()
        }

        alertController.addAction(action)
        alertController.showOnANewWindow()
    }

    /// Displays a message alert with multiple action options on top of all other content.
    ///
    /// - Parameters:
    ///   - message: The message to be displayed in the alert.
    ///   - title: The title of the alert.
    ///   - buttons: An array of `ButtonAction` representing the actions for the alert.
    static func displayMessageOnTopOfEverythingWithOptions(_ message: String, title: String, buttons: [ButtonAction]) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)

        for button in buttons {
            let action = UIAlertAction(title: button.title, style: .default) { _ in
                // Hide and remove the custom window used for the alert.
                removeAlert(alertController)
                // Execute the button's action, if provided.
                button.action?()
            }

            alertController.addAction(action)
        }

        alertController.showOnANewWindow()
    }

    /// Removes the specified alert from the screen by hiding its associated window.
    ///
    /// - Parameter alertController: The `UIAlertController` to be removed.
    static func removeAlert(_ alertController: UIAlertController) {
        alertController.xxx_window?.isHidden = true
        alertController.xxx_window = nil
    }

    /// Dismisses all currently presented alerts.
    static func dismissAllNotifications() {
        guard let rootViewController = UIApplication.shared.keyWindow?.rootViewController else {
            return
        }

        dismissAlerts(in: rootViewController)
    }

    /// Recursively dismisses alerts within the specified view controller and its children.
    ///
    /// - Parameter viewController: The `UIViewController` in which to search for presented alerts.
    private static func dismissAlerts(in viewController: UIViewController) {
        if let alertController = viewController as? UIAlertController {
            alertController.dismiss(animated: true, completion: nil)
        }

        for childViewController in viewController.children {
            dismissAlerts(in: childViewController)
        }

        if let presentedViewController = viewController.presentedViewController {
            dismissAlerts(in: presentedViewController)
        }
    }
}
