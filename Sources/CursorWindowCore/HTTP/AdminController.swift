import Foundation
import Vapor
import Leaf

/// Controller for handling admin dashboard routes
public class AdminController {
    private let httpServer: HTTPServerManager
    private let hlsManager: HLSStreamManager
    private let authManager: AuthenticationManager
    
    private var startTime: Date?
    private var requestLogs: [RequestLog] = []
    private var systemInfo: SystemInfo
    
    struct SystemInfo {
        let version: String
        let hostname: String
        let osInfo: String
        let ipAddress: String
    }
    
    struct RequestLog: Codable {
        let id: UUID
        let timestamp: Date
        let method: String
        let path: String
        let statusCode: Int
        let ipAddress: String
        let duration: Double
        let details: String?
    }
    
    struct LogFilter: Codable {
        var level: String
        var source: String
        var search: String
        var startDate: Date?
        var endDate: Date?
        var limit: Int
        
        init() {
            self.level = "info"
            self.source = "all"
            self.search = ""
            self.startDate = nil
            self.endDate = nil
            self.limit = 50
        }
    }
    
    public init(httpServer: HTTPServerManager, hlsManager: HLSStreamManager, authManager: AuthenticationManager) {
        self.httpServer = httpServer
        self.hlsManager = hlsManager
        self.authManager = authManager
        
        // Get system information
        let processInfo = ProcessInfo.processInfo
        let hostName = processInfo.hostName
        let osVersion = processInfo.operatingSystemVersionString
        
        self.systemInfo = SystemInfo(
            version: "1.0.0", // Replace with actual version
            hostname: hostName,
            osInfo: osVersion,
            ipAddress: "0.0.0.0" // Will be updated when server starts
        )
        
        // Initialize request logs storage
        self.requestLogs = []
    }
    
    // MARK: - Dashboard Routes
    
    func setupRoutes(_ app: RoutesBuilder) {
        // Register the admin routes
        let adminRoutes = app.grouped("admin")
        
        // Login page
        adminRoutes.get(use: loginPage)
        adminRoutes.get("login", use: loginPage)
        adminRoutes.post("login", use: performLogin)
        adminRoutes.get("logout", use: performLogout)
        
        // Protect all other admin routes with authentication
        let protectedRoutes = adminRoutes.grouped(AdminAuthMiddleware(authManager: authManager))
        
        // Main dashboard pages
        protectedRoutes.get("dashboard", use: dashboardPage)
        protectedRoutes.get(use: dashboardPage) // default route redirects to dashboard
        protectedRoutes.get("stream", use: streamPage)
        protectedRoutes.get("settings", use: settingsPage)
        protectedRoutes.get("logs", use: logsPage)
        
        // API endpoints for dashboard
        let apiRoutes = protectedRoutes.grouped("api")
        apiRoutes.get("server-status", use: getServerStatus)
        apiRoutes.get("stream-status", use: getStreamStatus)
        apiRoutes.get("recent-requests", use: getRecentRequests)
        apiRoutes.get("stream-history", use: getStreamHistory)
        apiRoutes.post("generate-api-key", use: generateApiKey)
        
        // Action endpoints
        protectedRoutes.post("server", "start", use: startServer)
        protectedRoutes.post("server", "stop", use: stopServer)
        protectedRoutes.post("server", "restart", use: restartServer)
        protectedRoutes.post("stream", "stop", use: stopStream)
        protectedRoutes.post("settings", "update", use: updateSettings)
        protectedRoutes.post("settings", "reset", use: resetSettings)
        protectedRoutes.post("logs", "clear", use: clearLogs)
        protectedRoutes.get("logs", "export", use: exportLogs)
    }
    
    // MARK: - Authentication Pages
    
    func loginPage(req: Request) throws -> EventLoopFuture<View> {
        return req.view.render("admin/login", ["error": req.query[String.self, at: "error"]])
    }
    
