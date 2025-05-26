//
//  AppDetailsHelper.swift
//
//  grovs
//

import Foundation
import UIKit
import WebKit

import WebKit

class AppDetailsHelper {

    private struct Constants {
        static let bundleShort = "CFBundleShortVersionString"
        static let bundleVersion = "CFBundleVersion"
        static let bundleIdentifier = "CFBundleIdentifier"

        static let unknownValue = "unknown"
    }

    // MARK: Methods

    /// Retrieves the details of the current app.
    ///
    /// - Returns: An instance of `AppDetails` containing app details.
    static func getAppDetails() -> AppDetails {
        let version: String = Bundle.main.object(forInfoDictionaryKey: Constants.bundleShort) as? String ?? Constants.unknownValue
        let build: String = Bundle.main.object(forInfoDictionaryKey: Constants.bundleVersion) as? String ?? Constants.unknownValue
        let bundle = getBundleID()

        let device = UIDevice.modelName

        let screenBounds = UIScreen.main.bounds
        let screenWidth = Int(max(screenBounds.width, screenBounds.height))
        let screenHeight = Int(min(screenBounds.width, screenBounds.height))

        let language = Locale.preferredLanguages.first
        let timeZone = TimeZone.current.identifier

        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? Constants.unknownValue
        let userAgent = getUserAgent()

        return AppDetails(version: version, build: build, bundle: bundle, device: device, deviceID: deviceID, userAgent: userAgent, screenWidth: screenWidth, screenHeight: screenHeight, language: language, timeZone: timeZone)
    }

    /// Retrieves the bundle identifier of the app.
    ///
    /// - Returns: The bundle identifier.
    static func getBundleID() -> String {
        return Bundle.main.object(forInfoDictionaryKey: Constants.bundleIdentifier) as? String ?? Constants.unknownValue
    }

    /// Retrieves the user agent string of the app.
    ///
    /// - Returns: The user agent string.
    static func getUserAgent() -> String {
        if let userAgent = Context.userAgent {
            return userAgent
        }

        if let userAgent = WKWebView().value(forKey: "userAgent") as? String {
            return userAgent
        }
        return ""
    }
}
