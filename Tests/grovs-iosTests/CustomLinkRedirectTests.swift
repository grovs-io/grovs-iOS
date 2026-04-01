import XCTest
@testable import Grovs

final class CustomLinkRedirectTests: XCTestCase {

    // MARK: - CustomLinkRedirect toBackend()

    func testToBackendMapsLinkToURLAndOpenAppIfInstalled() {
        let redirect = CustomLinkRedirect(link: "https://example.com")

        let dict = redirect.toBackend()

        XCTAssertEqual(dict["url"] as? String, "https://example.com")
        XCTAssertEqual(dict["open_app_if_installed"] as? Bool, true)
    }

    func testToBackendWithOpenAppIfInstalledFalse() {
        let redirect = CustomLinkRedirect(link: "https://other.com", openAppIfInstalled: false)

        let dict = redirect.toBackend()

        XCTAssertEqual(dict["url"] as? String, "https://other.com")
        XCTAssertEqual(dict["open_app_if_installed"] as? Bool, false)
    }

    // MARK: - Default values

    func testDefaultOpenAppIfInstalledIsTrue() {
        let redirect = CustomLinkRedirect(link: "https://test.com")
        XCTAssertTrue(redirect.openAppIfInstalled)
    }

    // MARK: - CustomRedirects

    func testCustomRedirectsInitWithAllNilDefaults() {
        let redirects = CustomRedirects()

        XCTAssertNil(redirects.ios)
        XCTAssertNil(redirects.android)
        XCTAssertNil(redirects.desktop)
    }

    func testCustomRedirectsCodableRoundTrip() throws {
        let original = CustomRedirects(
            ios: CustomLinkRedirect(link: "https://ios.com", openAppIfInstalled: true),
            android: CustomLinkRedirect(link: "https://android.com", openAppIfInstalled: false),
            desktop: CustomLinkRedirect(link: "https://desktop.com")
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CustomRedirects.self, from: data)

        XCTAssertEqual(decoded.ios?.link, "https://ios.com")
        XCTAssertEqual(decoded.ios?.openAppIfInstalled, true)
        XCTAssertEqual(decoded.android?.link, "https://android.com")
        XCTAssertEqual(decoded.android?.openAppIfInstalled, false)
        XCTAssertEqual(decoded.desktop?.link, "https://desktop.com")
        XCTAssertEqual(decoded.desktop?.openAppIfInstalled, true)
    }

    func testCustomRedirectsCodableRoundTripWithNils() throws {
        let original = CustomRedirects(ios: nil, android: nil, desktop: nil)

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CustomRedirects.self, from: data)

        XCTAssertNil(decoded.ios)
        XCTAssertNil(decoded.android)
        XCTAssertNil(decoded.desktop)
    }
}
