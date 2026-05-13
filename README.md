# Loupe

> A premium debugging companion for iOS — network, analytics, console, and mocks in one place. Captures everything with one call, presents it with a calm, editorial UI, and streams live to a macOS companion app.

Loupe started as a network logger and grew into a full-spectrum runtime inspector. Drop it into any iOS app and look closely at what's happening — with the precision of a jeweler's loupe.

---

## Highlights

- **Zero-boilerplate capture.** Swizzle-based `URLProtocol` interception picks up every `URLSession` request — Alamofire, native, third-party SDKs.
- **Beyond networking.** Analytics events (Mixpanel / Firebase / Adjust / Segment / Insider / custom), `OSLog` console mirror, mock-response engine, and per-screen attribution.
- **Live macOS companion.** Auto-discovers your device over Bonjour and streams entries, logs, and events in real time.
- **Security-first.** Auto-masks `Authorization`, cookies, passwords, tokens, SSN, card numbers, and any keys you configure.
- **On-device semantic search.** Powered by Apple's `NLEmbedding` — no cloud, no model bundling.
- **Premium minimal UI.** Porcelain · ink · sapphire palette; identical aesthetic across iOS and macOS.
- **Zero-overhead release builds.** Swap the `Loupe` target for `LoupeNoop` in production.

---

## Requirements

- iOS 15+ (iOS 16+ for full nav-bar flattening)
- macOS 13+ for the companion app
- Swift 5.9 · Xcode 15+

---

## Run on iOS

### 1. Install via Swift Package Manager

In Xcode: **File → Add Packages…** and paste the repo URL, or add it manually:

```swift
// Package.swift
.package(url: "https://github.com/usmanmazharr/loupe.git", from: "1.0.0"),

// target dependencies
.product(name: "Loupe", package: "loupe"),
```

For Release builds, depend on `LoupeNoop` instead — same API surface, no captures, no UI, no cost.

### 2. Start capturing

In your `AppDelegate` (or SwiftUI `App` init):

```swift
import Loupe

Loupe.shared.start()
```

Every `URLSession` request from this point on is captured automatically.

### 3. Open the debug UI

```swift
// UIKit
LoupeViewController.present(from: self)

// SwiftUI
.sheet(isPresented: $showLoupe) {
    LoupeView(isPresented: $showLoupe)
}
```

Or just **shake the device** — enabled by default in DEBUG.

### 4. Optional features

Track analytics events (auto-attributed to the current screen):
```swift
Loupe.shared.trackEvent("checkout_started",
                        provider: "Mixpanel",
                        properties: ["plan": "pro"])
```

Mirror `OSLog` into the Console tab:
```swift
Loupe.shared.startConsoleMirror(subsystems: ["com.myapp"])
```

Stub responses with the Mock Engine:
```swift
Loupe.shared.addMockRule(
    .init(urlPattern: ".*\\/users\\/me",
          method: "GET",
          statusCode: 200,
          responseBody: #"{"id":1,"name":"Loupe"}"#.data(using: .utf8))
)
```

---

## Run on macOS (companion app)

The macOS companion auto-discovers your iPhone over local Wi-Fi and streams everything live — network entries, console logs, analytics events.

### 1. Build and launch the Mac app

```bash
git clone https://github.com/usmanmazharr/loupe.git
cd loupe
swift run LoupeMacApp
```

### 2. Enable remote logging on iOS

```swift
var config = LoupeConfiguration()
config.remoteLoggingEnabled = true
Loupe.shared.start(with: config)
```

### 3. Add Bonjour entries to your iOS app's `Info.plist`

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>Connect to the Loupe debugging app on your Mac.</string>

<key>NSBonjourServices</key>
<array>
    <string>_loupe._tcp</string>
</array>
```

### 4. Attach

Make sure your iPhone and Mac are on the same Wi-Fi. Your device will appear in the Mac app's sidebar automatically — click to attach. That's it.

---

## Architecture

```
URLSession traffic ─┐
Analytics calls    ─┼─→ Interceptor / Stores ─→ LogManager (actor) ─→ Combine subjects ─→ SwiftUI / macOS
OSLog stream       ─┘                       └─→ SQLite store          └─→ RemoteServer (Bonjour TCP) ─→ macOS
```

- **`Loupe.swift`** — the public API surface
- **`Interceptor/`** — `URLProtocol` subclass with auto-swizzle
- **`Managers/`** — `LogManager` actor, security, exports, ring buffers
- **`Core/LogStore.swift`** — SQLite-backed persistence (configurable capacity)
- **`UI/SwiftUI/`** — `LoupeView`, request list, detail, timeline, insights, analytics, console, mocks
- **`Remote/`** — Bonjour-advertised TCP server with frame protocol
- **`AI/SemanticSearch.swift`** — on-device cosine ranking via `NLEmbedding`
- **`Sources/LoupeMacApp/`** — companion macOS app, AppKit-styled SwiftUI

---

## Security

All sensitive data is masked before storage and broadcast. Defaults cover:

- Headers: `Authorization`, `Cookie`, `Set-Cookie`, `X-Api-Key`, `X-Auth-Token`, …
- JSON keys: `password`, `token`, `secret`, `api_key`, `ssn`, `credit_card`, `cvv`, …
- URL query params: `token`, `key`, `secret`, …

Extend or override via `LoupeConfiguration.security`.

---

## Performance

- SQLite-backed store with configurable eviction (default 500 entries).
- Ring buffers for high-volume logs/events.
- Internal bypass session prevents re-interception loops.
- macOS companion uses change detection — only sends what's new.

---

## License

[MIT](LICENSE) © 2026 Muhammad Usman

---

## Acknowledgements

Inspired by [Pulse](https://github.com/kean/Pulse) and [Wormholy](https://github.com/pmusolino/Wormholy). Built from scratch with modern Swift concurrency, SwiftUI, and a clean layered architecture.
