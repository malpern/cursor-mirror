import Foundation
import Vapor

extension TouchEventController {
    /// Register the touch event route with the Vapor application
    /// - Parameter app: The Vapor application
    public func registerRoutes(with app: Application) {
        // Create group for touch API endpoints
        let touchRoutes = app.grouped("api", "touch")
        
        // POST endpoint to receive touch events
        touchRoutes.post { req -> HTTPStatus in
            do {
                // Decode the request body
                let touchEventData = try req.content.decode([String: AnyCodable].self)
                
                // Convert to dictionary
                let eventDict = touchEventData.reduce(into: [String: Any]()) { result, entry in
                    result[entry.key] = entry.value.value
                }
                
                // Process the touch event
                self.processTouchEvent(eventDict)
                
                return .ok
            } catch {
                req.logger.error("Failed to process touch event: \(error)")
                return .badRequest
            }
        }
    }
} 