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

## Installation

```swift
// Package.swift
.package(url: "https://github.com/usmanmazharr/loupe.git", from: "1.0.0"),

// target dependencies
.product(name: "Loupe", package: "loupe"),
```

For Release builds, depend on `LoupeNoop` instead — same API surface, no captures, no UI, no cost.

---

## Quick start

```swift
import Loupe

@main
struct MyApp: App {
    init() {
        Loupe.shared.start()  // capture starts immediately
    }
    var body: some Scene { WindowGroup { ContentView() } }
}
```

That's it — every network call from this point on is captured.

### Open the debug UI

```swift
// UIKit
LoupeViewController.present(from: self)

// SwiftUI
.sheet(isPresented: $showLoupe) {
    LoupeView(isPresented: $showLoupe)
}

// Or shake your device — enabled by default in DEBUG.
```

### Track analytics events

```swift
Loupe.shared.trackEvent("checkout_started",
                        provider: "Mixpanel",
                        properties: ["plan": "pro"])
```

Events auto-attribute to the current screen (set via `Loupe.shared.setCurrentScreen(_:)`, the `.loupeScreen("Cart")` SwiftUI modifier, or auto-detected from `UIViewController.viewDidAppear`).

### Mirror `OSLog` into the Console tab

```swift
Loupe.shared.startConsoleMirror(subsystems: ["com.myapp"])
```

### Stub responses with the Mock Engine

```swift
Loupe.shared.addMockRule(
    .init(urlPattern: ".*\\/users\\/me",
          method: "GET",
          statusCode: 200,
          responseBody: #"{"id":1,"name":"Loupe"}"#.data(using: .utf8))
)
```

### Stream to the macOS companion

In your iOS app:
```swift
var config = LoupeConfiguration()
config.remoteLoggingEnabled = true
Loupe.shared.start(with: config)
```

Add `NSLocalNetworkUsageDescription` and `NSBonjourServices` (`_loupe._tcp`) to your `Info.plist`, then run the macOS app:

```bash
swift run LoupeMacApp
```

Your device will appear in the sidebar. Click to attach.

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
