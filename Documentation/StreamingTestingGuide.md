# VirtualDisplayKit Streaming Testing Guide

## Overview

The streaming feature captures frames from the virtual display, encodes them using VideoToolbox (H.264 or HEVC), and delivers encoded data via a callback. This is useful for:

- Sending to RTMP servers (Twitch, YouTube Live, etc.)
- Integrating with OBS via custom plugins
- Building custom streaming solutions
- Network-based display sharing

## Quick Test in the Demo App

1. **Start the display**: Select a preset and click "Start Display"
2. **Start streaming**: Click "Start Streaming" in the Streaming section
3. **Watch the counters**: You should see:
   - **Frames**: Incrementing count of encoded frames
   - **Data**: Total encoded data size
   - **fps indicator**: Shows current frame rate (bottom right "LIVE X fps")

If frames are incrementing, streaming is working! The data is being encoded and passed to the callback.

## Testing with a File Output

To verify the encoded data is valid, you can modify the demo app to write frames to a file:

```swift
// In ContentView.swift, modify toggleStreaming():

func toggleStreaming() {
    if isStreaming {
        controller.stopStreaming()
        // ... existing code
    } else {
        // Create a file to write encoded data
        let documentsURL = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first!
        let streamURL = documentsURL.appendingPathComponent("stream_test.h264")
        FileManager.default.createFile(atPath: streamURL.path, contents: nil, attributes: nil)
        let handle = try? FileHandle(forWritingTo: streamURL)
        
        try controller.startStreaming(configuration: .rtmpStreaming) { [weak self] data, time, isKeyFrame in
            // Write to file
            try? handle?.write(contentsOf: data)
            
            // Update UI
            Task { @MainActor in
                self?.streamingFrameCount += 1
                self?.streamingBytesOutput += Int64(data.count)
            }
        }
    }
}
```

Then play the resulting `.h264` file with:
```bash
ffplay ~/Movies/stream_test.h264
```

## Testing with FFmpeg (RTMP)

To test actual RTMP streaming, you can set up a local RTMP server:

### 1. Install nginx with RTMP module (macOS)

```bash
brew tap denji/nginx
brew install nginx-full --with-rtmp-module
```

### 2. Configure nginx for RTMP

Add to `/usr/local/etc/nginx/nginx.conf`:

```nginx
rtmp {
    server {
        listen 1935;
        chunk_size 4096;
        
        application live {
            live on;
            record off;
        }
    }
}
```

### 3. Start nginx

```bash
nginx
```

### 4. Modify Demo App to Send RTMP

You'll need to add an RTMP client library. Here's the conceptual flow:

```swift
// Pseudocode - requires an RTMP library like HaishinKit
let rtmpConnection = RTMPConnection()
let rtmpStream = RTMPStream(connection: rtmpConnection)

rtmpConnection.connect("rtmp://localhost/live")

try controller.startStreaming(configuration: .rtmpStreaming) { data, time, isKeyFrame in
    // Send to RTMP stream
    rtmpStream.appendSampleBuffer(data, isKeyFrame: isKeyFrame, timestamp: time)
}
```

### 5. View the Stream

```bash
ffplay rtmp://localhost/live/stream
# or
vlc rtmp://localhost/live/stream
```

## Streaming Formats

The demo supports three formats:

| Format | Use Case | Output |
|--------|----------|--------|
| **H.264 (RTMP)** | RTMP streaming, web compatibility | Annex-B H.264 NAL units |
| **HEVC** | High efficiency, newer platforms | Annex-B HEVC NAL units |
| **Raw** | Custom processing, low latency | Raw pixel buffers |

## Programmatic Usage

```swift
import VirtualDisplayKit

let controller = VirtualDisplayController(preset: .standard1080p)
controller.start()

// Wait for display to be ready
// ...

// Start streaming with H.264
try controller.startStreaming(configuration: .rtmpStreaming) { data, presentationTime, isKeyFrame in
    // data: Encoded H.264 data (Annex-B format with start codes)
    // presentationTime: CMTime for synchronization
    // isKeyFrame: true for IDR frames (important for seeking/joining)
    
    print("Frame: \(data.count) bytes, keyframe: \(isKeyFrame)")
    
    // Send to your streaming destination
    myRTMPClient.send(data, timestamp: presentationTime)
}

// Later...
controller.stopStreaming()
```

## Custom Configuration

```swift
let config = StreamOutputConfiguration(
    format: .h264AnnexB,
    bitrate: 6_000_000,      // 6 Mbps
    maxKeyFrameInterval: 60,  // Keyframe every 2 seconds at 30fps
    expectedFrameRate: 30
)

try controller.startStreaming(configuration: config) { data, time, isKeyFrame in
    // Handle frames
}
```

## Troubleshooting

### 0 Frames / No Data
- Ensure the display is "Active" (green indicator)
- Check that screen recording permissions are granted
- Look for errors in Xcode console

### Low Frame Rate
- The virtual display refresh rate affects capture rate
- Ensure no other heavy processes are using the GPU
- Try reducing resolution

### Encoding Errors
- Check VideoToolbox availability
- HEVC may not be available on older hardware
- Try H.264 as fallback

## Integration Examples

### OBS WebSocket
Send frames to OBS via WebSocket for custom sources.

### WebRTC
Convert encoded frames to RTP packets for browser-based viewing.

### NDI
Wrap frames in NDI protocol for professional video workflows.

### Custom Protocol
Build your own protocol for LAN-based display sharing.
