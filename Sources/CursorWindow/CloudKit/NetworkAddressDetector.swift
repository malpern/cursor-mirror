#if os(macOS)
import Foundation
import Network
import os.log

/// Class to detect network addresses of the current device
class NetworkAddressDetector {
    // MARK: - Properties
    
    /// Shared instance
    static let shared = NetworkAddressDetector()
    
    /// Logger for debugging
    private let logger = Logger(subsystem: "com.cursormirror.cursorwindow", category: "NetworkDetection")
    
    /// Queue for network path monitoring
    private let monitorQueue = DispatchQueue(label: "com.cursormirror.cursorwindow.networkmonitor", qos: .utility)
    
    /// Network path monitor
    private var pathMonitor: NWPathMonitor?
    
    /// Current list of network addresses
    private(set) var currentAddresses: [String] = []
    
    /// Network change callback
    private var networkChangeCallback: (([String]) -> Void)?
    
    // MARK: - Initialization
    
    private init() {
        // Private initializer to enforce singleton
    }
    
    // MARK: - Public Methods
    
    /// Start monitoring for network changes
    func startMonitoring(callback: @escaping ([String]) -> Void) {
        stopMonitoring()
        
        networkChangeCallback = callback
        
        // Create and start path monitor
        pathMonitor = NWPathMonitor()
        pathMonitor?.pathUpdateHandler = { [weak self] path in
            self?.handleNetworkPathUpdate(path)
        }
        
        pathMonitor?.start(queue: monitorQueue)
        
        // Perform initial detection
        detectNetworkAddresses()
    }
    
    /// Stop monitoring for network changes
    func stopMonitoring() {
        pathMonitor?.cancel()
        pathMonitor = nil
    }
    
    /// Manually trigger network address detection
    func detectNetworkAddresses() {
        var addresses = [String]()
        
        // Get list of network interfaces
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            logger.error("Failed to get network interfaces")
            return
        }
        
        // Iterate through interfaces
        var ptr = firstAddr
        while ptr != nil {
            defer { ptr = ptr.pointee.ifa_next }
            
            let interface = ptr.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family
            
            // Check for IPv4 or IPv6 interface
            if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
                // Get interface name
                let name = String(cString: interface.ifa_name)
                
                // Skip loopback interfaces
                if name == "lo0" || name == "lo1" || name == "lo2" {
                    continue
                }
                
                // Convert socket address to string
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                           &hostname, socklen_t(hostname.count),
                           nil, 0,
                           NI_NUMERICHOST)
                
                let address = String(cString: hostname)
                
                // Add valid addresses (skip link-local IPv6 addresses for simplicity)
                if !address.isEmpty && !address.hasPrefix("fe80") {
                    addresses.append(address)
                    logger.info("Found network address: \(address) on interface \(name)")
                }
            }
        }
        
        // Free memory
        freeifaddrs(ifaddr)
        
        // Try to get public IP address
        Task {
            if let publicIP = await detectPublicIPAddress() {
                addresses.append(publicIP)
                logger.info("Found public IP address: \(publicIP)")
                
                // Update and notify
                DispatchQueue.main.async {
                    self.currentAddresses = addresses
                    self.networkChangeCallback?(addresses)
                }
            } else {
                // Update and notify with just local addresses
                DispatchQueue.main.async {
                    self.currentAddresses = addresses
                    self.networkChangeCallback?(addresses)
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Handle network path updates
    private func handleNetworkPathUpdate(_ path: NWPath) {
        logger.info("Network path changed: \(path.status)")
        
        // Detect addresses when the network status changes
        DispatchQueue.main.async {
            self.detectNetworkAddresses()
        }
    }
    
    /// Detect public IP address
    private func detectPublicIPAddress() async -> String? {
        // Try multiple services in case one is down
        let publicIPServices = [
            "https://api.ipify.org",
            "https://ifconfig.me/ip",
            "https://api.my-ip.io/ip"
        ]
        
        for service in publicIPServices {
            do {
                guard let url = URL(string: service) else { continue }
                
                let (data, response) = try await URLSession.shared.data(from: url)
                
                guard let httpResponse = response as? HTTPURLResponse, 
                      httpResponse.statusCode == 200,
                      let ipString = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !ipString.isEmpty else {
                    continue
                }
                
                logger.info("Detected public IP: \(ipString) using service \(service)")
                return ipString
            } catch {
                logger.error("Failed to detect public IP using \(service): \(error.localizedDescription)")
                continue
            }
        }
        
        logger.warning("Could not detect public IP address")
        return nil
    }
}
#endif 