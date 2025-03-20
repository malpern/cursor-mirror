import Foundation
import Vapor

/// Filter for request logs
public struct LogFilter: Content {
    /// Method to filter by
    public let method: String?
    
    /// Path to filter by
    public let path: String?
    
    /// Status code to filter by
    public let status: Int?
}

/// Controller for admin dashboard
public actor AdminController {
    /// HTTP server manager
    private let serverManager: HTTPServerManager
    
    /// HLS stream manager
    private let streamManager: HLSStreamManager
    
    /// Authentication manager
    private let authManager: AuthenticationManager
    
    /// Logger
    private let logger: Logger
    
    /// Request logs
    private var requestLogs: [RequestLog] = []
    
    /// Maximum number of logs to keep
    private let maxLogs: Int = 1000
    
    /// Initialize with managers
    /// - Parameters:
    ///   - serverManager: HTTP server manager
    ///   - streamManager: HLS stream manager
    ///   - authManager: Authentication manager
    ///   - logger: Logger
    public init(
        serverManager: HTTPServerManager,
        streamManager: HLSStreamManager,
        authManager: AuthenticationManager,
        logger: Logger = Logger(label: "AdminController")
    ) {
        self.serverManager = serverManager
        self.streamManager = streamManager
        self.authManager = authManager
        self.logger = logger
    }
    
    /// Record a request log
    /// - Parameter log: Request log to record
    public func recordRequest(_ log: RequestLog) async {
        // Add to the beginning of the array
        requestLogs.insert(log, at: 0)
        
        // Trim if we have too many logs
        if requestLogs.count > maxLogs {
            requestLogs = Array(requestLogs.prefix(maxLogs))
        }
    }
    
    /// Get request logs
    /// - Parameter filter: Optional filter to apply
    /// - Returns: Filtered request logs
    public func getLogs(filter: LogFilter? = nil) -> [RequestLog] {
        guard let filter = filter else {
            return requestLogs
        }
        
        return requestLogs.filter { log in
            // Apply method filter if provided
            if let method = filter.method, !method.isEmpty, log.method != method {
                return false
            }
            
            // Apply path filter if provided
            if let path = filter.path, !path.isEmpty, !log.path.contains(path) {
                return false
            }
            
            // Apply status code filter if provided
            if let status = filter.status, log.status != status {
                return false
            }
            
            return true
        }
    }
    
    /// Custom authentication middleware for admin routes
    private struct AdminAuthMiddleware: AsyncMiddleware {
        let authManager: AuthenticationManager
        
        init(authManager: AuthenticationManager) {
            self.authManager = authManager
        }
        
        func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
            // Basic implementation for admin access
            // In a real app, you might want to check for specific admin roles
            
            // Check for basic auth credentials
            guard let auth = request.headers.basicAuthorization else {
                return Response(status: .unauthorized)
            }
            
            do {
                // Authenticate with basic credentials
                _ = try await authManager.authenticateBasic(username: auth.username, password: auth.password)
                return try await next.respond(to: request)
            } catch {
                return Response(status: .unauthorized)
            }
        }
    }
    
    /// Set up admin routes
    /// - Parameter app: Vapor application
    public func setupRoutes(_ app: Application) async {
        // Admin dashboard
        let adminRoutes = app.grouped("admin")
            .grouped(AdminAuthMiddleware(authManager: authManager))
        
        // Dashboard home
        adminRoutes.get { [weak self] (req: Request) -> View in
            guard let self = self else {
                throw Abort(.internalServerError)
            }
            
            // Get server stats
            let config = await self.serverManager.config
            let isRunning = await self.serverManager.isRunning
            let isStreaming = await self.streamManager.isStreaming
            
            // Render dashboard template
            return try await req.view.render("admin/dashboard", DashboardContext(
                serverConfig: config,
                isRunning: isRunning,
                isStreaming: isStreaming,
                requestCount: self.requestLogs.count
            ))
        }
        
        // Request logs
        adminRoutes.get("logs") { [weak self] (req: Request) -> View in
            guard let self = self else {
                throw Abort(.internalServerError)
            }
            
            // Get filter parameters
            let method = try? req.query.get(String.self, at: "method")
            let path = try? req.query.get(String.self, at: "path")
            let status = try? req.query.get(Int.self, at: "status")
            
            let filter = LogFilter(method: method, path: path, status: status)
            
            // Get filtered logs
            let logs = await self.getLogs(filter: filter)
            
            // Render logs template
            return try await req.view.render("admin/logs", LogsContext(
                logs: logs,
                filter: filter
            ))
        }
        
        // Stream management
        adminRoutes.get("stream") { [weak self] (req: Request) -> View in
            guard let self = self else {
                throw Abort(.internalServerError)
            }
            
            // Get stream info
            let isStreaming = await self.streamManager.isStreaming
            
            // Render stream page
            return try await req.view.render("admin/stream", StreamContext(
                isStreaming: isStreaming
            ))
        }
        
        // Force stop stream
        adminRoutes.post("stream/stop") { [weak self] (req: Request) -> Response in
            guard let self = self else {
                throw Abort(.internalServerError)
            }
            
            // Invalidate all streams
            await self.streamManager.invalidateAllStreams()
            
            return Response(status: .ok)
        }
    }
}

// MARK: - Template Contexts

/// Context for dashboard template
struct DashboardContext: Content {
    let serverConfig: ServerConfig
    let isRunning: Bool
    let isStreaming: Bool
    let requestCount: Int
}

/// Context for logs template
struct LogsContext: Content {
    let logs: [RequestLog]
    let filter: LogFilter
}

/// Context for stream template
struct StreamContext: Content {
    let isStreaming: Bool
} 