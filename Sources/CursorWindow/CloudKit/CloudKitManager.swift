#if os(macOS)
import Foundation
import CloudKit
import os.log

/// Record types used in CloudKit database
enum CloudKitRecordType {
    static let serverInstance = "ServerInstance"
}

/// Record fields for server instances
enum ServerInstanceField {
    static let deviceIdentifier = "deviceIdentifier"
    static let deviceName = "deviceName"
    static let serverStatus = "serverStatus"
    static let networkAddresses = "networkAddresses"
    static let lastUpdated = "lastUpdated"
    static let streamConfig = "streamConfig"
}

/// Manager class for CloudKit operations
class CloudKitManager {
    // MARK: - Properties
    
    /// CloudKit container for app's data
    private let container: CKContainer
    
    /// Private database for user's data
    private let privateDatabase: CKDatabase
    
    /// Unique identifier for this device
    private let deviceIdentifier: UUID
    
    /// Device name
    private var deviceName: String
    
    /// Logger for debugging
    private let logger = Logger(subsystem: "com.cursormirror.cursorwindow", category: "CloudKit")
    
    /// Subscription IDs
    private enum SubscriptionID {
        static let serverInstanceChanges = "server-instance-changes"
    }
    
    /// Background refresh task
    private var refreshTask: Task<Void, Error>?
    
    /// Current server status
    private var isServerRunning = false
    
    /// Network addresses
    private var networkAddresses: [String] = []
    
    /// Publishers for status changes
    var serverInstancesPublisher = NotificationCenter.default.publisher(for: .serverInstancesChanged)
    
    // MARK: - Initialization
    
    /// Initialize the CloudKit manager
    init() {
        // Get the default container
        self.container = CKContainer.default()
        
        // Get the private database
        self.privateDatabase = container.privateCloudDatabase
        
        // Load or generate device identifier
        if let savedID = UserDefaults.standard.string(forKey: "device_identifier"),
           let uuid = UUID(uuidString: savedID) {
            self.deviceIdentifier = uuid
        } else {
            self.deviceIdentifier = UUID()
            UserDefaults.standard.set(deviceIdentifier.uuidString, forKey: "device_identifier")
        }
        
        // Set device name
        self.deviceName = Host.current().localizedName ?? "Unknown Mac"
        
        // Setup subscriptions for changes
        setupSubscriptions()
    }
    
    // MARK: - Public Methods
    
    /// Start CloudKit services
    func start() {
        // Check CloudKit availability
        checkCloudKitAvailability { [weak self] available in
            guard let self = self, available else {
                self?.logger.error("CloudKit is not available")
                return
            }
            
            self.logger.info("CloudKit is available, starting services")
            
            // Start periodic refresh
            self.startBackgroundRefresh()
            
            // Initial server record update
            self.updateServerRecord()
        }
    }
    
    /// Stop CloudKit services
    func stop() {
        refreshTask?.cancel()
        refreshTask = nil
    }
    
    /// Update the server status
    func updateServerStatus(isRunning: Bool, addresses: [String]) {
        self.isServerRunning = isRunning
        self.networkAddresses = addresses
        
        // Update the record in CloudKit
        updateServerRecord()
    }
    
    /// Fetch all available server instances
    func fetchServerInstances(completion: @escaping ([CKRecord]?, Error?) -> Void) {
        let query = CKQuery(recordType: CloudKitRecordType.serverInstance, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: ServerInstanceField.lastUpdated, ascending: false)]
        
