import ScreenCaptureKit

#if DEBUG
public class MockSCStream: SCStream {
    public var startCaptureCount = 0
    public var stopCaptureCount = 0
    
    public convenience init() async throws {
        let content = try await SCShareableContent.current
        guard let display = content.displays.first else {
            throw ScreenCaptureError.noDisplayFound
        }
        
        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        let config = SCStreamConfiguration()
        self.init(filter: filter, configuration: config, delegate: nil)
    }
    
    public override func startCapture() async throws {
        startCaptureCount += 1
    }
    
    public override func stopCapture() async throws {
        stopCaptureCount += 1
    }
}
#endif 