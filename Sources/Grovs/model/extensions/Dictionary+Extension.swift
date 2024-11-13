//
//  Dictionary+Extension.swift
//
//  grovs
//

import Foundation

extension Dictionary {

    /// Converts the dictionary to JSON data.
    ///
    /// - Returns: The JSON data representation of the dictionary.
    func dictToData() -> Data? {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: self, options: .prettyPrinted)

            return jsonData
        } catch {
            print(error.localizedDescription)
        }

        return nil
    }

    /// Converts the dictionary to a string representation.
    ///
    /// - Returns: A string representation of the dictionary.
    func toString() -> String {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: self, options: .prettyPrinted)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                return jsonString
            } else {
                return ""
            }
        } catch {
            print("Error converting dictionary to string: \(error)")
            return ""
        }
    }
}
