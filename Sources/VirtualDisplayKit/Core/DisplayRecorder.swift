//
//  DisplayRecorder.swift
//  VirtualDisplayKit
//
//  Records virtual display content to video files.
//

import AVFoundation
import Cocoa
import Combine
import CoreMedia
import CoreVideo
import VideoToolbox

/// Delegate for receiving recording events
@MainActor
public protocol DisplayRecorderDelegate: AnyObject {
    /// Called when recording starts
    func recorderDidStartRecording(_ recorder: DisplayRecorder)
    
    /// Called when recording stops
    func recorderDidStopRecording(_ recorder: DisplayRecorder, outputURL: URL)
    
    /// Called when an error occurs
    func recorder(_ recorder: DisplayRecorder, didEncounterError error: DisplayRecorderError)
    
    /// Called periodically with recording duration
    func recorder(_ recorder: DisplayRecorder, didUpdateDuration duration: TimeInterval)
}

public extension DisplayRecorderDelegate {
    func recorderDidStartRecording(_ recorder: DisplayRecorder) {}
    func recorderDidStopRecording(_ recorder: DisplayRecorder, outputURL: URL) {}
    func recorder(_ recorder: DisplayRecorder, didEncounterError error: DisplayRecorderError) {}
    func recorder(_ recorder: DisplayRecorder, didUpdateDuration duration: TimeInterval) {}
}

/// Errors that can occur during recording
public enum DisplayRecorderError: Error, LocalizedError {
    case notConfigured
    case alreadyRecording
    case notRecording
    case assetWriterFailed(Error?)
    case invalidOutputURL
    case encodingFailed
    
    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Recorder is not configured"
        case .alreadyRecording:
            return "Recording is already in progress"
        case .notRecording:
            return "No recording in progress"
        case .assetWriterFailed(let error):
            return "Asset writer failed: \(error?.localizedDescription ?? "unknown error")"
        case .invalidOutputURL:
            return "Invalid output URL"
        case .encodingFailed:
            return "Video encoding failed"
        }
    }
}

/// Configuration for display recording
public struct RecordingConfiguration: Sendable {
    /// Output video codec
    public var codec: AVVideoCodecType
    
    /// Output frame rate
    public var frameRate: Int
    
    /// Video bitrate in bits per second
    public var bitrate: Int
    
    /// Whether to include system audio
    public var includeAudio: Bool
    
    /// Audio sample rate
    public var audioSampleRate: Double
    
    /// Output video dimensions (nil = match display)
    public var outputSize: CGSize?
    
    /// File type for output
    public var fileType: AVFileType
    
    public init(
        codec: AVVideoCodecType = .h264,
        frameRate: Int = 30,
        bitrate: Int = 10_000_000,
        includeAudio: Bool = false,
        audioSampleRate: Double = 44100,
        outputSize: CGSize? = nil,
        fileType: AVFileType = .mp4
    ) {
        self.codec = codec
        self.frameRate = frameRate
        self.bitrate = bitrate
        self.includeAudio = includeAudio
        self.audioSampleRate = audioSampleRate
        self.outputSize = outputSize
        self.fileType = fileType
    }
    
    // MARK: - Presets
    
    /// High quality recording (1080p, 10Mbps)
    public static var highQuality: RecordingConfiguration {
        RecordingConfiguration(
            codec: .h264,
            frameRate: 60,
            bitrate: 10_000_000
        )
    }
    
    /// Standard quality recording (720p equivalent, 5Mbps)
    public static var standard: RecordingConfiguration {
        RecordingConfiguration(
            codec: .h264,
            frameRate: 30,
            bitrate: 5_000_000
        )
    }
    
    /// Optimized for streaming (lower latency)
    public static var streaming: RecordingConfiguration {
        RecordingConfiguration(
            codec: .h264,
            frameRate: 30,
            bitrate: 3_000_000
        )
    }
    
    /// HEVC/H.265 high efficiency
    public static var hevcHighEfficiency: RecordingConfiguration {
        RecordingConfiguration(
            codec: .hevc,
            frameRate: 30,
            bitrate: 4_000_000
        )
    }
}

/// Records virtual display content to video files
@MainActor
public final class DisplayRecorder: ObservableObject {
    
    // MARK: - Published State
    
    /// Whether recording is currently active
    @Published public private(set) var isRecording = false
    
    /// Current recording duration in seconds
    @Published public private(set) var duration: TimeInterval = 0
    
    /// Output URL of the current/last recording
    @Published public private(set) var outputURL: URL?
    
    // MARK: - Properties
    
    public weak var delegate: DisplayRecorderDelegate?
    public let configuration: RecordingConfiguration
    
    // MARK: - Private Properties
    
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var audioInput: AVAssetWriterInput?
    
    private var startTime: CMTime?
    private var lastFrameTime: CMTime = .zero
    private var frameCount: Int64 = 0
    
    private var durationTimer: Timer?
    private var recordingStartDate: Date?
    
    private var displaySize: CGSize = .zero
    private var scaleFactor: CGFloat = 1.0
    
    // MARK: - Initialization
    
    public init(configuration: RecordingConfiguration = .standard) {
        self.configuration = configuration
    }
    
    // MARK: - Public Methods
    
