import Foundation
import Vapor

extension TouchEventController {
    /// Register the touch event route with the Vapor application
    /// - Parameter app: The Vapor application
    public func registerRoutes(with app: Application) {
        // Create group for touch API endpoints
        let touchRoutes = app.grouped("api", "touch")
        
        // Define a struct to decode touch event data
        struct TouchEventRequest: Content {
            var deviceID: String
            var event: [String: JSONValue]
            
            // Helper method to convert to [String: Any]
            func toDict() -> [String: Any] {
                var result: [String: Any] = [:]
                result["deviceID"] = deviceID
                
                // Convert event dictionary
                var eventDict: [String: Any] = [:]
                for (key, value) in event {
                    eventDict[key] = value.anyValue
                }
                result["event"] = eventDict
                
                return result
            }
        }
        
        // Define a helper enum for JSON values
        enum JSONValue: Content {
            case string(String)
            case number(Double)
            case bool(Bool)
            case null
            case array([JSONValue])
            case object([String: JSONValue])
            
            var anyValue: Any {
                switch self {
                case .string(let string): return string
                case .number(let number): return number
                case .bool(let bool): return bool
                case .null: return NSNull()
                case .array(let array): return array.map { $0.anyValue }
                case .object(let object):
                    var dict: [String: Any] = [:]
                    for (key, value) in object {
                        dict[key] = value.anyValue
                    }
                    return dict
                }
            }
            
            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                
                if let string = try? container.decode(String.self) {
                    self = .string(string)
                } else if let number = try? container.decode(Double.self) {
                    self = .number(number)
                } else if let bool = try? container.decode(Bool.self) {
                    self = .bool(bool)
                } else if container.decodeNil() {
                    self = .null
                } else if let array = try? container.decode([JSONValue].self) {
                    self = .array(array)
                } else if let object = try? container.decode([String: JSONValue].self) {
                    self = .object(object)
                } else {
                    throw DecodingError.dataCorruptedError(
                        in: container,
                        debugDescription: "Cannot decode JSON value"
                    )
                }
            }
        }
        
        // POST endpoint to receive touch events
        touchRoutes.post { req -> HTTPStatus in
            do {
                // Decode the request body
                let touchEventRequest = try req.content.decode(TouchEventRequest.self)
                
                // Convert to dictionary and process
                let eventDict = touchEventRequest.toDict()
                self.processTouchEvent(eventDict)
                
                return .ok
            } catch {
                req.logger.error("Failed to process touch event: \(error)")
                return .badRequest
            }
        }
    }
} 