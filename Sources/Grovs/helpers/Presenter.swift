//
//  Presenter.swift
//
//  grovs
//

import UIKit

class DismissalDelegate: NSObject, UIAdaptivePresentationControllerDelegate {
    static let shared = DismissalDelegate() // Singleton instance

    var completion: GrovsEmptyClosure? // Store the completion closure

    // This method will be called when the presented view controller is dismissed
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        let block = completion
        completion = nil
        block?()
    }

    func viewControllerDidDismiss() {
        let block = completion
        completion = nil
        block?()
    }
}

class Presenter {

    /// Retrieves all currently presented view controllers of a specific type.
    /// - Parameter type: The class type of the view controllers to search for.
    /// - Returns: An array of view controllers of the specified type.
    static func getPresentedViewControllers<T: UIViewController>(ofType type: T.Type) -> [T] {
        var matchingViewControllers = [T]()

        // Start from the top view controller
        var viewController = getTopViewController()

        // Traverse all presented view controllers and filter by the specified type
        while let presentedVC = viewController?.presentedViewController {
            if let matchingVC = presentedVC as? T {
                matchingViewControllers.append(matchingVC)
            }
            viewController = presentedVC
        }

        return matchingViewControllers
    }

    /// Presents the given view controller on top of everything else in the app.
    /// - Parameters:
    ///   - viewController: The view controller to present.
    ///   - animated: A flag indicating whether to animate the presentation.
    ///   - completion: A block to execute after the presentation finishes.
    static func presentOnTop(_ viewController: UIViewController, animated: Bool = true, completion: (() -> Void)? = nil) {
        // Get the top most view controller
        if let topViewController = getTopViewController() {
            topViewController.present(viewController, animated: animated, completion: completion)
        }
    }

    /// Recursively find the top most view controller.
    /// - Returns: The top most view controller in the app.
    private static func getTopViewController() -> UIViewController? {
        // Get the key window based on the scene or legacy approach
        let keyWindow = getKeyWindow()

        // If we have the key window, find the root view controller
        var topController = keyWindow?.rootViewController

        // Loop through any presented view controllers to find the top one
        while let presentedViewController = topController?.presentedViewController {
            topController = presentedViewController
        }

        return topController
    }

    /// Retrieves the app's key window.
    /// - Returns: The key window in the application.
    static func getKeyWindow() -> UIWindow? {
        if #available(iOS 15, *) {
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .filter { $0.activationState == .foregroundActive }
                .first?.keyWindow
        }

        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
            .first?.windows.first { $0.isKeyWindow }
    }
}
