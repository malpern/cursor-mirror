import Foundation

/// Authentication methods supported by the application
public enum AuthenticationMethod: String, Codable, CaseIterable {
    /// Basic authentication (username/password)
    case basic
    
    /// API key authentication
    case apiKey
    
    /// JWT authentication
    case jwt
    
    /// CloudKit/iCloud authentication
    case iCloud
    
    /// Session token authentication 
    case token
} 