    func performLogin(req: Request) throws -> Response {
        guard let username = try? req.content.get(String.self, at: "username"),
              let password = try? req.content.get(String.self, at: "password") else {
            return req.redirect(to: "/admin/login?error=Invalid+credentials")
        }
        
        do {
            let token = try authManager.loginWithCredentials(username: username, password: password)
            
            // Set cookie with the token
            let response = req.redirect(to: "/admin")
            response.cookies["admin_token"] = HTTPCookies.Value(string: token, expires: Date().addingTimeInterval(3600), isHTTPOnly: true)
            return response
        } catch {
            return req.redirect(to: "/admin/login?error=Invalid+credentials")
        }
    }
    
    func performLogout(req: Request) throws -> Response {
        if let tokenString = req.cookies["admin_token"]?.string {
            try? authManager.invalidateToken(tokenString)
        }
        
        let response = req.redirect(to: "/admin/login")
        response.cookies["admin_token"] = HTTPCookies.Value(string: "", expires: Date(timeIntervalSince1970: 0))
        return response
    }
    
    // MARK: - Dashboard Pages
    
    func dashboardPage(req: Request) throws -> EventLoopFuture<View> {
        // Get server status
        let serverRunning = httpServer.isRunning
        
        // Get stream status
        let streamActive = isStreamActive()
        
        // Calculate uptime
        let uptime: String
        if let startTime = startTime, serverRunning {
            let interval = Date().timeIntervalSince(startTime)
            uptime = formatTimeInterval(interval)
        } else {
            uptime = "N/A"
        }
        
        // Get connection time if active
        let connectionTime: String
        if streamActive, let connection = try? hlsManager.activeConnection {
            connectionTime = formatDate(connection.connectedAt)
        } else {
            connectionTime = "N/A"
        }
        
        // Get auth settings
        let authEnabled = authManager.authenticationMethod != .none
        let authMethod = formatAuthMethod(authManager.authenticationMethod)
        
        // Get rate limiting settings
        let config = try httpServer.getConfig()
        let rateLimitEnabled = config.rateLimit.enabled
        let rateLimit = config.rateLimit.requestsPerMinute
        
        // Get recent requests (last 5)
        let recentRequests = Array(requestLogs.prefix(5).map { log in
            return [
                "time": formatTime(log.timestamp),
                "method": log.method,
                "path": log.path,
                "status": String(log.statusCode),
                "ip": log.ipAddress
            ]
        })
        
        // Prepare chart data (last 24 hours by hour)
        let calendar = Calendar.current
        let now = Date()
        var chartLabels: [String] = []
        var chartValues: [Int] = []
        
        for hour in 0..<24 {
            if let date = calendar.date(byAdding: .hour, value: -hour, to: now) {
                let hourString = formatHour(date)
                chartLabels.insert(hourString, at: 0)
                
                // Count requests in this hour
                let startOfHour = calendar.date(bySettingHour: calendar.component(.hour, from: date), minute: 0, second: 0, of: date)!
                let endOfHour = calendar.date(bySettingHour: calendar.component(.hour, from: date), minute: 59, second: 59, of: date)!
                
                let count = requestLogs.filter { log in
                    return log.timestamp >= startOfHour && log.timestamp <= endOfHour
                }.count
                
                chartValues.insert(count, at: 0)
            }
        }
        
        // Convert arrays to JSON strings for passing to the template
        let labelsJson = try JSONEncoder().encode(chartLabels)
        let valuesJson = try JSONEncoder().encode(chartValues)
        
        let chartLabelsString = String(data: labelsJson, encoding: .utf8) ?? "[]"
        let chartValuesString = String(data: valuesJson, encoding: .utf8) ?? "[]"
        
        // Prepare context
        let context: [String: Any] = [
            "section": "dashboard",
            "title": "Dashboard",
            "serverRunning": serverRunning,
            "uptime": uptime,
            "streamActive": streamActive,
            "connectionTime": connectionTime,
            "authEnabled": authEnabled,
            "authMethod": authMethod,
            "rateLimitEnabled": rateLimitEnabled,
            "rateLimit": rateLimit,
            "recentRequests": recentRequests,
            "version": systemInfo.version,
            "hostname": systemInfo.hostname,
            "osInfo": systemInfo.osInfo,
            "ipAddress": systemInfo.ipAddress,
            "port": config.port,
            "startTime": startTime.map { formatDate($0) } ?? "N/A",
            "chartLabels": chartLabelsString,
            "chartValues": chartValuesString
        ]
        
        return req.view.render("admin/dashboard", context)
    }
    
