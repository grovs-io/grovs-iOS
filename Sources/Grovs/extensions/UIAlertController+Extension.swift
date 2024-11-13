//
//  UIAlertController+Extension.swift
//
//  grovs
//

import Foundation
import UIKit

/// A private view controller used as a container for presenting the alert.
/// It sets the preferred status bar style to light content.
fileprivate class AlertContainerViewController: UIViewController {
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
}

extension UIAlertController {

    /// A struct containing associated keys for extending `UIAlertController`.
    private struct AssociatedKeys {
        static var activityIndicator = "xxx_window"  // Key for associating a custom window.
    }

    /// A computed property to get or set a custom UIWindow associated with the alert controller.
    var xxx_window: UIWindow? {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.activityIndicator) as? UIWindow
        }
        set {
            if let newValue = newValue {
                objc_setAssociatedObject(
                    self,
                    &AssociatedKeys.activityIndicator,
                    newValue as UIWindow?,
                    .OBJC_ASSOCIATION_RETAIN_NONATOMIC
                )
            }
        }
    }

    /// Presents the alert controller on a new window.
    ///
    /// This method creates a new `UIWindow` and sets it as the key window with a level above the main window.
    /// The alert controller is then presented on this new window's root view controller.
    func showOnANewWindow() {
        // Create a new window for the alert and set its root view controller.
        xxx_window = UIWindow(frame: UIScreen.main.bounds)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            xxx_window = UIWindow(windowScene:scene)
        }

        xxx_window?.rootViewController = AlertContainerViewController()

        // Set the window level above the main window to ensure visibility.
        if let topWindow = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) {
            xxx_window?.windowLevel = topWindow.windowLevel + 1
        }

        xxx_window?.makeKeyAndVisible()
        xxx_window?.rootViewController?.present(self, animated: true, completion: nil)
    }
}
