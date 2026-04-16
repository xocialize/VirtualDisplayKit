//
//  FrameOutputStream.swift
//  VirtualDisplayKit
//
//  Provides frame data for streaming to external services.
//

import AVFoundation
import Cocoa
import Combine
import CoreMedia
import CoreVideo
import VideoToolbox

// Wrapper to cross Sendable boundaries for Core Media types that are not
// themselves Sendable but are safe to hand off to MainActor work.
private struct UncheckedSendableBox<Value>: @unchecked Sendable {
    let value: Value
    init(_ value: Value) { self.value = value }
}

/// Delegate for receiving streaming frames
@MainActor
public protocol FrameOutputStreamDelegate: AnyObject {
    /// Called when a new compressed frame is available
    func frameOutputStream(_ stream: FrameOutputStream, didOutputEncodedFrame data: Data, presentationTime: CMTime, isKeyFrame: Bool)
    
    /// Called when a new raw frame is available (for custom processing)
    func frameOutputStream(_ stream: FrameOutputStream, didOutputPixelBuffer buffer: CVPixelBuffer, presentationTime: CMTime)
    
    /// Called when stream parameters change (SPS/PPS for H.264)
    func frameOutputStream(_ stream: FrameOutputStream, didOutputParameterSets parameterSets: [[Data]])
    
    /// Called when an error occurs
    func frameOutputStream(_ stream: FrameOutputStream, didEncounterError error: Error)
}

public extension FrameOutputStreamDelegate {
    func frameOutputStream(_ stream: FrameOutputStream, didOutputEncodedFrame data: Data, presentationTime: CMTime, isKeyFrame: Bool) {}
    func frameOutputStream(_ stream: FrameOutputStream, didOutputPixelBuffer buffer: CVPixelBuffer, presentationTime: CMTime) {}
    func frameOutputStream(_ stream: FrameOutputStream, didOutputParameterSets parameterSets: [[Data]]) {}
    func frameOutputStream(_ stream: FrameOutputStream, didEncounterError error: Error) {}
}

/// Output format for streaming
public enum StreamOutputFormat: Sendable {
    /// Raw pixel buffers (for custom encoding)
    case rawPixelBuffer
    
    /// H.264 Annex B format (for RTMP streaming)
    case h264AnnexB
    
    /// H.264 AVCC format (for HLS/MP4)
    case h264AVCC
    
    /// HEVC Annex B format
    case hevcAnnexB
}

/// Configuration for frame output streaming
public struct StreamOutputConfiguration: Sendable {
    /// Output format
    public var format: StreamOutputFormat
    
    /// Target bitrate in bits per second
    public var bitrate: Int
    
    /// Target frame rate
    public var frameRate: Int
    
    /// Keyframe interval in seconds
    public var keyframeInterval: TimeInterval
    
    /// Whether to use low-latency encoding
    public var lowLatency: Bool
    
    /// Output resolution (nil = match source)
    public var outputSize: CGSize?
    
    public init(
        format: StreamOutputFormat = .h264AnnexB,
        bitrate: Int = 4_000_000,
        frameRate: Int = 30,
        keyframeInterval: TimeInterval = 2.0,
        lowLatency: Bool = true,
        outputSize: CGSize? = nil
    ) {
        self.format = format
        self.bitrate = bitrate
        self.frameRate = frameRate
        self.keyframeInterval = keyframeInterval
        self.lowLatency = lowLatency
        self.outputSize = outputSize
    }
    
    // MARK: - Presets
    
    /// Optimized for Twitch/YouTube streaming
    public static var rtmpStreaming: StreamOutputConfiguration {
        StreamOutputConfiguration(
            format: .h264AnnexB,
            bitrate: 4_500_000,
            frameRate: 30,
            keyframeInterval: 2.0,
            lowLatency: true
        )
    }
    
    /// High quality streaming
    public static var highQuality: StreamOutputConfiguration {
        StreamOutputConfiguration(
            format: .h264AnnexB,
            bitrate: 8_000_000,
            frameRate: 60,
            keyframeInterval: 2.0,
            lowLatency: false
        )
    }
    
