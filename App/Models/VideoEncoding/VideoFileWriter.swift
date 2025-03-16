import Foundation
import AVFoundation
import CoreMedia

/// Errors that can occur during video file writing
enum VideoFileWriterError: Error {
    case fileCreationFailed
    case assetWriterNotReady
    case inputNotReady
    case appendFailed
    case finalizeFailed
}

/// A class that handles writing encoded video frames to a file
class VideoFileWriter {
    private var assetWriter: AVAssetWriter?
    private var assetWriterInput: AVAssetWriterInput?
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
    
    private var isWriting = false
    private var startTime: CMTime?
    
    /// Creates a new video file at the specified URL
    /// - Parameters:
    ///   - url: The URL where the video file will be saved
    ///   - width: The width of the video in pixels
    ///   - height: The height of the video in pixels
    ///   - frameRate: The frame rate of the video in frames per second
    /// - Throws: VideoFileWriterError if file creation fails
    func createFile(at url: URL, width: Int, height: Int, frameRate: Int) throws {
        // Remove any existing file at the URL
        try? FileManager.default.removeItem(at: url)
        
        // Create the asset writer
        do {
            assetWriter = try AVAssetWriter(outputURL: url, fileType: .mp4)
        } catch {
            throw VideoFileWriterError.fileCreationFailed
        }
        
        // Configure the video settings
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 2000000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoMaxKeyFrameIntervalKey: frameRate
            ]
        ]
        
        // Create the asset writer input
        assetWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        assetWriterInput?.expectsMediaDataInRealTime = true
        
        // Create the pixel buffer adaptor
        let sourcePixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height
        ]
        
        adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: assetWriterInput!,
            sourcePixelBufferAttributes: sourcePixelBufferAttributes
        )
        
        // Add the input to the writer
        if let assetWriterInput = assetWriterInput, assetWriter?.canAdd(assetWriterInput) == true {
            assetWriter?.add(assetWriterInput)
        } else {
            throw VideoFileWriterError.inputNotReady
        }
        
        // Start the session
        if assetWriter?.startWriting() == true {
            isWriting = true
        } else {
            throw VideoFileWriterError.assetWriterNotReady
        }
        
        startTime = nil
    }
    
    /// Appends encoded video data to the file
    /// - Parameters:
    ///   - data: The encoded video data
    ///   - presentationTime: The presentation timestamp for the frame
    /// - Throws: VideoFileWriterError if appending fails
    func appendEncodedData(_ data: Data, presentationTime: CMTime) throws {
        guard isWriting, let assetWriter = assetWriter, let assetWriterInput = assetWriterInput else {
            throw VideoFileWriterError.assetWriterNotReady
        }
        
        // Start the session if this is the first frame
        if startTime == nil {
            startTime = presentationTime
            assetWriter.startSession(atSourceTime: presentationTime)
        }
        
        // Check if the input is ready to receive data
        guard assetWriterInput.isReadyForMoreMediaData else {
            throw VideoFileWriterError.inputNotReady
        }
        
        // Create a sample buffer from the encoded data
        let sampleBuffer = try createSampleBuffer(from: data, presentationTime: presentationTime)
        
        // Append the sample buffer to the input
        if !assetWriterInput.append(sampleBuffer) {
            throw VideoFileWriterError.appendFailed
        }
    }
    
    /// Finalizes the video file
    /// - Throws: VideoFileWriterError if finalization fails
    func finishWriting() async throws {
        guard isWriting, let assetWriter = assetWriter else {
            throw VideoFileWriterError.assetWriterNotReady
        }
        
        // Mark the input as finished
        assetWriterInput?.markAsFinished()
        
        // Finish writing
        return try await withCheckedThrowingContinuation { continuation in
            assetWriter.finishWriting {
                if assetWriter.status == .completed {
                    self.isWriting = false
                    self.assetWriter = nil
                    self.assetWriterInput = nil
                    self.adaptor = nil
                    continuation.resume()
                } else {
                    continuation.resume(throwing: VideoFileWriterError.finalizeFailed)
                }
            }
        }
    }
    
    /// Cancels writing and deletes the file
    func cancelWriting() {
        assetWriterInput?.markAsFinished()
        assetWriter?.cancelWriting()
        
        if let url = assetWriter?.outputURL {
            try? FileManager.default.removeItem(at: url)
        }
        
        isWriting = false
        assetWriter = nil
        assetWriterInput = nil
        adaptor = nil
    }
    
    // MARK: - Private Methods
    
    private func createSampleBuffer(from data: Data, presentationTime: CMTime) throws -> CMSampleBuffer {
        var sampleBuffer: CMSampleBuffer?
        
        // Create a block buffer from the data
        var blockBuffer: CMBlockBuffer?
        let result = CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault,
            memoryBlock: nil,
            blockLength: data.count,
            blockAllocator: kCFAllocatorDefault,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: data.count,
            flags: 0,
            blockBufferOut: &blockBuffer
        )
        
        guard result == kCMBlockBufferNoErr, let blockBuffer = blockBuffer else {
            throw VideoFileWriterError.appendFailed
        }
        
        // Copy the data into the block buffer
        let dataPointer = UnsafeMutablePointer<UInt8>.allocate(capacity: data.count)
        data.copyBytes(to: dataPointer, count: data.count)
        
        CMBlockBufferReplaceDataBytes(
            with: dataPointer,
            blockBuffer: blockBuffer,
            offsetIntoDestination: 0,
            dataLength: data.count
        )
        
        dataPointer.deallocate()
        
        // Create a format description
        var formatDescription: CMFormatDescription?
        let videoSpecificInfo: [String: Any] = [
            "AVCProfileIndication": 100, // High profile
            "AVCLevelIndication": 41,    // Level 4.1
            "AVCProfileCompatibility": 0
        ]
        
        CMVideoFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            codecType: kCMVideoCodecType_H264,
            width: 1280, // Default, will be overridden by actual frame size
            height: 720, // Default, will be overridden by actual frame size
            extensions: videoSpecificInfo as CFDictionary,
            formatDescriptionOut: &formatDescription
        )
        
        guard let formatDescription = formatDescription else {
            throw VideoFileWriterError.appendFailed
        }
        
        // Create timing info
        var timingInfo = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: 30), // Default frame duration
            presentationTimeStamp: presentationTime,
            decodeTimeStamp: CMTime.invalid
        )
        
        // Create the sample buffer
        CMSampleBufferCreateReady(
            allocator: kCFAllocatorDefault,
            dataBuffer: blockBuffer,
            formatDescription: formatDescription,
            sampleCount: 1,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timingInfo,
            sampleSizeEntryCount: 0,
            sampleSizeArray: nil,
            sampleBufferOut: &sampleBuffer
        )
        
        guard let sampleBuffer = sampleBuffer else {
            throw VideoFileWriterError.appendFailed
        }
        
        return sampleBuffer
    }
} 