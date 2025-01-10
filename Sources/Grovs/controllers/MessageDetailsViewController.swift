//
//  MessageDetailsViewController.swift
//
//  grovs
//

import UIKit
import WebKit

/// A view controller that displays the details of a message using a web view.
class MessageDetailsViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {

    static func loadVCFromNib() -> MessageDetailsViewController? {
        var vc: MessageDetailsViewController?

#if SWIFT_PACKAGE
        vc = MessageDetailsViewController.init(nibName: "MessageDetailsViewController", bundle: Bundle.module)
#else
        vc = MessageDetailsViewController.init(nibName: "MessageDetailsViewController", bundle: Bundle.framework)
#endif

        return vc
    }

    @IBOutlet weak var activityIndicator: UIActivityIndicatorView! // Activity indicator to show loading state.
    @IBOutlet weak var webView: WKWebView!                        // Web view for displaying the message content.
    @IBOutlet weak var backButton: UIButton!                      // Back button for navigation.
    @IBOutlet weak var closeButton: UIButton!                     // Close button for dismissing the view.

    var notification: Notification?  // The notification to display.
    var manager: GrovsManager? // The manager responsible for marking the notification as read.
    var dismissalDelegate: DismissalDelegate?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // Configure activity indicator color.
        activityIndicator.tintColor = UIColor.systemGray
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Show or hide the back and close buttons based on navigation controller presence.
        if navigationController != nil {
            backButton.isHidden = false
            closeButton.isHidden = true
        } else {
            backButton.isHidden = true
            closeButton.isHidden = false
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Load the notification's URL in the web view.
        guard var urlString = notification?.accessURL?.absoluteString else {
            exitScreen()
            return
        }

        if !urlString.hasPrefix("http") {
            urlString = "https://" + urlString
        }

        guard let url = URL(string: urlString) else {
            return
        }

        let request = URLRequest(url: url)
        webView.load(request)
        webView.navigationDelegate = self
        webView.uiDelegate = self

        markNotificationAsRead() // Mark the notification as read when the view appears.
    }

    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        super.dismiss(animated: flag, completion: completion)

        // Notify the delegate when the view is dismissed
        dismissalDelegate?.viewControllerDidDismiss()
    }

    // MARK: - WKNavigationDelegate Methods

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        // Called when the web view begins loading content.
        startLoading()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Called when the web view finishes loading content.
        stopLoading()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        // Called when the web view fails to load content.
        stopLoading()
        print("Failed to load page: \(error.localizedDescription)")
    }

    // MARK: - Navigation UI delegate

    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
            UIApplication.shared.open(url)
        }
        
        return nil
    }

    // MARK: - Actions

    /// Handles the back button tap to exit the screen.
    @IBAction func back(_ sender: Any) {
        exitScreen()
    }

    /// Handles the close button tap to exit the screen.
    @IBAction func dismissVC(_ sender: Any) {
        exitScreen()
    }

    // MARK: - Private Methods

    /// Exits the screen by popping or dismissing the view controller.
    private func exitScreen() {
        if let navigationController {
            navigationController.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    /// Marks the notification as read using the manager.
    private func markNotificationAsRead() {
        guard let notification else { return }

        manager?.markNotificationAsRead(notificationID: notification.id, completion: { _ in
            print("Notification marked as read")
        })
    }

    /// Starts the activity indicator animation.
    private func startLoading() {
        activityIndicator.startAnimating()  // Start animating the indicator.
        activityIndicator.isHidden = false  // Make sure the indicator is visible.
    }

    /// Stops the activity indicator animation.
    private func stopLoading() {
        activityIndicator.stopAnimating()   // Stop animating the indicator.
        activityIndicator.isHidden = true   // Hide the indicator.
    }
}
