#if os(macOS)
import Foundation

@available(macOS 14.0, *)
public actor TSSegmentWriter: TSSegmentWriterProtocol {
    private let segmentDirectory: String
    private var currentSegment: TSSegment?
    private var segments: [TSSegment] = []
    private var currentSegmentFile: FileHandle?
    private var segmentStartTime: Double?
    private var lastPresentationTime: Double?
    
    public init(segmentDirectory: String) async throws {
        self.segmentDirectory = segmentDirectory
        try await createSegmentDirectoryIfNeeded()
    }
    
    private func createSegmentDirectoryIfNeeded() async throws {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        
        if !fileManager.fileExists(atPath: segmentDirectory, isDirectory: &isDirectory) {
            try fileManager.createDirectory(atPath: segmentDirectory, withIntermediateDirectories: true)
        } else if !isDirectory.boolValue {
            throw HLSError.invalidSegmentDirectory
        }
    }
    
    public func startNewSegment() async throws {
        if let segment = currentSegment {
            try await finishCurrentSegment()
            segments.append(segment)
        }
        
        let segmentId = UUID().uuidString
        let segmentPath = "\(segmentDirectory)/\(segmentId).ts"
        let startTime = lastPresentationTime ?? 0
        
        if FileManager.default.createFile(atPath: segmentPath, contents: nil) {
            currentSegmentFile = try FileHandle(forWritingTo: URL(fileURLWithPath: segmentPath))
            currentSegment = TSSegment(id: segmentId, path: segmentPath, duration: 0, startTime: startTime)
            segmentStartTime = startTime
        } else {
            throw HLSError.fileOperationFailed("Failed to create segment file")
        }
    }
    
    public func writeEncodedData(_ data: Data, presentationTime: Double) async throws {
        guard let file = currentSegmentFile else {
            throw HLSError.noActiveSegment
        }
        
        try file.write(contentsOf: data)
        lastPresentationTime = presentationTime
        
        if let startTime = segmentStartTime,
           let segment = currentSegment {
            let duration = presentationTime - startTime
            currentSegment = TSSegment(id: segment.id, path: segment.path, duration: duration, startTime: startTime)
        }
    }
    
    public func getCurrentSegment() async throws -> TSSegment? {
        return currentSegment
    }
    
    public func getSegments() async throws -> [TSSegment] {
        if let current = currentSegment {
            return segments + [current]
        }
        return segments
    }
    
    public func removeSegment(_ segment: TSSegment) async throws {
        try FileManager.default.removeItem(atPath: segment.path)
        segments.removeAll { $0.id == segment.id }
        if currentSegment?.id == segment.id {
            currentSegment = nil
            currentSegmentFile = nil
            segmentStartTime = nil
        }
    }
    
    public func cleanup() async throws {
        if currentSegment != nil {
            try await finishCurrentSegment()
        }
        
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(atPath: segmentDirectory)
        
        for file in contents {
            let filePath = (segmentDirectory as NSString).appendingPathComponent(file)
            try? fileManager.removeItem(atPath: filePath)
        }
        
        segments.removeAll()
        currentSegment = nil
        currentSegmentFile = nil
        segmentStartTime = nil
        lastPresentationTime = nil
    }
    
    private func finishCurrentSegment() async throws {
        guard let currentFile = currentSegmentFile else {
            return
        }
        
        try currentFile.synchronize()
        try currentFile.close()
        currentSegmentFile = nil
    }
}
#else
#error("TSSegmentWriter is only available on macOS 14.0 or later")
#endif 