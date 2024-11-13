//
//  Message.swift
//
//  grovs
//

import Foundation

/// A structure representing a notification.
struct Notification: Codable {
    let id: Int                  // Unique identifier for the notification.
    let title: String            // The title of the notification.
    let updatedAt: Date          // The date when the notification was last updated.
    let subtitle: String?        // An optional subtitle for the notification.
    let autoDisplay: Bool        // Indicates whether the notification should be displayed automatically.
    let accessURL: URL?          // An optional URL associated with the notification.
    let read: Bool               // Indicates whether the notification has been read.

    /// Coding keys for decoding and encoding the notification.
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case updatedAt = "updated_at"
        case subtitle
        case autoDisplay = "auto_display"
        case accessURL = "access_url"
        case read
    }
}

/// A structure representing the response containing a list of notifications.
struct NotificationsResponse: Codable {
    let notifications: [Notification]  // Array of notifications.
}
