import Foundation
@testable import Grovs

class MockUserDefaultsHelper: UserDefaultsHelperProtocol {
    var store: [UserDefaultsKeys: Int] = [:]

    var getIntCallCount = 0
    var setIntCallCount = 0

    func getInt(key: UserDefaultsKeys) -> Int {
        getIntCallCount += 1
        return store[key] ?? 0
    }

    func setInt(value: Int, key: UserDefaultsKeys) {
        setIntCallCount += 1
        store[key] = value
    }

    func reset() {
        store.removeAll()
        getIntCallCount = 0
        setIntCallCount = 0
    }
}
