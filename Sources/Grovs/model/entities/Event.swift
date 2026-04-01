//
//  Event.swift
//
//  grovs
//

import Foundation

/// An enumeration representing different types of events.
enum EventType: String {
    case appOpen = "app_open"
    case view = "view"
    case open = "open"
    case install = "install"
    case reinstall = "reinstall"
    case timeSpent = "time_spent"
    case reactivation = "reactivation"
}

/// A class representing an event with type, creation date, link, and engagement time.
class Event: NSObject, NSSecureCoding {

    static var supportsSecureCoding: Bool { true }

    // MARK: - Properties

    /// Unique identifier for this event.
    let id: UUID

    /// The type of the event.
    let type: EventType

    /// The creation date of the event.
    let createdAt: Date

    /// The link associated with the event.
    var link: String?

    /// The engagement time associated with the event.
    var engagementTime: Int?

    // MARK: - Initialization

    /// Initializes an event with the specified parameters.
    ///
    /// - Parameters:
    ///   - type: The type of the event.
    ///   - createdAt: The creation date of the event.
    ///   - link: The link associated with the event. Default is nil.
    ///   - engagementTime: The engagement time associated with the event. Default is nil.
    init(type: EventType, createdAt: Date, link: String? = nil, engagementTime: Int? = nil) {
        self.id = UUID()
        self.type = type
        self.createdAt = createdAt
        self.link = link
        self.engagementTime = engagementTime
    }

    // MARK: - NSCoding

    func encode(with coder: NSCoder) {
        coder.encode(id.uuidString, forKey: "id")
        coder.encode(type.rawValue, forKey: "type")
        coder.encode(createdAt, forKey: "createdAt")
        coder.encode(link, forKey: "link")
        coder.encode(engagementTime, forKey: "engagementTime")
    }

    required init?(coder: NSCoder) {
        guard let typeRawValue = coder.decodeObject(of: NSString.self, forKey: "type") as String?,
              let type = EventType(rawValue: typeRawValue),
              let createdAt = coder.decodeObject(of: NSDate.self, forKey: "createdAt") as Date?
        else {
            return nil
        }

        // Backwards compatible: generate a new UUID if none was persisted
        if let idString = coder.decodeObject(of: NSString.self, forKey: "id") as String?,
           let id = UUID(uuidString: idString) {
            self.id = id
        } else {
            self.id = UUID()
        }
        self.type = type
        self.createdAt = createdAt
        self.link = coder.decodeObject(of: NSString.self, forKey: "link") as String?
        self.engagementTime = coder.decodeObject(of: NSNumber.self, forKey: "engagementTime") as? Int
    }

    // MARK: - Backend Conversion

    /// Converts the event to a dictionary format suitable for backend transmission.
    ///
    /// - Returns: A dictionary containing the event data.
    func toBackend() -> [String: Any] {
        return ["event": type.rawValue, "link": link as Any, "engagement_time": engagementTime as Any, "created_at": createdAt.backendDateString()]
    }
}