    /// Low latency for real-time applications
    public static var realtime: StreamOutputConfiguration {
        StreamOutputConfiguration(
            format: .h264AnnexB,
            bitrate: 3_000_000,
            frameRate: 30,
            keyframeInterval: 1.0,
            lowLatency: true
        )
    }
}

/// Provides encoded frame data for streaming to external services
@MainActor
public final class FrameOutputStream: ObservableObject {
    
    // MARK: - Published State
    
    /// Whether the stream is currently active
    @Published public private(set) var isStreaming = false
    
    /// Current output frame rate (actual)
    @Published public private(set) var currentFrameRate: Double = 0
    
    /// Total frames output
    @Published public private(set) var frameCount: Int64 = 0
    
    /// Total bytes output
    @Published public private(set) var bytesOutput: Int64 = 0
    
    // MARK: - Properties
    
    public weak var delegate: FrameOutputStreamDelegate?
    public let configuration: StreamOutputConfiguration
    
    /// Closure called for each encoded frame (alternative to delegate)
    public var onEncodedFrame: ((_ data: Data, _ presentationTime: CMTime, _ isKeyFrame: Bool) -> Void)?
    
    /// Closure called for each raw frame
    public var onRawFrame: ((_ buffer: CVPixelBuffer, _ presentationTime: CMTime) -> Void)?
    
    // MARK: - Private Properties
    
    // Using nonisolated(unsafe) to allow cleanup in deinit
    private nonisolated(unsafe) var compressionSession: VTCompressionSession?
    private var startTime: CFAbsoluteTime?
    private var lastFrameTime: CMTime = .zero
    private var frameRateCalculator = FrameRateCalculator()
    
    private var displaySize: CGSize = .zero
    private var scaleFactor: CGFloat = 1.0
    
    private var hasOutputParameterSets = false
    
    // MARK: - Initialization
    
    public init(configuration: StreamOutputConfiguration = .rtmpStreaming) {
        self.configuration = configuration
    }
    
    deinit {
        if let session = compressionSession {
            VTCompressionSessionInvalidate(session)
        }
    }
    
    // MARK: - Public Methods
    
    /// Configures the stream for a specific display size
    public func configure(displaySize size: CGSize, scaleFactor: CGFloat) {
        self.displaySize = size
        self.scaleFactor = scaleFactor
    }
    
    /// Starts the output stream
    public func start() throws {
        guard !isStreaming else { return }
        guard displaySize != .zero else {
            throw DisplayRecorderError.notConfigured
        }
        
        // Only create compression session for encoded formats
        if configuration.format != .rawPixelBuffer {
            try createCompressionSession()
        }
        
        startTime = CFAbsoluteTimeGetCurrent()
        lastFrameTime = .zero
        frameCount = 0
        bytesOutput = 0
        hasOutputParameterSets = false
        isStreaming = true
    }
    
    /// Stops the output stream
    public func stop() {
        guard isStreaming else { return }
        
        if let session = compressionSession {
            VTCompressionSessionCompleteFrames(session, untilPresentationTimeStamp: .invalid)
            VTCompressionSessionInvalidate(session)
            compressionSession = nil
        }
        
        isStreaming = false
    }
    
    /// Processes a frame from an IOSurface
    public func processFrame(from surface: IOSurface) {
        guard isStreaming else { return }
        
        // Create pixel buffer from IOSurface
        guard let buffer = createPixelBuffer(from: surface) else {
            return
        }
        
        processFrame(pixelBuffer: buffer)
    }
    
    /// Processes a frame from a CVPixelBuffer
    public func processFrame(pixelBuffer: CVPixelBuffer) {
        guard isStreaming, let startTime = startTime else { return }
        
        // Calculate presentation time
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        let presentationTime = CMTime(seconds: elapsed, preferredTimescale: 600)
        
        // Update frame rate
        frameRateCalculator.recordFrame()
        currentFrameRate = frameRateCalculator.frameRate
        
        switch configuration.format {
        case .rawPixelBuffer:
            // Output raw pixel buffer
            onRawFrame?(pixelBuffer, presentationTime)
            delegate?.frameOutputStream(self, didOutputPixelBuffer: pixelBuffer, presentationTime: presentationTime)
            frameCount += 1
            
        case .h264AnnexB, .h264AVCC, .hevcAnnexB:
            // Encode the frame
            encodeFrame(pixelBuffer: pixelBuffer, presentationTime: presentationTime)
        }
        
        lastFrameTime = presentationTime
    }
    
