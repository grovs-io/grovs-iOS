<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://s3.eu-north-1.amazonaws.com/grovs.io/full-white.svg">
    <img src="https://s3.eu-north-1.amazonaws.com/grovs.io/full-black.svg" width="120" alt="Grovs">
  </picture>
</p>

<p align="center">
  <a href="https://github.com/grovs-io/grovs-iOS/releases"><img src="https://img.shields.io/github/v/release/grovs-io/grovs-iOS?style=flat-square&color=4F46E5" alt="Latest release"/></a>
  <a href="https://swiftpackageindex.com/grovs-io/grovs-iOS"><img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fgrovs-io%2Fgrovs-iOS%2Fbadge%3Ftype%3Dswift-versions" alt="Swift versions"/></a>
  <a href="https://swiftpackageindex.com/grovs-io/grovs-iOS"><img src="https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fgrovs-io%2Fgrovs-iOS%2Fbadge%3Ftype%3Dplatforms" alt="Platforms"/></a>
  <a href="https://cocoapods.org/pods/Grovs"><img src="https://img.shields.io/cocoapods/v/Grovs.svg?style=flat-square&color=4F46E5" alt="CocoaPods"/></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/grovs-io/grovs-iOS?style=flat-square&color=4F46E5" alt="MIT License"/></a>
  <a href="https://github.com/grovs-io/grovs-iOS/stargazers"><img src="https://img.shields.io/github/stars/grovs-io/grovs-iOS?style=flat-square&color=4F46E5" alt="GitHub stars"/></a>
</p>

<p align="center">
  Deep linking, attribution, and smart links for iOS.<br/>
  Part of the <a href="https://github.com/grovs-io">Grovs</a> open-source mobile linking platform.
</p>

<p align="center">
  <a href="https://docs.grovs.io/docs/sdk/ios/quick-start">Quick Start</a> ·
  <a href="https://docs.grovs.io/docs/sdk/ios/api-reference">API Reference</a> ·
  <a href="https://docs.grovs.io">Full Docs</a>
</p>

---

The Grovs iOS SDK provides deep linking, universal linking, link generation, in-app messaging, revenue tracking, and attribution for your iOS apps. It supports both Swift and Objective-C.

## Features

- **Deep linking & universal links** — route users to the right in-app screen, even after install
- **Smart link generation** — create trackable links with metadata, custom redirects, and UTM parameters
- **In-app messaging** — display messages and announcements from the Grovs dashboard
- **Push notifications** — receive push notifications for dashboard-sent messages
- **Revenue tracking** — log StoreKit 2 and custom purchases with automatic attribution
- **User identity** — attach user IDs and attributes for analytics and segmentation
- **Self-hosting support** — point the SDK at your own backend

## Requirements

- iOS 13.0+
- Swift 5.0+
- Xcode 14+

## Installation

### Swift Package Manager

1. In Xcode, go to **File → Swift Packages → Add Package Dependency**
2. Enter the repository URL: `https://github.com/grovs-io/grovs-iOS.git`
3. Select the version range that fits your project
4. Click **Next**, then **Finish**

### CocoaPods

Add the pod to your `Podfile`:

```ruby
pod 'Grovs'
```

Then run:

```bash
pod install
```

## Quick Start

### 1. Initialize the SDK

Import the module and configure the SDK in your `AppDelegate`:

```swift
import Grovs

func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    Grovs.configure(APIKey: "your-api-key", useTestEnvironment: false, delegate: self) { success in
        if success {
            print("Grovs SDK is ready")
        }
    }

    // Optional: enable debug logging
    Grovs.setDebug(level: .info)

    // Optional: set user identity for analytics
    Grovs.userIdentifier = "user_id_from_your_app"
    Grovs.userAttributes = ["name": "John Doe", "plan": "premium"]

    return true
}
```

For self-hosted backends, pass the `baseURL` parameter (domain only — the SDK appends the API path):