    /// Configures the recorder for a specific display size
    /// - Parameters:
    ///   - size: Display resolution
    ///   - scaleFactor: Display scale factor
    public func configure(displaySize size: CGSize, scaleFactor: CGFloat) {
        self.displaySize = size
        self.scaleFactor = scaleFactor
    }
    
    /// Starts recording to the specified URL
    /// - Parameter url: Output file URL
    public func startRecording(to url: URL) throws {
        guard !isRecording else {
            throw DisplayRecorderError.alreadyRecording
        }
        
        guard displaySize != .zero else {
            throw DisplayRecorderError.notConfigured
        }
        
        // Remove existing file if present
        try? FileManager.default.removeItem(at: url)
        
        // Create asset writer
        let writer = try AVAssetWriter(url: url, fileType: configuration.fileType)
        
        // Calculate output size
        let outputSize = configuration.outputSize ?? CGSize(
            width: displaySize.width * scaleFactor,
            height: displaySize.height * scaleFactor
        )
        
        // Video settings
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: configuration.codec,
            AVVideoWidthKey: Int(outputSize.width),
            AVVideoHeightKey: Int(outputSize.height),
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: configuration.bitrate,
                AVVideoExpectedSourceFrameRateKey: configuration.frameRate,
                AVVideoMaxKeyFrameIntervalKey: configuration.frameRate * 2,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            ] as [String: Any]
        ]
        
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = true
        
        // Pixel buffer adaptor for efficient frame writing
        let sourcePixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(outputSize.width),
            kCVPixelBufferHeightKey as String: Int(outputSize.height),
            kCVPixelBufferMetalCompatibilityKey as String: true,
        ]
        
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: sourcePixelBufferAttributes
        )
        
        if writer.canAdd(videoInput) {
            writer.add(videoInput)
        }
        
        // Audio input (if enabled)
        if configuration.includeAudio {
            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: configuration.audioSampleRate,
                AVNumberOfChannelsKey: 2,
                AVEncoderBitRateKey: 128000,
            ]
            
            let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            audioInput.expectsMediaDataInRealTime = true
            
            if writer.canAdd(audioInput) {
                writer.add(audioInput)
                self.audioInput = audioInput
            }
        }
        
        // Start writing
        guard writer.startWriting() else {
            throw DisplayRecorderError.assetWriterFailed(writer.error)
        }
        
        writer.startSession(atSourceTime: .zero)
        
        // Store references
        self.assetWriter = writer
        self.videoInput = videoInput
        self.pixelBufferAdaptor = adaptor
        self.outputURL = url
        self.startTime = nil
        self.frameCount = 0
        self.recordingStartDate = Date()
        
        // Start duration timer
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateDuration()
            }
        }
        
        isRecording = true
        delegate?.recorderDidStartRecording(self)
    }
    
    /// Stops the current recording
    public func stopRecording() async throws {
        guard isRecording else {
            throw DisplayRecorderError.notRecording
        }
        
        durationTimer?.invalidate()
        durationTimer = nil
        
        videoInput?.markAsFinished()
        audioInput?.markAsFinished()
        
        await assetWriter?.finishWriting()
        
        let finalURL = outputURL
        
        // Clean up
        assetWriter = nil
        videoInput = nil
        pixelBufferAdaptor = nil
        audioInput = nil
        startTime = nil
        isRecording = false
        
        if let url = finalURL {
            delegate?.recorderDidStopRecording(self, outputURL: url)
        }
    }
    
    /// Appends a video frame from an IOSurface
    /// - Parameter surface: The IOSurface containing the frame
    public func appendFrame(from surface: IOSurface) {
        guard isRecording,
              let videoInput = videoInput,
              let adaptor = pixelBufferAdaptor,
              videoInput.isReadyForMoreMediaData else {
            return
        }
        
        // Create pixel buffer from IOSurface using IOSurface's backing
        guard let buffer = createPixelBuffer(from: surface) else {
            return
        }
        
        appendFrame(pixelBuffer: buffer)
    }
    
    /// Appends a video frame from a CVPixelBuffer
    /// - Parameter pixelBuffer: The pixel buffer containing the frame
    public func appendFrame(pixelBuffer buffer: CVPixelBuffer) {
        guard isRecording,
              let videoInput = videoInput,
              let adaptor = pixelBufferAdaptor,
              videoInput.isReadyForMoreMediaData else {
            return
        }
        
        // Calculate presentation time
        let currentTime: CMTime
        if let start = startTime {
            let elapsed = CFAbsoluteTimeGetCurrent() - CFAbsoluteTime(CMTimeGetSeconds(start))
            currentTime = CMTime(seconds: elapsed, preferredTimescale: 600)
        } else {
            startTime = CMTime(seconds: CFAbsoluteTimeGetCurrent(), preferredTimescale: 600)
            currentTime = .zero
        }
        
        // Ensure monotonically increasing timestamps
        guard currentTime > lastFrameTime || lastFrameTime == .zero else {
            return
        }
        
        // Append the frame
        if adaptor.append(buffer, withPresentationTime: currentTime) {
            lastFrameTime = currentTime
            frameCount += 1
        }
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
    
    private func updateDuration() {
        guard let startDate = recordingStartDate else { return }
        let newDuration = Date().timeIntervalSince(startDate)
        duration = newDuration
        delegate?.recorder(self, didUpdateDuration: newDuration)
    }
}