    // MARK: - Private Methods
    
    private func createPixelBuffer(from surface: IOSurface) -> CVPixelBuffer? {
        let width = IOSurfaceGetWidth(surface)
        let height = IOSurfaceGetHeight(surface)
        
        var pixelBuffer: CVPixelBuffer?
        let attrs: [CFString: Any] = [
            kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary
        ]
        
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }
        
        // Lock and copy data
        CVPixelBufferLockBaseAddress(buffer, [])
        IOSurfaceLock(surface, .readOnly, nil)
        
        let srcData = IOSurfaceGetBaseAddress(surface)
        let dstData = CVPixelBufferGetBaseAddress(buffer)
        let srcBytesPerRow = IOSurfaceGetBytesPerRow(surface)
        let dstBytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        
        if let dst = dstData {
            for y in 0..<height {
                let srcRow = srcData.advanced(by: y * srcBytesPerRow)
                let dstRow = dst.advanced(by: y * dstBytesPerRow)
                memcpy(dstRow, srcRow, min(srcBytesPerRow, dstBytesPerRow))
            }
        }
        
        IOSurfaceUnlock(surface, .readOnly, nil)
        CVPixelBufferUnlockBaseAddress(buffer, [])
        
        return buffer
    }
    
    private func createCompressionSession() throws {
        let outputSize = configuration.outputSize ?? CGSize(
            width: displaySize.width * scaleFactor,
            height: displaySize.height * scaleFactor
        )
        
        let codecType: CMVideoCodecType
        switch configuration.format {
        case .hevcAnnexB:
            codecType = kCMVideoCodecType_HEVC
        default:
            codecType = kCMVideoCodecType_H264
        }
        
        var session: VTCompressionSession?
        let status = VTCompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            width: Int32(outputSize.width),
            height: Int32(outputSize.height),
            codecType: codecType,
            encoderSpecification: nil,
            imageBufferAttributes: nil,
            compressedDataAllocator: nil,
            outputCallback: nil,
            refcon: nil,
            compressionSessionOut: &session
        )
        
        guard status == noErr, let compressionSession = session else {
            throw DisplayRecorderError.encodingFailed
        }
        
        // Configure encoder
        VTSessionSetProperty(compressionSession, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)
        VTSessionSetProperty(compressionSession, key: kVTCompressionPropertyKey_ProfileLevel, value: kVTProfileLevel_H264_High_AutoLevel)
        VTSessionSetProperty(compressionSession, key: kVTCompressionPropertyKey_AverageBitRate, value: configuration.bitrate as CFNumber)
        VTSessionSetProperty(compressionSession, key: kVTCompressionPropertyKey_ExpectedFrameRate, value: configuration.frameRate as CFNumber)
        VTSessionSetProperty(compressionSession, key: kVTCompressionPropertyKey_MaxKeyFrameInterval, value: Int(Double(configuration.frameRate) * configuration.keyframeInterval) as CFNumber)
        VTSessionSetProperty(compressionSession, key: kVTCompressionPropertyKey_AllowFrameReordering, value: kCFBooleanFalse)
        
        if configuration.lowLatency {
            VTSessionSetProperty(compressionSession, key: kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration, value: configuration.keyframeInterval as CFNumber)
        }
        
        VTCompressionSessionPrepareToEncodeFrames(compressionSession)
        
        self.compressionSession = compressionSession
    }
    
    private func encodeFrame(pixelBuffer: CVPixelBuffer, presentationTime: CMTime) {
        guard let session = compressionSession else { return }
        
        var flags: VTEncodeInfoFlags = []
        
        let status = VTCompressionSessionEncodeFrame(
            session,
            imageBuffer: pixelBuffer,
            presentationTimeStamp: presentationTime,
            duration: CMTime(value: 1, timescale: Int32(configuration.frameRate)),
            frameProperties: nil,
            infoFlagsOut: &flags
        ) { [weak self] status, infoFlags, sampleBuffer in
            guard status == noErr, let buffer = sampleBuffer else { return }
            let sendableBuffer = UncheckedSendableBox(buffer)
            Task { @MainActor [weak self] in
                self?.handleEncodedFrame(sendableBuffer.value)
            }
        }
        
        if status != noErr {
            delegate?.frameOutputStream(self, didEncounterError: DisplayRecorderError.encodingFailed)
        }
    }
    
    private func handleEncodedFrame(_ sampleBuffer: CMSampleBuffer) {
        guard let dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }
        
        // Check if keyframe
        let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[CFString: Any]]
        let isKeyFrame = attachments?.first?[kCMSampleAttachmentKey_NotSync] as? Bool != true
        
        // Extract parameter sets for first keyframe
        if isKeyFrame && !hasOutputParameterSets {
            extractAndOutputParameterSets(from: sampleBuffer)
            hasOutputParameterSets = true
        }
        
        // Get encoded data
        var length = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        CMBlockBufferGetDataPointer(dataBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &dataPointer)
        
        guard let pointer = dataPointer, length > 0 else { return }
        
        let data: Data
        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        
        switch configuration.format {
        case .h264AnnexB, .hevcAnnexB:
            // Convert from AVCC to Annex B format
            data = convertToAnnexB(Data(bytes: pointer, count: length))
        case .h264AVCC:
            data = Data(bytes: pointer, count: length)
        case .rawPixelBuffer:
            return
        }
        
        frameCount += 1
        bytesOutput += Int64(data.count)
        
        onEncodedFrame?(data, presentationTime, isKeyFrame)
        delegate?.frameOutputStream(self, didOutputEncodedFrame: data, presentationTime: presentationTime, isKeyFrame: isKeyFrame)
    }
    
    private func extractAndOutputParameterSets(from sampleBuffer: CMSampleBuffer) {
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else { return }
        
        var parameterSets: [[Data]] = []
        
        // Get number of parameter sets
        var parameterSetCount = 0
        CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
            formatDescription,
            parameterSetIndex: 0,
            parameterSetPointerOut: nil,
            parameterSetSizeOut: nil,
            parameterSetCountOut: &parameterSetCount,
            nalUnitHeaderLengthOut: nil
        )
        
        // Extract each parameter set
        for i in 0..<parameterSetCount {
            var parameterSetPointer: UnsafePointer<UInt8>?
            var parameterSetSize = 0
            
            let status = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
                formatDescription,
                parameterSetIndex: i,
                parameterSetPointerOut: &parameterSetPointer,
                parameterSetSizeOut: &parameterSetSize,
                parameterSetCountOut: nil,
                nalUnitHeaderLengthOut: nil
            )
            
            if status == noErr, let pointer = parameterSetPointer, parameterSetSize > 0 {
                let data = Data(bytes: pointer, count: parameterSetSize)
                parameterSets.append([data])
            }
        }
        
        if !parameterSets.isEmpty {
            delegate?.frameOutputStream(self, didOutputParameterSets: parameterSets)
        }
    }
    
    private func convertToAnnexB(_ avccData: Data) -> Data {
        var annexBData = Data()
        let startCode: [UInt8] = [0x00, 0x00, 0x00, 0x01]
        
        var offset = 0
        while offset < avccData.count - 4 {
            // Read NAL unit length (4 bytes, big endian)
            let lengthBytes = avccData.subdata(in: offset..<(offset + 4))
            let length = Int(lengthBytes.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian })
            offset += 4
            
            guard offset + length <= avccData.count else { break }
            
            // Append start code and NAL unit
            annexBData.append(contentsOf: startCode)
            annexBData.append(avccData.subdata(in: offset..<(offset + length)))
            offset += length
        }
        
        return annexBData
    }
}

// MARK: - Frame Rate Calculator

private class FrameRateCalculator {
    private var frameTimes: [CFAbsoluteTime] = []
    private let windowSize: Int = 30
    
    var frameRate: Double {
        guard frameTimes.count >= 2 else { return 0 }
        let duration = frameTimes.last! - frameTimes.first!
        guard duration > 0 else { return 0 }
        return Double(frameTimes.count - 1) / duration
    }
    
    func recordFrame() {
        let now = CFAbsoluteTimeGetCurrent()
        frameTimes.append(now)
        
        // Keep only recent frames
        if frameTimes.count > windowSize {
            frameTimes.removeFirst()
        }
    }
}
