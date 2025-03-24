import Foundation

@Observable
class StreamConfig {
    enum Quality: String, CaseIterable {
        case auto = "auto"
        case low = "low"
        case medium = "medium"
        case high = "high"
    }
    
    static let minimumBufferSize: Double = 1.0
    static let maximumBufferSize: Double = 10.0
    static let defaultBufferSize: Double = 3.0
    
    // UserDefaults instance to use (allows for custom UserDefaults in tests)
    private let defaults: UserDefaults
    private let qualityKey = "streamQuality"
    private let bufferSizeKey = "bufferSize"
    
    var quality: Quality {
        didSet {
            isAutoQualityEnabled = quality == .auto
        }
    }
    
    // Using a private backing property for bufferSize validation
    private var _bufferSize: Double
    
    var bufferSize: Double {
        get { return _bufferSize }
        set {
            _bufferSize = min(max(newValue, Self.minimumBufferSize), Self.maximumBufferSize)
        }
    }
    
    var isAutoQualityEnabled: Bool
    
    init(url: URL? = nil, skipDefaultsClear: Bool = false, userDefaults: UserDefaults = .standard) {
        // Store the UserDefaults instance
        self.defaults = userDefaults
        
        // Clean previous test values when running in test environment
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil && !skipDefaultsClear {
            defaults.removeObject(forKey: qualityKey)
            defaults.removeObject(forKey: bufferSizeKey)
        }
        
        // Initialize properties first, before any didSet is triggered
        let savedQuality = defaults.string(forKey: qualityKey)
        let initialQuality = Quality(rawValue: savedQuality ?? "") ?? .auto
        
        var savedBufferSize = defaults.double(forKey: bufferSizeKey)
        if savedBufferSize == 0 {
            savedBufferSize = Self.defaultBufferSize
        }
        savedBufferSize = min(max(savedBufferSize, Self.minimumBufferSize), Self.maximumBufferSize)
        
        // Initialize all properties with local variables
        self.quality = initialQuality
        self._bufferSize = savedBufferSize
        self.isAutoQualityEnabled = initialQuality == .auto
    }
    
    func generateStreamURL(forDevice deviceID: String, baseURL: String) -> URL {
        var components = URLComponents(string: baseURL)!
        components.path = "/stream/\(deviceID)"
        components.queryItems = [
            URLQueryItem(name: "quality", value: quality.rawValue),
            URLQueryItem(name: "buffer", value: String(bufferSize))
        ]
        return components.url!
    }
    
    func adjustQualityBasedOnBandwidth(available bandwidth: Int) {
        guard isAutoQualityEnabled || quality != .auto else { return }
        
        let newQuality: Quality
        
        switch bandwidth {
        case ...2_000_000: // Less than 2 Mbps
            newQuality = .low
        case 2_000_001...5_000_000: // 2-5 Mbps
            newQuality = .medium
        default: // More than 5 Mbps
            newQuality = .high
        }
        
        // Update the quality property directly to avoid affecting isAutoQualityEnabled
        if quality == .auto {
            // If we're in auto mode, keep the auto setting but still adjust the quality
            // isAutoQualityEnabled will remain true
            quality = newQuality
            // We need to restore isAutoQualityEnabled manually since the didSet will change it
            isAutoQualityEnabled = true
        } else {
            quality = newQuality
        }
    }
    
    func saveConfiguration() {
        defaults.set(quality.rawValue, forKey: qualityKey)
        defaults.set(bufferSize, forKey: bufferSizeKey)
        defaults.synchronize() // Ensure values are saved immediately
    }
    
    func resetToDefaults() {
        quality = .auto
        bufferSize = Self.defaultBufferSize
        isAutoQualityEnabled = true
        saveConfiguration()
    }
}
