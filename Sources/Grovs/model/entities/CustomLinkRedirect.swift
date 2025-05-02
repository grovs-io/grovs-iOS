//
//  CustomLinkRedirect.swift
//  GrovsSDK
//
//  Created by Razvan Chelemen on 01.05.2025.
//

import UIKit

/// A structure representing a redirect on a set of devices.
public struct CustomLinkRedirect: Codable {
    public let link: String
    public var openAppIfInstalled: Bool = true
    
    public init(link: String, openAppIfInstalled: Bool = true) {
        self.link = link
        self.openAppIfInstalled = openAppIfInstalled
    }
    
    /// Converts the custom link redirect to a backend-compatible dictionary.
    ///
    /// - Returns: A dictionary containing the custom link redirect.
    func toBackend() -> [String: Any] {
        return [
            "url": link,
            "open_app_if_installed": openAppIfInstalled
        ]
    }
}

public struct CustomRedirects: Codable {
    public var ios: CustomLinkRedirect? = nil
    public var android: CustomLinkRedirect? = nil
    public var desktop: CustomLinkRedirect? = nil
    
    public init(ios: CustomLinkRedirect? = nil, android: CustomLinkRedirect? = nil, desktop: CustomLinkRedirect? = nil) {
        self.ios = ios
        self.android = android
        self.desktop = desktop
    }
}
