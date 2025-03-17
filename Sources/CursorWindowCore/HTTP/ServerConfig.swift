// Find the section for HTTP server configuration
public struct HTTPServerConfig: Equatable {
    /// Hostname to bind the server to
    public let hostname: String
    
    /// Port number for the server
    public let port: Int
    
    /// Whether to use SSL/TLS
    public let useSSL: Bool
    
    /// Path to SSL certificate file (if useSSL is true)
    public let certificatePath: String?
    
    /// Path to SSL key file (if useSSL is true)
    public let keyPath: String?
    
    /// Whether to enable admin dashboard
    public let enableAdmin: Bool
    
    /// Authentication configuration
    public let authentication: AuthenticationConfig
    
    /// CORS configuration
    public let enableCORS: Bool
    
    /// Cross-Origin Resource Sharing (CORS) allowed origin
    public let allowedOrigin: String
    
    /// CORS allowed methods
    public let allowedMethods: [HTTPMethod]
    
    /// CORS allowed headers
    public let allowedHeaders: [String]
    
    /// CORS allow credentials
    public let allowCredentials: Bool
    
    /// CORS cache expiration
    public let cacheExpiration: Int
    
    /// Rate limiting configuration
    public let rateLimit: RateLimitConfig
    
    /// Security configuration
    public let security: SecurityConfig
    
    /// Middleware configuration
    public let middleware: MiddlewareConfig
    
    /// Logging configuration
    public let logging: LoggingConfig
    
    /// Whether to enable CloudKit integration
    public let enableCloudKit: Bool
    
    // Create a modified constructor that includes the enableCloudKit parameter
    public init(
        hostname: String = "localhost",
        port: Int = 8080,
        useSSL: Bool = false,
        certificatePath: String? = nil,
        keyPath: String? = nil,
        enableAdmin: Bool = true,
        authentication: AuthenticationConfig = .disabled,
        enableCORS: Bool = true,
        allowedOrigin: String = "*",
        allowedMethods: [HTTPMethod] = [.GET, .POST, .PUT, .DELETE, .OPTIONS, .HEAD],
        allowedHeaders: [String] = ["Accept", "Authorization", "Content-Type", "X-Requested-With"],
        allowCredentials: Bool = false,
        cacheExpiration: Int = 600,
        rateLimit: RateLimitConfig = RateLimitConfig(),
        security: SecurityConfig = SecurityConfig(),
        middleware: MiddlewareConfig = MiddlewareConfig(),
        logging: LoggingConfig = LoggingConfig(),
        enableCloudKit: Bool = false
    ) {
        self.hostname = hostname
        self.port = port
        self.useSSL = useSSL
        self.certificatePath = certificatePath
        self.keyPath = keyPath
        self.enableAdmin = enableAdmin
        self.authentication = authentication
        self.enableCORS = enableCORS
        self.allowedOrigin = allowedOrigin
        self.allowedMethods = allowedMethods
        self.allowedHeaders = allowedHeaders
        self.allowCredentials = allowCredentials
        self.cacheExpiration = cacheExpiration
        self.rateLimit = rateLimit
        self.security = security
        self.middleware = middleware
        self.logging = logging
        self.enableCloudKit = enableCloudKit
    }
} 