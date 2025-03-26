import Foundation
import Vapor

/// Configuration for the HTTP server
public struct ServerConfig: Codable, Equatable, Sendable {
    /// Hostname to bind to
    public let hostname: String
    
    /// Port to listen on
    public let port: Int
    
    /// CORS configuration
    public let cors: CORSConfig?
    
    /// Authentication configuration
    public let authentication: ServerAuthConfig
    
    /// TLS configuration
    public let tls: TLSConfig?
    
    /// Whether to enable admin dashboard
    public let enableAdmin: Bool
    
    /// Whether to enable CORS
    public let enableCORS: Bool
    
    /// Default initializer
    /// - Parameters:
    ///   - hostname: Hostname to bind to (default: "localhost")
    ///   - port: Port to listen on (default: 8080)
    ///   - cors: CORS configuration (default: .default)
    ///   - authentication: Authentication configuration (default: .basic)
    ///   - tls: TLS configuration (default: nil)
    ///   - enableAdmin: Whether to enable admin dashboard (default: true)
    ///   - enableCORS: Whether to enable CORS (default: true)
    public init(
        hostname: String = "localhost",
        port: Int = 8080,
        cors: CORSConfig? = .default,
        authentication: ServerAuthConfig = .basic,
        tls: TLSConfig? = nil,
        enableAdmin: Bool = true,
        enableCORS: Bool = true
    ) {
        self.hostname = hostname
        self.port = port
        self.cors = cors
        self.authentication = authentication
        self.tls = tls
        self.enableAdmin = enableAdmin
        self.enableCORS = enableCORS
    }
    
    /// Get the device's local network IP address
    public static func getLocalIPAddress() -> String {
        var address: String = "localhost"
        
        // Get list of all interfaces
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return address
        }
        
        // Find a suitable IP address
        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee
            
            // Check for IPv4 or IPv6 interface
            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
                // Check if interface is en0 which is the primary interface on macOS
                let name = String(cString: interface.ifa_name)
                if name == "en0" {
                    // Convert interface address to a string (IPv4)
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                               &hostname, socklen_t(hostname.count),
                               nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                    
                    // Use the first IPv4 address from en0 interface
                    if addrFamily == UInt8(AF_INET) {
                        break
                    }
                }
            }
        }
        
        freeifaddrs(ifaddr)
        return address
    }
}

/// Configuration for Cross-Origin Resource Sharing (CORS)
public struct CORSConfig: Codable, Equatable, Sendable {
    /// Allowed origins
    public let allowedOrigins: [String]
    
    /// Allowed methods
    public let allowedMethods: [String]
    
    /// Allowed headers
    public let allowedHeaders: [String]
    
    /// Whether to allow credentials
    public let allowCredentials: Bool
    
    /// Cache expiration in seconds
    public let cacheExpiration: Int?
    
    /// Exposed headers
    public let exposedHeaders: [String]?
    
    /// Default initializer
    /// - Parameters:
    ///   - allowedOrigins: Allowed origins (default: ["*"])
    ///   - allowedMethods: Allowed methods (default: ["GET", "POST", "PUT", "DELETE", "OPTIONS"])
    ///   - allowedHeaders: Allowed headers (default: ["Accept", "Authorization", "Content-Type", "Origin", "X-Requested-With"])
    ///   - allowCredentials: Whether to allow credentials (default: false)
    ///   - cacheExpiration: Cache expiration in seconds (default: nil)
    ///   - exposedHeaders: Exposed headers (default: nil)
    public init(
        allowedOrigins: [String] = ["*"],
        allowedMethods: [String] = ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
        allowedHeaders: [String] = ["Accept", "Authorization", "Content-Type", "Origin", "X-Requested-With"],
        allowCredentials: Bool = false,
        cacheExpiration: Int? = nil,
        exposedHeaders: [String]? = nil
    ) {
        self.allowedOrigins = allowedOrigins
        self.allowedMethods = allowedMethods
        self.allowedHeaders = allowedHeaders
        self.allowCredentials = allowCredentials
        self.cacheExpiration = cacheExpiration
        self.exposedHeaders = exposedHeaders
    }
    
    /// Convert to Vapor's CORS configuration
    /// - Returns: Vapor CORS configuration
    public func toVaporConfig() -> Vapor.CORSMiddleware.Configuration {
        return .init(
            allowedOrigin: .custom(allowedOrigins.joined(separator: ", ")),
            allowedMethods: allowedMethods.compactMap { Vapor.HTTPMethod(rawValue: $0) },
            allowedHeaders: allowedHeaders.map { Vapor.HTTPHeaders.Name($0) },
            allowCredentials: allowCredentials,
            cacheExpiration: cacheExpiration,
            exposedHeaders: exposedHeaders?.map { Vapor.HTTPHeaders.Name($0) }
        )
    }
    
    /// Default CORS configuration
    public static let `default` = CORSConfig()
}

/// TLS configuration
public struct TLSConfig: Codable, Equatable, Sendable {
    /// Path to the certificate file
    public let certificatePath: String
    
    /// Path to the private key file
    public let privateKeyPath: String
    
    /// Initialize with certificate and key paths
    /// - Parameters:
    ///   - certificatePath: Path to the certificate file
    ///   - privateKeyPath: Path to the private key file
    public init(certificatePath: String, privateKeyPath: String) {
        self.certificatePath = certificatePath
        self.privateKeyPath = privateKeyPath
    }
}

/// Authentication configuration
public struct ServerAuthConfig: Codable, Equatable, Sendable {
    /// Authentication methods
    public enum AuthenticationMethod: String, Codable, Equatable, Sendable {
        /// Basic authentication with username/password
        case basic
        
        /// Token-based authentication
        case token
        
        /// Session-based authentication
        case session
    }
    
    /// Whether authentication is enabled
    public let enabled: Bool
    
    /// Authentication methods
    public let methods: [AuthenticationMethod]
    
    /// Session duration in seconds
    public let sessionDuration: TimeInterval
    
    /// Initialize with authentication settings
    /// - Parameters:
    ///   - enabled: Whether authentication is enabled
    ///   - methods: Allowed authentication methods
    ///   - sessionDuration: Session duration in seconds
    public init(
        enabled: Bool = true,
        methods: [AuthenticationMethod] = [.basic, .token],
        sessionDuration: TimeInterval = 3600
    ) {
        self.enabled = enabled
        self.methods = methods
        self.sessionDuration = sessionDuration
    }
    
    /// Basic authentication config
    public static let basic = ServerAuthConfig(
        enabled: true,
        methods: [.basic],
        sessionDuration: 3600
    )
    
    /// Token authentication config
    public static let token = ServerAuthConfig(
        enabled: true,
        methods: [.token],
        sessionDuration: 86400 // 24 hours
    )
    
    /// No authentication
    public static let none = ServerAuthConfig(
        enabled: false,
        methods: [],
        sessionDuration: 0
    )
} 