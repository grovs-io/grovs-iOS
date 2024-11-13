//
//  UserAgentHelper.swift
//  grovs-ios-sdk-development
//
//  Created by Dragos Dobrean on 23.07.2024.
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

    // Shared WKWebView instance used to retrieve the user agent string.
    private static let webView = WKWebView(frame: .zero)

    // Delegate to handle web view navigation events.
    private static var delegate: WebViewNavigationDelegate!

    /// Retrieves the Safari user agent string by loading a minimal HTML page in a WKWebView.
    ///
    /// - Parameter completion: A closure to be called with the user agent string or nil if retrieval fails.
    static func getSafariUserAgent(completion: @escaping (String?) -> Void) {
        // Load a minimal HTML page to initialize the WebView.
        webView.loadHTMLString("<html></html>", baseURL: nil)

        // Initialize the delegate and assign it to the WebView's navigation delegate.
        delegate = WebViewNavigationDelegate {
            // Evaluate JavaScript to get the user agent string.
            webView.evaluateJavaScript("navigator.userAgent") { result, error in
                if let userAgent = result as? String {
                    // Pass the user agent string to the completion handler.
                    completion(userAgent)
                } else {
                    // Pass nil if an error occurred.
                    completion(nil)
                }
            }
        }

        // Assign the delegate to handle navigation events.
        webView.navigationDelegate = delegate
    }
}