    func streamPage(req: Request) throws -> EventLoopFuture<View> {
        let streamActive = isStreamActive()
        let config = try httpServer.getConfig()
        
        // Get connection details if active
        var connectionId = ""
        var connectionTime = ""
        var lastAccessed = ""
        var timeoutIn = ""
        
        if streamActive, let connection = try? hlsManager.activeConnection {
            connectionId = connection.id.uuidString
            connectionTime = formatDate(connection.connectedAt)
            lastAccessed = formatDate(connection.lastAccessed)
            
            // Calculate timeout
            let timeoutDate = connection.lastAccessed.addingTimeInterval(TimeInterval(config.streamTimeout * 60))
            let interval = timeoutDate.timeIntervalSince(Date())
            if interval > 0 {
                timeoutIn = formatTimeInterval(interval)
            } else {
                timeoutIn = "Expired"
            }
        }
        
        // Generate stream URL
        let streamUrl = "\(config.hostname):\(config.port)/stream/access"
        
        // Prepare context
        let context: [String: Any] = [
            "section": "stream",
            "streamActive": streamActive,
            "config": [
                "streamTimeout": config.streamTimeout,
                "streamAuthRequired": config.auth.streamAuthRequired
            ],
            "connectionId": connectionId,
            "connectionTime": connectionTime,
            "lastAccessed": lastAccessed,
            "timeoutIn": timeoutIn,
            "streamUrl": streamUrl,
            "connectionHistory": [] // This would come from a real history storage
        ]
        
        return req.view.render("admin/stream", context)
    }
    
    func settingsPage(req: Request) throws -> EventLoopFuture<View> {
        let config = try httpServer.getConfig()
        
        // Prepare context with the full configuration
        let context: [String: Any] = [
            "section": "settings",
            "config": config
        ]
        
        return req.view.render("admin/settings", context)
    }
    
    func logsPage(req: Request) throws -> EventLoopFuture<View> {
        // Get filter parameters from request
        let logLevel = req.query[String.self, at: "logLevel"] ?? "info"
        let source = req.query[String.self, at: "source"] ?? "all"
        let search = req.query[String.self, at: "search"] ?? ""
        let limit = Int(req.query[String.self, at: "limit"] ?? "50") ?? 50
        let page = Int(req.query[String.self, at: "page"] ?? "1") ?? 1
        
        // Create filter
        var filter = LogFilter()
        filter.level = logLevel
        filter.source = source
        filter.search = search
        filter.limit = limit
        
        // TODO: Apply filtering to logs in a real implementation
        
        // For now, just return mock logs
        let mockLogs = createMockLogs()
        let filteredLogs = mockLogs // In a real implementation, apply filters
        
        // Paginate logs
        let pageSize = 10
        let startIndex = (page - 1) * pageSize
        let endIndex = min(startIndex + pageSize, filteredLogs.count)
        let pagedLogs = startIndex < filteredLogs.count ? Array(filteredLogs[startIndex..<endIndex]) : []
        
        // Calculate pagination
        let totalPages = (filteredLogs.count + pageSize - 1) / pageSize
        let paginationRange = calculatePaginationRange(currentPage: page, totalPages: totalPages)
        
        // Build pagination params string
        var paginationParams = "logLevel=\(logLevel)&source=\(source)"
        if !search.isEmpty {
            paginationParams += "&search=\(search)"
        }
        paginationParams += "&limit=\(limit)"
        
        // Format logs for display
        let formattedLogs = pagedLogs.map { log in
            return [
                "id": log.id.uuidString,
                "timestamp": formatDate(log.timestamp),
                "level": "info",
                "source": "server",
                "message": "HTTP Request: \(log.method) \(log.path) - \(log.statusCode)",
                "details": log.details
            ]
        }
        
        // Prepare context
        let context: [String: Any] = [
            "section": "logs",
            "logs": formattedLogs,
            "filter": [
                "level": filter.level,
                "source": filter.source,
                "search": filter.search,
                "limit": filter.limit
            ],
            "totalLogs": mockLogs.count,
            "filteredLogs": filteredLogs.count,
            "page": page,
            "lastPage": totalPages,
            "pagination": paginationRange,
            "paginationParams": paginationParams
        ]
        
        return req.view.render("admin/logs", context)
    }
    