```swift
Grovs.configure(APIKey: "your-api-key", useTestEnvironment: false, baseURL: "https://your-domain.com", delegate: self)
```

### 2. Forward delegate calls

#### Apps using SceneDelegate

```swift
func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    Grovs.handleSceneDelegate(openURLContexts: URLContexts)
}

func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    Grovs.handleSceneDelegate(continue: userActivity)
}

func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    Grovs.handleSceneDelegate(options: connectionOptions)
}
```

#### Apps using AppDelegate only

```swift
func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
    return Grovs.handleAppDelegate(continue: userActivity, restorationHandler: restorationHandler)
}

func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
    return Grovs.handleAppDelegate(open: url, options: options)
}
```

### 3. Handle deep links

Conform to the `GrovsDelegate` protocol to receive deep link callbacks:

```swift
class YourViewController: UIViewController, GrovsDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()
        Grovs.delegate = self
    }

    func grovsReceivedPayloadFromDeeplink(link: String?, payload: [String: Any]?, tracking: [String: Any]?) {
        // Route the user based on payload data
        if let screen = payload?["screen"] as? String {
            navigateTo(screen)
        }
    }
}
```

You can also retrieve past payloads:

```swift
// Get the most recent payload
Grovs.lastReceivedPayload { payload in
    print("Last payload: \(payload)")
}

// Get all payloads received since app launch
Grovs.allReceivedPayloadsSinceStartup { payloads in
    guard let payloads = payloads else { return }
    for payload in payloads {
        print("Payload: \(payload)")
    }
}
```

## Link Generation

Create smart links with metadata, payload data, and tracking parameters:

```swift
Grovs.generateLink(
    title: "Check out this product",
    subtitle: "Limited time offer",
    imageURL: "https://example.com/image.jpg",
    data: ["productId": "12345", "screen": "product_detail"],
    tags: ["promotion", "share"],
    trackingCampaign: "spring_sale",
    trackingSource: "in_app",
    trackingMedium: "share_button"
) { url in
    guard let url = url else { return }
    print("Generated link: \(url)")
}
```

### Custom redirects

Override where a link sends users on each platform:

```swift
let redirects = CustomRedirects(
    ios: CustomLinkRedirect(link: "https://example.com/ios-promo"),
    android: CustomLinkRedirect(link: "https://example.com/android-promo"),
    desktop: CustomLinkRedirect(link: "https://example.com/desktop-promo", openAppIfInstalled: false)
)

Grovs.generateLink(title: "Special offer", data: ["promoId": "summer25"], customRedirects: redirects) { url in
    guard let url = url else { return }
    print("Generated link: \(url)")
}
```

### Share sheet

Present a share sheet after generating a link:

```swift
Grovs.generateLink(title: "Share this", data: ["itemId": "abc"]) { url in
    guard let url = url else { return }
    let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
    self.present(activityVC, animated: true)
}
```

## Messages

> If console messages have **automatic display** enabled in your dashboard, they will appear in your app without any additional integration.

### Push notifications

To receive push notifications for messages sent from the Grovs dashboard:

**1. Add capabilities** — In Xcode, add the **Push Notifications** capability and enable **Remote notifications** under **Background Modes**.

