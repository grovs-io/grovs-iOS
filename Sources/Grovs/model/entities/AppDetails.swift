//
//  AppDetails.swift
//
//  grovs
//

/// A structure representing details of the application.
struct AppDetails: Codable {
    let version: String
    let build: String
    let bundle: String
    let device: String
    let deviceID: String
    let userAgent: String

    /// Coding keys for decoding and encoding.
    private enum CodingKeys : String, CodingKey {
        case version, build, bundle, device, deviceID, userAgent
    }

    /// Converts the app details to a backend-compatible dictionary.
    ///
    /// - Returns: A dictionary containing the app details.
    func toBackend() -> [String: Any] {
        return [
            "user_agent": userAgent,
            "vendor_id": deviceID,
            "app_version": version,
            "build": build,
            "device": device
        ]
    }
}
