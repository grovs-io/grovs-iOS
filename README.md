# Grovs iOS SDK

[Grovs](https://grovs.io) is a powerful SDK that enables deep linking and universal linking within your iOS applications. This document serves as a guide to integrate and utilize Grovs seamlessly within your project.

<br />
<br />

## Installation

### SPM

Grovs is available as a Swift Package Manager (SPM) package. You can add it to your project by following these steps:

1. In Xcode, go to File -> Swift Packages -> Add Package Dependency.
2. Enter the repository URL: `https://github.com/grovs-io/grovs-iOS`.
3. Select the version range that fits your project requirements.
4. Click Next, then Finish.
   <br />
   <br />

### COCOAPODS

To integrate the SDK using COCOCAPODS, add the pod to your Podfile

```
pod 'Grovs'
```

<br />
<br />

## Configuration

To configure the Grovs SDK within your application, follow these steps:

1. Import the Grovs module in your Swift file:

```swift
import Grovs
```

1. Initialize the SDK with your API key (usually in AppDelegate):

```swift
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {

        Grovs.configure(APIKey: "your-api-key", delegate: yourDelegate)

        # Optionally, you can adjust the debug level for logging:

        Grovs.setDebug(level: .info)

        ... Your other code ...
    }
```

### Scene Delegate Integration

If your application uses a scene delegate, you need to forward relevant calls to Grovs.

```swift
// Handle open URL contexts
@available(iOS 13.0, *)
func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    Grovs.handleSceneDelegate(openURLContexts: URLContexts)
}

// Handle continue user activity
func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    Grovs.handleSceneDelegate(continue: userActivity)
}

// Handle scene delegate options
@available(iOS 13.0, *)
func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    Grovs.handleSceneDelegate(options: connectionOptions)
}

```

### App Delegate Integration

If your application doesn't use a scene delegate, you should forward relevant calls from the app delegate to Grovs:

```swift
// Handle universal link continuation
func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
    return Grovs.handleAppDelegate(continue: userActivity, restorationHandler: restorationHandler)
}

// Handle URI opening
func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    return Grovs.handleAppDelegate(open: url, options: options)
}

```

## Usage

Once configured, you can utilize the various functionalities provided by Grovs.

### Handling deeplinks

You can receive deep link events by conforming to the GrovsDelegate protocol. Here's how you can implement it:

```swift
class YourViewController: UIViewController, GrovsDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()
        Grovs.delegate = self
    }

    // Implement the delegate method
    func grovsReceivedPayloadFromDeeplink(payload: [String: Any]) {
        // Handle the received payload here
    }
}

```

### Generating Links

```swift
Grovs.generateLink(title: "Link Title", subtitle: "Link Subtitle", imageURL: "imageURL", data: ["key": "value"]) { url in
    // Handle generated URL
}

```

### Using messages

IMPORTANT: if console messages have automatic display enabled, they will appear in your app without any additional integration required.

To receive push notifications for the received messages attach the device token to the SDK.

```swift
func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    // Convert token to a string
    let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
    let token = tokenParts.joined()

    print("Device Token: \(token)")

    // You can pass this token to the library
    Grovs.pushToken = token
}
```

To get the number of unread messages, for instance if you want to display an unread number bullet, you can use the following SDK method.

```swift
Grovs.numberOfUnreadMessages { count in
    print("Count \(count)")
}
```

To display the list of the messages on top of everthing else use:

```swift
Grovs.displayMessagesViewController {
    // Display has finished.
}
```



## Demo project

You can download and run a demo project [from here](https://github.com/grovs-io/grovs-ios-example-app).

## Further Assistance

For further assistance and detailed documentation, refer to the Grovs documentation available at https://docs.grovs.io/s/docs.

For technical support and inquiries, contact our support team at [support@grovs.io](mailto:support@grovs.io).

Thank you for choosing Grovs! We're excited to see what you build with our SDK.

<br />
<br />
Copyright Grovs.
