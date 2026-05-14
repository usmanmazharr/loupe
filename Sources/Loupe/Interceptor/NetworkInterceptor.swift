import Foundation

// MARK: - NetworkInterceptor

public final class NetworkInterceptor: URLProtocol, @unchecked Sendable {

    private static let handledKey = "com.loupe.handled"

    // Associated-object key used to mark "bypass" configs created internally.
    // These configs must NOT get our interceptor re-injected on URLSession init.
    fileprivate static var bypassKey = "com.loupe.bypass"

    private var dataTask: URLSessionDataTask?
    private var entry: NetworkEntry?
    private var receivedData = Data()
    private var timing = TimingMetrics()
    private var internalSession: URLSession?

    // MARK: - Registration

    public static func register() {
        URLProtocol.registerClass(NetworkInterceptor.self)
        URLSessionConfiguration.lpSwizzle()
        URLSession.lpSwizzle()
    }

    public static func unregister() {
        URLProtocol.unregisterClass(NetworkInterceptor.self)
    }

    // MARK: - Injection helper

    /// Prepends `NetworkInterceptor` into `config.protocolClasses` if not already present.
    /// Internal so `Loupe.swift` can also call it.
    static func inject(into config: URLSessionConfiguration) {
        var classes = config.protocolClasses ?? []
        if !classes.contains(where: { $0 == NetworkInterceptor.self }) {
            classes.insert(NetworkInterceptor.self, at: 0)
        }
        config.protocolClasses = classes
    }

    // MARK: - URLProtocol

    override public class func canInit(with request: URLRequest) -> Bool {
        guard URLProtocol.property(forKey: handledKey, in: request) == nil else { return false }
        guard let scheme = request.url?.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else { return false }
        return true
    }

    override public class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override public class func requestIsCacheEquivalent(_ a: URLRequest, to b: URLRequest) -> Bool { false }

    override public func startLoading() {
        let mutableRequest = (request as NSURLRequest).mutableCopy() as! NSMutableURLRequest
        URLProtocol.setProperty(true, forKey: Self.handledKey, in: mutableRequest)

        timing = TimingMetrics(startDate: Date())
        let entry = buildEntry(from: mutableRequest as URLRequest)
        self.entry = entry

        Task { await LogManager.shared.begin(entry: entry) }

        if let rule = MockEngine.shared.matchingRule(for: mutableRequest as URLRequest) {
            serveMock(rule: rule, entry: entry)
            return
        }

        // Create a bypass session that makes real network calls without re-interception.
        let config = URLSessionConfiguration.lpBypass()
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        internalSession = session
        dataTask = session.dataTask(with: mutableRequest as URLRequest)
        dataTask?.resume()
    }

    override public func stopLoading() {
        dataTask?.cancel()
        dataTask = nil
        internalSession?.invalidateAndCancel()
        internalSession = nil
        if let entry, entry.status == .inProgress {
            var t = timing; t.endDate = Date()
            Task { await LogManager.shared.fail(id: entry.id, error: URLError(.cancelled), timing: t) }
        }
    }

    // MARK: - Mock

    private func serveMock(rule: MockRule, entry: NetworkEntry) {
        DispatchQueue.global().asyncAfter(deadline: .now() + max(0, rule.delay)) { [weak self] in
            guard let self else { return }
            var t = self.timing
            t.firstByteDate = Date()
            t.endDate = Date()

            if let errorCode = rule.errorCode {
                let err = URLError(errorCode)
                self.client?.urlProtocol(self, didFailWithError: err)
                Task { await LogManager.shared.fail(id: entry.id, error: err, timing: t) }
                return
            }

            let response = HTTPURLResponse(url: entry.url, statusCode: rule.statusCode,
                                           httpVersion: "HTTP/1.1", headerFields: rule.responseHeaders)!
            self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if let body = rule.responseBody { self.client?.urlProtocol(self, didLoad: body) }
            self.client?.urlProtocolDidFinishLoading(self)

            Task {
                await LogManager.shared.complete(
                    id: entry.id,
                    responseHeaders: rule.responseHeaders,
                    responseBody: rule.responseBody,
                    statusCode: rule.statusCode,
                    responseSize: Int64(rule.responseBody?.count ?? 0),
                    contentType: ContentType.parse(rule.responseHeaders["Content-Type"]),
                    timing: t, isMocked: true
                )
            }
        }
    }

    private func buildEntry(from request: URLRequest) -> NetworkEntry {
        let url = request.url ?? URL(string: "about:blank")!
        var body = request.httpBody
        if body == nil, let stream = request.httpBodyStream { body = Data(reading: stream) }
        return NetworkEntry(url: url, method: request.httpMethod ?? "GET",
                            requestHeaders: request.allHTTPHeaderFields ?? [:],
                            requestBody: body)
    }
}

// MARK: - URLSessionDataDelegate / TaskDelegate

extension NetworkInterceptor: URLSessionDataDelegate, URLSessionTaskDelegate {

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        receivedData.append(data)
        timing.firstByteDate = timing.firstByteDate ?? Date()
        let total = dataTask.countOfBytesExpectedToReceive
        if total > 0, let entry {
            Task { await LogManager.shared.updateProgress(id: entry.id, upload: nil,
                                                         download: Double(receivedData.count) / Double(total)) }
        }
        client?.urlProtocol(self, didLoad: data)
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask,
                           didReceive response: URLResponse,
                           completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        timing.firstByteDate = Date()
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        completionHandler(.allow)
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        timing.endDate = Date()
        if let error {
            client?.urlProtocol(self, didFailWithError: error)
            if let entry { Task { await LogManager.shared.fail(id: entry.id, error: error, timing: timing) } }
            return
        }
        client?.urlProtocolDidFinishLoading(self)
        guard let entry else { return }