**2. Upload your APNs key** — In [Apple Developer → Keys](https://developer.apple.com/account/resources/authkeys/list), create a key with APNs enabled. Upload the `.p8` file, Key ID, and Team ID in your [Grovs dashboard](https://app.grovs.io) under **Settings → Push Notifications**.

**3. Request permission and register:**

```swift
import UserNotifications

UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
    if granted {
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
}
```

**4. Pass the device token to Grovs:**

```swift
func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    Grovs.pushToken = token
}
```

> Push notifications do not work in the iOS Simulator. Test on a physical device.

### Display messages

```swift
// Show the messages list as a modal
Grovs.displayMessagesViewController {
    // Modal was dismissed
}

// Get unread count for badges
Grovs.numberOfUnreadMessages { count in
    print("Unread: \(count)")
}
```

## Revenue Tracking

> Revenue tracking is currently in **beta**.

### Setup

1. Enable revenue tracking in the [Grovs dashboard](https://app.grovs.io) under **Settings → Revenue Tracking**
2. Configure App Store Server Notifications in [App Store Connect](https://appstoreconnect.apple.com) — set the production and sandbox URLs shown in the Grovs dashboard under **Developers → iOS Setup → Revenue**

### App Store purchases (StoreKit 2)

```swift
import StoreKit

let result = try await Product.purchase(...)

if case .success(let verification) = result,
   case .verified(let transaction) = verification {

    Grovs.logInAppPurchase(transactionID: transaction.id) { success in
        if success {
            Task { await transaction.finish() }
        }
    }
}
```

> Requires iOS 15+. The SDK automatically extracts price, currency, and product info. Duplicates are filtered.

### Custom purchases

```swift
Grovs.logCustomPurchase(
    type: .buy,
    priceInCents: 999,       // $9.99
    currency: "USD",
    productID: "premium_monthly"
) { success in
    // Revenue event recorded
}
```

Use `.cancel` and `.refund` transaction types for cancellations and refunds. For App Store purchases, these are detected automatically via App Store Server Notifications.

## API Reference

### Properties

| Property | Type | Description |
|---|---|---|
| `delegate` | `GrovsDelegate?` | Receives deep link callbacks |
| `userIdentifier` | `String?` | User ID shown in dashboard and reports |
| `userAttributes` | `[String: Any]?` | User attributes for analytics |
| `pushToken` | `String?` | APNs device token for push notifications |

### Key Methods

| Method | Description |
|---|---|
| `configure(APIKey:useTestEnvironment:baseURL:delegate:completion:)` | Initialize the SDK |
| `setSDK(enabled:)` | Enable or disable the SDK |
| `setDebug(level:)` | Set logging level (`.info`, `.warn`, `.error`) |
| `generateLink(...)` | Generate a smart link |
| `lastReceivedPayload(completion:)` | Get the last deep link payload |
| `allReceivedPayloadsSinceStartup(completion:)` | Get all payloads since launch |
| `linkDetails(path:completion:)` | Get details for a link path |
| `displayMessagesViewController(completion:)` | Show messages modal |
| `numberOfUnreadMessages(completion:)` | Get unread message count |
| `logInAppPurchase(transactionID:completion:)` | Log a StoreKit 2 purchase |
| `logCustomPurchase(type:priceInCents:currency:productID:startDate:completion:)` | Log a custom purchase |

Full API reference: [docs.grovs.io/docs/sdk/ios/api-reference](https://docs.grovs.io/docs/sdk/ios/api-reference)

## Example App

A demo project is available at [grovs-io/grovs-ios-example-app](https://github.com/grovs-io/grovs-ios-example-app).

## Setup Guides

- [Custom URL Scheme](https://docs.grovs.io/docs/how-to-guides/ios/url-scheme) — configure deep link URL schemes
- [Associated Domains](https://docs.grovs.io/docs/how-to-guides/ios/associated-domain) — set up universal links
- [Apple App Prefix](https://docs.grovs.io/docs/how-to-guides/ios/apple-app-prefix) — find your Team ID
- [Bundle Identifier](https://docs.grovs.io/docs/how-to-guides/ios/bundle-identifier) — find your bundle ID

## Migration Guides

- [Migrate from Firebase Dynamic Links](https://docs.grovs.io/docs/migration-guides/firebase-dynamic-links/ios)
- [Migrate from Branch.io](https://docs.grovs.io/docs/migration-guides/branch-io/ios)

## Documentation

Full documentation at [docs.grovs.io](https://docs.grovs.io).

## Support

For technical support and inquiries, contact [support@grovs.io](mailto:support@grovs.io).

## License

See [LICENSE](LICENSE) for details.
