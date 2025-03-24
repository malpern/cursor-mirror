import Foundation
@testable import CursorMirrorClient

// Mock URL Session for testing network requests
class MockURLSession {
    // Track the last request that was "sent"
    var lastRequest: URLRequest?
    
    // Configure response for different URLs
    var responsesByURL: [URL: (Data?, URLResponse?, Error?)] = [:]
    
    // Track number of requests made
    var requestCount = 0
    
    // Configure default response
    var defaultResponse: (Data?, URLResponse?, Error?) = (
        nil,
        HTTPURLResponse(url: URL(string: "http://localhost:8080")!, statusCode: 200, httpVersion: nil, headerFields: nil),
        nil
    )
    
    // Reset the mock
    func reset() {
        lastRequest = nil
        responsesByURL = [:]
        requestCount = 0
    }
    
    // Configure a response for a specific URL
    func setResponse(_ response: (Data?, URLResponse?, Error?), for url: URL) {
        responsesByURL[url] = response
    }
    
    // Configure success response for a URL
    func setSuccessResponse(for url: URL) {
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
        responsesByURL[url] = (nil, response, nil)
    }
    
    // Configure error response for a URL
    func setErrorResponse(for url: URL, error: Error) {
        responsesByURL[url] = (nil, nil, error)
    }
}

// Mock URLSession that conforms to the async/await pattern
class MockURLProtocol: URLProtocol {
    static var mockURLSession: MockURLSession?
    
    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        guard let mockSession = MockURLProtocol.mockURLSession else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        
        // Track the request
        mockSession.lastRequest = request
        mockSession.requestCount += 1
        
        // Get the appropriate response
        let (data, response, error) = mockSession.responsesByURL[request.url!] ?? mockSession.defaultResponse
        
        // Send the response
        if let error = error {
            client?.urlProtocol(self, didFailWithError: error)
        } else {
            if let data = data {
                client?.urlProtocol(self, didLoad: data)
            }
            if let response = response {
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            }
            client?.urlProtocolDidFinishLoading(self)
        }
    }
    
    override func stopLoading() {}
}

// Extension to create a mock URLSession
extension URLSession {
    static func makeMockSession(mockURLSession: MockURLSession) -> URLSession {
        MockURLProtocol.mockURLSession = mockURLSession
        
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        
        return URLSession(configuration: config)
    }
} 