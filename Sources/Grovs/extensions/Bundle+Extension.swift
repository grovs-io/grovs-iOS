//
//  Bundle+Extension.swift
//
//  grovs
//

import Foundation

extension Bundle {

    static var framework: Bundle {
        get {
            let bundle = Bundle(for: Grovs.self)

            return bundle
        }
    }
}
