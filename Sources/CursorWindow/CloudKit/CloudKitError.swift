#if os(macOS)
import Foundation
import CloudKit

/// Errors that can occur during CloudKit operations
enum CloudKitError: Error, LocalizedError {
    case accountNotAvailable
    case containerNotAvailable
    case networkUnavailable
    case permissionDenied
    case recordNotFound
    case recordSaveFailed(String)
    case subscriptionFailed(String)
    case queryFailed(String)
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .accountNotAvailable:
            return "iCloud account is not available. Please sign in to iCloud in System Settings."
        case .containerNotAvailable:
            return "CloudKit container is not available."
        case .networkUnavailable:
            return "Network connection is not available."
        case .permissionDenied:
            return "Permission to access CloudKit was denied."
        case .recordNotFound:
            return "CloudKit record not found."
        case .recordSaveFailed(let message):
            return "Failed to save CloudKit record: \(message)"
        case .subscriptionFailed(let message):
            return "Failed to set up CloudKit subscription: \(message)"
        case .queryFailed(let message):
            return "CloudKit query failed: \(message)"
        case .unknown(let message):
            return "Unknown CloudKit error: \(message)"
        }
    }
    
    /// Convert CKError to CloudKitError
    static func from(_ error: Error) -> CloudKitError {
        guard let ckError = error as? CKError else {
            return .unknown(error.localizedDescription)
        }
        
        switch ckError.code {
        case .networkUnavailable:
            return .networkUnavailable
        case .notAuthenticated:
            return .accountNotAvailable
        case .permissionFailure:
            return .permissionDenied
        case .unknownItem:
            return .recordNotFound
        case .serverRejectedRequest:
            return .recordSaveFailed("Server rejected the request")
        case .serviceUnavailable:
            return .networkUnavailable
        case .requestRateLimited:
            return .queryFailed("Request rate limited")
        case .zoneBusy:
            return .queryFailed("CloudKit zone is busy")
        case .limitExceeded:
            return .queryFailed("CloudKit limit exceeded")
        default:
            return .unknown(ckError.localizedDescription)
        }
    }
}
#endif 