        privateDatabase.perform(query, inZoneWith: nil) { records, error in
            DispatchQueue.main.async {
                if let error = error {
                    let cloudKitError = CloudKitError.from(error)
                    self.logger.error("Failed to fetch server instances: \(cloudKitError.localizedDescription)")
                    completion(nil, cloudKitError)
                    return
                }
                
                self.logger.info("Fetched \(records?.count ?? 0) server instances")
                completion(records, nil)
                
                // Post notification that server instances changed
                NotificationCenter.default.post(name: .serverInstancesChanged, object: self, userInfo: ["records": records ?? []])
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Check if CloudKit is available
    private func checkCloudKitAvailability(completion: @escaping (Bool) -> Void) {
        container.accountStatus { status, error in
            DispatchQueue.main.async {
                if let error = error {
                    let cloudKitError = CloudKitError.from(error)
                    self.logger.error("CloudKit account status error: \(cloudKitError.localizedDescription)")
                    NotificationCenter.default.post(name: .cloudKitStatusChanged, object: self, userInfo: ["error": cloudKitError])
                    completion(false)
                    return
                }
                
                switch status {
                case .available:
                    self.logger.info("CloudKit account is available")
                    NotificationCenter.default.post(name: .cloudKitStatusChanged, object: self, userInfo: ["status": "available"])
                    completion(true)
                case .noAccount:
                    let error = CloudKitError.accountNotAvailable
                    self.logger.error("No iCloud account found: \(error.localizedDescription)")
                    NotificationCenter.default.post(name: .cloudKitStatusChanged, object: self, userInfo: ["error": error])
                    completion(false)
                case .restricted:
                    let error = CloudKitError.permissionDenied
                    self.logger.error("iCloud account is restricted: \(error.localizedDescription)")
                    NotificationCenter.default.post(name: .cloudKitStatusChanged, object: self, userInfo: ["error": error])
                    completion(false)
                case .couldNotDetermine:
                    let error = CloudKitError.unknown("Could not determine iCloud account status")
                    self.logger.error("Could not determine iCloud account status: \(error.localizedDescription)")
                    NotificationCenter.default.post(name: .cloudKitStatusChanged, object: self, userInfo: ["error": error])
                    completion(false)
                case .temporarilyUnavailable:
                    let error = CloudKitError.networkUnavailable
                    self.logger.error("iCloud account is temporarily unavailable: \(error.localizedDescription)")
                    NotificationCenter.default.post(name: .cloudKitStatusChanged, object: self, userInfo: ["error": error])
                    completion(false)
                @unknown default:
                    let error = CloudKitError.unknown("Unknown iCloud account status")
                    self.logger.error("Unknown iCloud account status: \(error.localizedDescription)")
                    NotificationCenter.default.post(name: .cloudKitStatusChanged, object: self, userInfo: ["error": error])
                    completion(false)
                }
            }
        }
    }
    
    /// Start background refresh for CloudKit data
    private func startBackgroundRefresh() {
        refreshTask?.cancel()
        
        refreshTask = Task {
            do {
                while !Task.isCancelled {
                    // Update server record
                    updateServerRecord()
                    
                    // Wait for the next refresh interval (30 seconds)
                    try await Task.sleep(nanoseconds: 30_000_000_000)
                }
            } catch {
                if error is CancellationError {
                    logger.info("Background refresh cancelled")
                } else {
                    logger.error("Background refresh error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Update the server record in CloudKit
    private func updateServerRecord() {
        // Create or fetch record
        let recordID = CKRecord.ID(recordName: deviceIdentifier.uuidString)
        
        privateDatabase.fetch(withRecordID: recordID) { [weak self] (record, error) in
            guard let self = self else { return }
            
            if let error = error as? CKError, error.code == .unknownItem {
                // Record doesn't exist, create a new one
                let newRecord = CKRecord(recordType: CloudKitRecordType.serverInstance, recordID: recordID)
                self.updateAndSaveRecord(newRecord)
            } else if let record = record {
                // Record exists, update it
                self.updateAndSaveRecord(record)
            } else if let error = error {
                self.logger.error("Error fetching server record: \(error.localizedDescription)")
            }
        }
    }
    
    /// Update and save the record with current server information
    private func updateAndSaveRecord(_ record: CKRecord) {
        // Update record fields
        record[ServerInstanceField.deviceIdentifier] = deviceIdentifier.uuidString
        record[ServerInstanceField.deviceName] = deviceName
        record[ServerInstanceField.serverStatus] = isServerRunning
        record[ServerInstanceField.networkAddresses] = networkAddresses
        record[ServerInstanceField.lastUpdated] = Date()
        
        // Create stream config dictionary
        let streamConfig: [String: Any] = [
            "hostname": UserDefaults.standard.string(forKey: "server_hostname") ?? "127.0.0.1",
            "port": UserDefaults.standard.integer(forKey: "server_port") == 0 ? 8080 : UserDefaults.standard.integer(forKey: "server_port"),
            "useSSL": UserDefaults.standard.bool(forKey: "server_useSSL")
        ]
        
        record[ServerInstanceField.streamConfig] = streamConfig
        
        // Save record to CloudKit
        privateDatabase.save(record) { [weak self] (savedRecord, error) in
            guard let self = self else { return }
            
            if let error = error {
                let cloudKitError = CloudKitError.from(error)
                self.logger.error("Error saving server record: \(cloudKitError.localizedDescription)")
                
                // Notify about the error
                NotificationCenter.default.post(name: .cloudKitRecordSaveError, object: self, userInfo: ["error": cloudKitError])
            } else {
                self.logger.info("Server record saved successfully")
                
                // Notify about successful save
                NotificationCenter.default.post(name: .cloudKitRecordSaved, object: self, userInfo: ["record": savedRecord as Any])
            }
        }
    }
    
    /// Setup CloudKit subscriptions
    private func setupSubscriptions() {
        // Create subscription for server instance changes
        let predicate = NSPredicate(value: true)
        let subscription = CKQuerySubscription(recordType: CloudKitRecordType.serverInstance, 
                                               predicate: predicate,
                                               subscriptionID: SubscriptionID.serverInstanceChanges,
                                               options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion])
        
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo
        
        privateDatabase.save(subscription) { [weak self] (_, error) in
            guard let self = self else { return }
            
            if let error = error as? CKError {
                // If subscription already exists, that's fine
                if error.code != .serverRejectedRequest {
                    self.logger.error("Error creating subscription: \(error.localizedDescription)")
                }
            } else {
                self.logger.info("Subscription created successfully")
            }
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let serverInstancesChanged = Notification.Name("com.cursormirror.cursorwindow.serverInstancesChanged")
    static let cloudKitStatusChanged = Notification.Name("com.cursormirror.cursorwindow.cloudKitStatusChanged")
    static let cloudKitRecordSaveError = Notification.Name("com.cursormirror.cursorwindow.cloudKitRecordSaveError")
    static let cloudKitRecordSaved = Notification.Name("com.cursormirror.cursorwindow.cloudKitRecordSaved")
}

#endif 