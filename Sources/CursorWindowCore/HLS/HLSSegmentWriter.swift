#if os(macOS)
import Foundation
import AVFoundation

@available(macOS 14.0, *)
actor TSSegmentWriter: HLSSegmentWriter {
    private let segmentDirectory: String
    private var outputFileHandle: FileHandle?
    private var currentSegment: HLSSegment?
    private var segmentStartTime: CMTime?
    private var segmentNumber: UInt = 0
    
    init(segmentDirectory: String) async throws {
        self.segmentDirectory = segmentDirectory
        try await createSegmentDirectoryIfNeeded()
    }
    
    private func createSegmentDirectoryIfNeeded() async throws {
        if !FileManager.default.fileExists(atPath: segmentDirectory) {
            try FileManager.default.createDirectory(
                atPath: segmentDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }
    
    func startNewSegment(startTime: CMTime) async throws -> HLSSegment {
        // Close any existing segment
        if outputFileHandle != nil {
            _ = try await finishCurrentSegment()
        }
        
        // Create new segment
        let segmentFilename = "segment\(segmentNumber).ts"
        let segmentPath = (segmentDirectory as NSString).appendingPathComponent(segmentFilename)
        
        // Create empty file
        FileManager.default.createFile(atPath: segmentPath, contents: nil)
        
        // Open file for writing
        outputFileHandle = try FileHandle(forWritingTo: URL(fileURLWithPath: segmentPath))
        
        // Create segment object
        let segment = HLSSegment(
            duration: 0.0, // Will be updated when segment is finished
            sequenceNumber: segmentNumber,
            filePath: segmentFilename,
            startTime: startTime
        )
        
        currentSegment = segment
        segmentStartTime = startTime
        segmentNumber += 1
        
        return segment
    }
    
    func writeEncodedData(_ data: Data) async throws {
        guard let outputFileHandle = outputFileHandle else {
            throw HLSError.noActiveSegment
        }
        
        try outputFileHandle.write(contentsOf: data)
    }
    
    func finishCurrentSegment() async throws -> HLSSegment {
        guard let outputFileHandle = outputFileHandle,
              let currentSegment = currentSegment,
              let segmentStartTime = segmentStartTime else {
            throw HLSError.noActiveSegment
        }
        
        // Close file
        try outputFileHandle.close()
        
        // Update segment duration based on next segment start time
        let currentTime = CMClockGetTime(CMClockGetHostTimeClock())
        let duration = CMTimeGetSeconds(CMTimeSubtract(currentTime, segmentStartTime))
        
        // Create updated segment with actual duration
        let finishedSegment = HLSSegment(
            duration: duration,
            sequenceNumber: currentSegment.sequenceNumber,
            filePath: currentSegment.filePath,
            startTime: currentSegment.startTime
        )
        
        // Reset state
        self.outputFileHandle = nil
        self.currentSegment = nil
        self.segmentStartTime = nil
        
        return finishedSegment
    }
    
    func cleanup() async throws {
        // Close current segment if exists
        if outputFileHandle != nil {
            _ = try await finishCurrentSegment()
        }
        
        // Remove segment directory and all contents
        if FileManager.default.fileExists(atPath: segmentDirectory) {
            try FileManager.default.removeItem(atPath: segmentDirectory)
        }
    }
}
#endif 