//
//  UserAgentHelper.swift
//
//  grovs
//


import Foundation
import WebKit

// MARK: - WebViewNavigationDelegate

/// A delegate class for handling WKWebView navigation events.
class WebViewNavigationDelegate: NSObject, WKNavigationDelegate {
    private let didFinish: () -> Void

    /// Initializes the delegate with a completion handler for when navigation finishes.
    ///
    /// - Parameter didFinish: A closure to be called when navigation finishes.
    init(didFinish: @escaping () -> Void) {
        self.didFinish = didFinish
    }

    /// Called when the web view finishes loading.
    ///
    /// - Parameter webView: The web view that finished loading.
    /// - Parameter navigation: The navigation object that finished loading.
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        didFinish()
    }
}

// MARK: - UserAgentHelper

/// A utility class for retrieving the Safari user agent string.
class UserAgentHelper {

    // Held alive only during the async user-agent fetch, then released.
    private static var activeWebView: WKWebView?
    private static var activeDelegate: WebViewNavigationDelegate?

    /// Retrieves the Safari user agent string by loading a minimal HTML page in a WKWebView.
    ///
    /// - Parameter completion: A closure to be called with the user agent string or nil if retrieval fails.
    static func getSafariUserAgent(completion: @escaping (String?) -> Void) {
        let webView = WKWebView(frame: .zero)
        activeWebView = webView

        webView.loadHTMLString("<html></html>", baseURL: nil)

        let delegate = WebViewNavigationDelegate {
            webView.evaluateJavaScript("navigator.userAgent") { result, error in
                activeWebView = nil
                activeDelegate = nil

                if let userAgent = result as? String {
                    completion(userAgent)
                } else {
                    completion(nil)
                }
            }
        }

        activeDelegate = delegate
        webView.navigationDelegate = delegate
    }
}
