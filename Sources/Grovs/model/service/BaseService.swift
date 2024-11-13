//
//  BaseService.swift
//
//  grovs
//

import Foundation

/// Closure typealias for JSON response handling
public typealias JSONClosure = (_ success: Bool, _ json: [String: Any]?) -> Void

/// Base service class for making network requests
open class BaseService: NSObject {

    // MARK: - Properties

    /// Configuration for background URLSession
    private let backgroundConfig = URLSessionConfiguration.background(withIdentifier: NSUUID().uuidString)

    /// Default URLSession configuration
    private let config = URLSessionConfiguration.default

    /// Operation queue for delegate callbacks
    private let delegateQueue = OperationQueue()

    /// URLSession instance for regular requests
    private var session: URLSession!

    /// URLSession instance for background requests
    private var backgroundSession: URLSession!

    /// Cached completion handler for background requests
    private var cachedCompletion: JSONClosure? = nil

    /// Retry delay for failed requests
    private var currentRetryDelay: Double = 10 // seconds

    // MARK: - Initialization

    override init() {
        delegateQueue.name = "background-queue-grovs"
        config.sessionSendsLaunchEvents = true

        super.init()

        session = URLSession(configuration: config, delegate: nil, delegateQueue: delegateQueue)
        backgroundSession = URLSession(configuration: backgroundConfig, delegate: self, delegateQueue: delegateQueue)
    }

    // MARK: - Request Methods

    /// Makes a network request with the given URLRequest.
    ///
    /// - Parameters:
    ///   - background: Indicates if the request should be made in the background.
    ///   - URLRequest: The URLRequest to be executed.
    ///   - completion: Completion handler to be called when the request finishes.

    func makeRequest(background: Bool = false, URLRequest: URLRequest, completion: @escaping JSONClosure) {
        if background {
            cachedCompletion = completion

            let task = backgroundSession.downloadTask(with: URLRequest)
            task.resume()

        } else {
            let task = session.dataTask(with: URLRequest) { (data, urlResponse, error) in

                if let error = error as? URLError {
                    // Check if the error is due to no internet connection
                    if error.code == .notConnectedToInternet || error.code == .timedOut || error.code == .networkConnectionLost {
                        // Retry
                        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + self.currentRetryDelay, execute: {
                            self.makeRequest(background: background, URLRequest: URLRequest, completion: completion)
                        })

                        if self.currentRetryDelay < 60 {
                            self.currentRetryDelay += 10
                        }
                        return
                    }
                }

                self.currentRetryDelay = 10

                guard error == nil, let data = data, let http = urlResponse as? HTTPURLResponse else {
                    completion(false, nil)
                    return
                }

                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any] {
                        DispatchQueue.main.async {
                            // Success
                            completion(http.statusCode == 200, json)
                        }
                        return
                    }

                    if let json = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [[String: Any]] {
                        DispatchQueue.main.async {
                            // Success
                            completion(http.statusCode == 200, ["value":json])
                        }
                        return
                    }

                } catch _ {}

                completion(false, nil)
            }

            task.resume()
        }
    }
}

// MARK: - URLSessionDownloadDelegate

extension BaseService: URLSessionDownloadDelegate {

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        defer {
            cachedCompletion = nil
        }

        cachedCompletion?(false, nil)
    }

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {

        defer {
            cachedCompletion = nil
        }

        do {
            let data = try Data(contentsOf: location)
            if let json = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any] {

                // Success
                cachedCompletion?(true, json)
                return
            }

        } catch {}

        cachedCompletion?(false, nil)
    }
}

