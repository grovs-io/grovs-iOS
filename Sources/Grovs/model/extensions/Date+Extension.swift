//
//  Date+Extension.swift
//
//  grovs
//

import Foundation

extension Date {
    /// Converts a `Date` object to seconds since the Unix epoch.
    ///
    /// - Returns: The number of seconds since the Unix epoch (January 1, 1970, 00:00:00 UTC).
    func toSeconds() -> Int {
        return Int(self.timeIntervalSince1970)
    }

    /// Creates a `Date` object from a given number of seconds since the Unix epoch.
    ///
    /// - Parameter seconds: The number of seconds since the Unix epoch.
    /// - Returns: A `Date` object representing the specified number of seconds since the Unix epoch.
    static func fromSeconds(_ seconds: Int) -> Date {
        return Date(timeIntervalSince1970: TimeInterval(seconds))
    }

    /// Returns the number of days between the instance date and the provided date.
    /// - Parameter date: The date to compare with.
    /// - Returns: The difference in days between the two dates.
    func daysBetween(_ date: Date) -> Int? {
        let calendar = Calendar.current
        let startOfSelf = calendar.startOfDay(for: self)
        let startOfOtherDate = calendar.startOfDay(for: date)
        let components = calendar.dateComponents([.day], from: startOfSelf, to: startOfOtherDate)
        return components.day
    }

    /// Parses a string representing a date in the format "YYYY-MM-dd" and returns the corresponding `Date` object.
    ///
    /// - Parameter string: The string representing the date.
    /// - Returns: A `Date` object representing the date parsed from the string, or nil if parsing fails.
    static func dateOnlyFromBackend(string: String) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        dateFormatter.dateFormat = "YYYY-MM-dd"

        return dateFormatter.date(from: string)
    }

    /// Returns a string representation of the date formatted for backend communication.
    ///
    /// - Returns: A string representation of the date formatted for backend communication.
    func backendDateString() -> String {
        let dateFormatter = Date.backendDateFormatter()
        return dateFormatter.string(from: self)
    }

    /// Returns a date formatter configured for backend communication.
    ///
    /// - Returns: A `DateFormatter` instance configured with the appropriate date format for backend communication.
    static func backendDateFormatter() -> DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX") // set locale to reliable US_POSIX
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        return dateFormatter
    }
}
