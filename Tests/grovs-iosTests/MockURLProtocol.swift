import Foundation
import XCTest

/// A URLProtocol subclass that intercepts network requests for testing.
/// Register it on a URLSessionConfiguration before creating your URLSession.
class MockURLProtocol: URLProtocol {

    /// Map of URL path → handler closure. The handler receives the request and returns (response, data).
    static var requestHandlers: [String: (URLRequest) throws -> (HTTPURLResponse, Data?)] = [:]

    /// Tracks all URL paths that were requested, in order.
    static var requestedPaths: [String] = []

    /// Path → expectation map. When a matching path is requested, the expectation is fulfilled.
    static var pathExpectations: [String: XCTestExpectation] = [:]

    static func reset() {
        requestHandlers.removeAll()
        requestedPaths.removeAll()
        pathExpectations.removeAll()
    }

    override class func canInit(with request: URLRequest) -> Bool {
        return true // intercept everything
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        // Reconstruct httpBody from httpBodyStream since URLProtocol strips httpBody
        var capturedRequest = request
        if capturedRequest.httpBody == nil, let stream = capturedRequest.httpBodyStream {
            stream.open()
            var data = Data()
            let bufferSize = 1024
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
            defer { buffer.deallocate() }
            while stream.hasBytesAvailable {
                let bytesRead = stream.read(buffer, maxLength: bufferSize)
                if bytesRead > 0 {
                    data.append(buffer, count: bytesRead)
                }
            }
            stream.close()
            capturedRequest.httpBody = data
        }

        let path = request.url?.path ?? ""
        if !path.isEmpty {
            Self.requestedPaths.append(path)
            Self.pathExpectations[path]?.fulfill()
        }

        guard let handler = MockURLProtocol.requestHandlers[path] else {
            let response = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocolDidFinishLoading(self)
            return
        }

        do {
            let (response, data) = try handler(capturedRequest)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if let data = data {
                client?.urlProtocol(self, didLoad: data)
            }
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