    // MARK: - API Endpoints
    
    func getServerStatus(req: Request) throws -> [String: Any] {
        let serverRunning = httpServer.isRunning
        let uptime: String
        
        if let startTime = startTime, serverRunning {
            let interval = Date().timeIntervalSince(startTime)
            uptime = formatTimeInterval(interval)
        } else {
            uptime = "N/A"
        }
        
        return [
            "running": serverRunning,
            "uptime": uptime,
            "startTime": startTime.map { formatDate($0) } ?? "N/A"
        ]
    }
    
    func getStreamStatus(req: Request) throws -> [String: Any] {
        let streamActive = isStreamActive()
        var result: [String: Any] = ["active": streamActive]
        
        if streamActive, let connection = try? hlsManager.activeConnection {
            result["connectionId"] = connection.id.uuidString
            result["connectionTime"] = formatDate(connection.connectedAt)
            result["lastAccessed"] = formatDate(connection.lastAccessed)
            
            // Calculate timeout
            let config = try httpServer.getConfig()
            let timeoutDate = connection.lastAccessed.addingTimeInterval(TimeInterval(config.streamTimeout * 60))
            let interval = timeoutDate.timeIntervalSince(Date())
            if interval > 0 {
                result["timeoutIn"] = formatTimeInterval(interval)
            } else {
                result["timeoutIn"] = "Expired"
            }
        }
        
        return result
    }
    
    func getRecentRequests(req: Request) throws -> EventLoopFuture<View> {
        // Get recent requests (last 10)
        let recentRequests = Array(requestLogs.prefix(10).map { log in
            return [
                "time": formatTime(log.timestamp),
                "method": log.method,
                "path": log.path,
                "status": String(log.statusCode),
                "ip": log.ipAddress
            ]
        })
        
        return req.view.render("admin/partials/recent-requests", ["recentRequests": recentRequests])
    }
    
    func getStreamHistory(req: Request) throws -> EventLoopFuture<View> {
        // In a real implementation, this would come from a storage
        let connectionHistory: [[String: String]] = []
        
        return req.view.render("admin/partials/stream-history", ["connectionHistory": connectionHistory])
    }
    
    func generateApiKey(req: Request) throws -> [String: String] {
        let apiKey = authManager.generateApiKey()
        return ["success": "true", "apiKey": apiKey]
    }
    
    // MARK: - Action Endpoints
    
    func startServer(req: Request) throws -> Response {
        do {
            try httpServer.start()
            startTime = Date()
            
            // Update IP address
            if let serverAddress = req.application.http.server.configuration.address {
                switch serverAddress {
                case .hostname(let hostname, _):
                    systemInfo.ipAddress = hostname
                case .unixDomainSocket:
                    systemInfo.ipAddress = "Unix Socket"
                }
            }
            
            return req.redirect(to: "/admin")
        } catch {
            return req.redirect(to: "/admin?error=\(error.localizedDescription)")
        }
    }
    
    func stopServer(req: Request) throws -> Response {
        do {
            try httpServer.stop()
            startTime = nil
            return req.redirect(to: "/admin")
        } catch {
            return req.redirect(to: "/admin?error=\(error.localizedDescription)")
        }
    }
    
    func restartServer(req: Request) throws -> Response {
        do {
            try httpServer.stop()
            try httpServer.start()
            startTime = Date()
            return req.redirect(to: "/admin")
        } catch {
            return req.redirect(to: "/admin?error=\(error.localizedDescription)")
        }
    }
    
    func stopStream(req: Request) throws -> Response {
        do {
            if let connection = try? hlsManager.activeConnection {
                try hlsManager.releaseAccess(streamKey: connection.id)
            }
            return req.redirect(to: "/admin/stream")
        } catch {
            return req.redirect(to: "/admin/stream?error=\(error.localizedDescription)")
        }
    }
    