        let statusCode  = task.response?.httpStatusCode ?? 0
        let headers     = task.response?.allHeaders ?? [:]
        let contentType = ContentType.parse(task.response?.contentMimeType)
        let maxBodySize = Loupe.shared.configuration.maxBodySize
        let bodyToStore = maxBodySize == 0 || receivedData.count <= maxBodySize
                          ? receivedData : Data(receivedData.prefix(maxBodySize))

        Task {
            await LogManager.shared.complete(
                id: entry.id, responseHeaders: headers, responseBody: bodyToStore,
                statusCode: statusCode, responseSize: Int64(receivedData.count),
                contentType: contentType, timing: timing, isMocked: false
            )
        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask,
                           didSendBodyData bytesSent: Int64, totalBytesSent: Int64,
                           totalBytesExpectedToSend: Int64) {
        guard totalBytesExpectedToSend > 0, let entry else { return }
        Task { await LogManager.shared.updateProgress(
            id: entry.id, upload: Double(totalBytesSent) / Double(totalBytesExpectedToSend), download: nil) }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask,
                           didFinishCollecting metrics: URLSessionTaskMetrics) {
        guard let entry else { return }
        Task { await LogManager.shared.updateTimingDetail(id: entry.id,
                                                         detail: NetworkTimingDetail(metrics: metrics)) }
    }
}

// MARK: - URLSessionConfiguration swizzle

extension URLSessionConfiguration {

    /// A clean ephemeral config with no protocol classes — used by the interceptor's
    /// own forwarding session so it never re-intercepts its own requests.
    static func lpBypass() -> URLSessionConfiguration {
        // Call the un-swizzled ephemeral getter (after swap, tf_ephemeral IS the original)
        let config = URLSessionConfiguration.tf_ephemeral
        config.protocolClasses = []
        // Tag it so the URLSession-init swizzle knows to skip injection
        objc_setAssociatedObject(config, &NetworkInterceptor.bypassKey,
                                 true, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return config
    }

    static func lpSwizzle() {
        let cls = URLSessionConfiguration.self
        swizzleClassMethod(cls,
                           original: #selector(getter: URLSessionConfiguration.default),
                           swizzled: #selector(getter: URLSessionConfiguration.tf_default))
        swizzleClassMethod(cls,
                           original: #selector(getter: URLSessionConfiguration.ephemeral),
                           swizzled: #selector(getter: URLSessionConfiguration.tf_ephemeral))
    }

    private static func swizzleClassMethod(_ cls: AnyClass, original: Selector, swizzled: Selector) {
        guard let orig = class_getClassMethod(cls, original),
              let swiz = class_getClassMethod(cls, swizzled)
        else { return }
        method_exchangeImplementations(orig, swiz)
    }

    @objc class var tf_default: URLSessionConfiguration {
        let c = self.tf_default   // after swap: calls original .default
        NetworkInterceptor.inject(into: c)
        return c
    }

    @objc class var tf_ephemeral: URLSessionConfiguration {
        let c = self.tf_ephemeral // after swap: calls original .ephemeral
        NetworkInterceptor.inject(into: c)
        return c
    }
}

// MARK: - URLSession init swizzle
//
// Hooks BOTH URLSession init forms with explicit @objc(selector) names so there
// is zero ambiguity about what ObjC selector Swift generates.

extension URLSession {

    static func lpSwizzle() {
        // initWithConfiguration:delegate:delegateQueue:  (designated init)
        lpSwizzleInit(
            original: NSSelectorFromString("initWithConfiguration:delegate:delegateQueue:"),
            swizzled: NSSelectorFromString("tf_initWithConfiguration:delegate:delegateQueue:")
        )
        // initWithConfiguration:  (convenience init — may or may not forward to the above)
        lpSwizzleInit(
            original: NSSelectorFromString("initWithConfiguration:"),
            swizzled: NSSelectorFromString("tf_initWithConfiguration:")
        )
    }

    private static func lpSwizzleInit(original: Selector, swizzled: Selector) {
        guard let orig = class_getInstanceMethod(URLSession.self, original),
              let swiz = class_getInstanceMethod(URLSession.self, swizzled)
        else { return }
        method_exchangeImplementations(orig, swiz)
    }

    // Explicit ObjC selector name to avoid Swift mangling surprises.
    @objc(tf_initWithConfiguration:delegate:delegateQueue:)
    func tf_initFull(
        _ configuration: URLSessionConfiguration,
        delegate: URLSessionDelegate?,
        delegateQueue: OperationQueue?
    ) -> URLSession {
        if !NetworkInterceptor.isBypass(configuration) {
            NetworkInterceptor.inject(into: configuration)
        }
        // After the swap, this selector points to the original init IMP.
        return tf_initFull(configuration, delegate: delegate, delegateQueue: delegateQueue)
    }

    @objc(tf_initWithConfiguration:)
    func tf_initShort(_ configuration: URLSessionConfiguration) -> URLSession {
        if !NetworkInterceptor.isBypass(configuration) {
            NetworkInterceptor.inject(into: configuration)
        }
        return tf_initShort(configuration)
    }
}

extension NetworkInterceptor {
    fileprivate static func isBypass(_ config: URLSessionConfiguration) -> Bool {
        objc_getAssociatedObject(config, &bypassKey) as? Bool == true
    }
}

// MARK: - InputStream → Data

private extension Data {
    init(reading stream: InputStream) {
        self.init()
        stream.open()
        let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)
        defer { buf.deallocate(); stream.close() }
        while stream.hasBytesAvailable {
            let n = stream.read(buf, maxLength: 4096)
            if n > 0 { append(buf, count: n) }
        }
    }
}
