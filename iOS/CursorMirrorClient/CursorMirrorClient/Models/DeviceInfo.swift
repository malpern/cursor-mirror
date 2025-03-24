import Foundation
import CloudKit

struct DeviceInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let type: String
    let recordID: CKRecord.ID
    var isOnline: Bool
    var lastSeen: Date
    
    init(
        id: String = UUID().uuidString,
        name: String,
        type: String = "Mac",
        recordID: CKRecord.ID,
        isOnline: Bool = false,
        lastSeen: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.recordID = recordID
        self.isOnline = isOnline
        self.lastSeen = lastSeen
    }
    
    // MARK: - Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // MARK: - Equatable
    static func == (lhs: DeviceInfo, rhs: DeviceInfo) -> Bool {
        lhs.id == rhs.id
    }
}

extension DeviceInfo {
    init?(from record: CKRecord) {
        guard
            let name = record["name"] as? String,
            let type = record["type"] as? String,
            let isOnline = record["isOnline"] as? Int,
            let lastSeen = record["lastSeen"] as? Date
        else {
            return nil
        }
        
        self.init(
            id: record.recordID.recordName,
            name: name,
            type: type,
            recordID: record.recordID,
            isOnline: isOnline == 1,
            lastSeen: lastSeen
        )
    }
    
    var displayName: String {
        "\(name) (\(type))"
    }
    
    var statusIndicator: String {
        isOnline ? "🟢" : "⚫️"
    }
    
    var lastSeenText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: lastSeen, relativeTo: Date())
    }
} 