    func updateSettings(req: Request) throws -> Response {
        // In a real implementation, this would parse form data and update the config
        return req.redirect(to: "/admin/settings?success=true")
    }
    
    func resetSettings(req: Request) throws -> Response {
        // In a real implementation, this would reset to default settings
        return req.redirect(to: "/admin/settings?reset=true")
    }
    
    func clearLogs(req: Request) throws -> Response {
        requestLogs.removeAll()
        return req.redirect(to: "/admin/logs?cleared=true")
    }
    
    func exportLogs(req: Request) throws -> Response {
        // In a real implementation, this would export logs in the requested format
        return req.redirect(to: "/admin/logs?exported=true")
    }
    
    // MARK: - Helper Methods
    
    public func recordRequest(_ request: RequestLog) {
        requestLogs.append(request)
        
        // Keep only the last 1000 logs
        if requestLogs.count > 1000 {
            requestLogs.removeFirst(requestLogs.count - 1000)
        }
    }
    
    private func isStreamActive() -> Bool {
        do {
            _ = try hlsManager.activeConnection
            return true
        } catch {
            return false
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
    
    private func formatHour(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:00"
        return formatter.string(from: date)
    }
    
    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let days = Int(interval) / 86400
        let hours = (Int(interval) % 86400) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        
        if days > 0 {
            return "\(days)d \(hours)h \(minutes)m \(seconds)s"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m \(seconds)s"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
    
    private func formatAuthMethod(_ method: AuthenticationMethod) -> String {
        switch method {
        case .none:
            return "None"
        case .basic:
            return "Basic Authentication"
        case .token:
            return "Token Authentication"
        }
    }
    
    private func calculatePaginationRange(currentPage: Int, totalPages: Int) -> [Int] {
        let maxPagesToShow = 5
        
        if totalPages <= maxPagesToShow {
            return Array(1...totalPages)
        }
        
        let halfMaxPagesToShow = maxPagesToShow / 2
        
        if currentPage <= halfMaxPagesToShow {
            return Array(1...maxPagesToShow)
        } else if currentPage >= totalPages - halfMaxPagesToShow {
            return Array((totalPages - maxPagesToShow + 1)...totalPages)
        } else {
            return Array((currentPage - halfMaxPagesToShow)...(currentPage + halfMaxPagesToShow))
        }
    }
    
    private func createMockLogs() -> [RequestLog] {
        // In a real implementation, this would come from a log storage
        var mockLogs: [RequestLog] = []
        
        for i in 0..<50 {
            let timestamp = Date().addingTimeInterval(-Double(i * 60))
            let log = RequestLog(
                id: UUID(),
                timestamp: timestamp,
                method: ["GET", "POST", "PUT", "DELETE"][Int.random(in: 0...3)],
                path: ["/", "/stream", "/auth/login", "/admin"][Int.random(in: 0...3)],
                statusCode: [200, 201, 400, 401, 404, 500][Int.random(in: 0...5)],
                ipAddress: "127.0.0.1",
                duration: Double.random(in: 0.01...1.0),
                details: i % 5 == 0 ? "Detailed information about the request" : nil
            )
            mockLogs.append(log)
        }
        
        return mockLogs
    }
}

/// Middleware to protect admin routes
final class AdminAuthMiddleware: Middleware {
    private let authManager: AuthenticationManager
    
    init(authManager: AuthenticationManager) {
        self.authManager = authManager
    }
    
    func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        // Check if admin authentication is required
        guard authManager.adminAuthRequired else {
            return next.respond(to: request)
        }
        
        // Check for admin token in cookie
        guard let token = request.cookies["admin_token"]?.string else {
            return request.eventLoop.makeSucceededFuture(request.redirect(to: "/admin/login"))
        }
        
        // Validate token
        do {
            let _ = try authManager.validateToken(token)
            return next.respond(to: request)
        } catch {
            return request.eventLoop.makeSucceededFuture(request.redirect(to: "/admin/login?error=Session+expired"))
        }
    }
} 