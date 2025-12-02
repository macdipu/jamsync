# JamSync - Multi-Device Synchronized Audio Playback

JamSync enables multiple devices to play the same audio in perfect synchronization over a local network. Create a unified sound system using phones, tablets, and computers - all playing the exact same track at the exact same moment.

[![Flutter](https://img.shields.io/badge/Flutter-3.38.3+-02569B?logo=flutter)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20macOS-lightgrey)]()
[![License](https://img.shields.io/badge/License-MIT-green)]()

## ✨ Features

- 🎵 **Perfect Sync**: Sub-150ms audio synchronization across all devices
- 🌐 **LAN Discovery**: Automatic device discovery via UDP multicast
- 📡 **Audio Streaming**: Host streams audio to speakers over HTTP
- 🎛️ **Centralized Control**: One host controls playback for all speakers
- 📊 **Real-time Metrics**: Monitor drift, latency, and connection status
- 🔄 **Auto-Reconnect**: Resilient connection with automatic retry
- 🎧 **Background Playback**: Continues playing when app is minimized

## 🏗️ Architecture Overview

### System Roles

JamSync uses a **Host-Speakers** architecture with three distinct roles:

```
┌─────────────────────────────────────────────────────────────────────┐
│                         JamSync Network                             │
│                                                                     │
│  ┌──────────────┐                                                  │
│  │     HOST     │  • Owns the audio file                           │
│  │   (Player)   │  • Streams audio over HTTP                       │
│  │              │  • Broadcasts sync ticks                         │
│  │              │  • Controls playback state                       │
│  └──────┬───────┘                                                  │
│         │                                                           │
│         │ HTTP Stream (Port 8888)                                  │
│         │ Sync Messages (Port 51234)                               │
│         │                                                           │
│         ├─────────────┬──────────────┬──────────────┐             │
│         │             │              │              │             │
│  ┌──────▼─────┐ ┌────▼──────┐ ┌────▼──────┐ ┌────▼──────┐       │
│  │  SPEAKER 1 │ │ SPEAKER 2 │ │ SPEAKER 3 │ │ SPEAKER N │       │
│  │            │ │           │ │           │ │           │       │
│  │ • Streams  │ │ • Streams │ │ • Streams │ │ • Streams │       │
│  │ • Syncs    │ │ • Syncs   │ │ • Syncs   │ │ • Syncs   │       │
│  │ • Adjusts  │ │ • Adjusts │ │ • Adjusts │ │ • Adjusts │       │
│  └────────────┘ └───────────┘ └───────────┘ └───────────┘       │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### How Synchronized Playback Works

#### 1️⃣ **Session Creation & Discovery**

```
┌─────────┐                                    ┌─────────┐
│  Host   │                                    │ Speaker │
└────┬────┘                                    └────┬────┘
     │                                              │
     │ 1. Create Session                            │
     │    - Generate Session ID                     │
     │    - Start HTTP Server (8888)                │
     │    - Start Messaging Hub (51234)             │
     │    - Broadcast UDP Announcement              │
     │                                              │
     │    UDP Multicast (239.255.255.250:53333)    │
     ├─────────────────────────────────────────────>│
     │    "Session: XYZ @ 192.168.1.100:51234"     │
     │                                              │
     │                                              │ 2. Discover & Join
     │           HTTP POST /messages                │    - See announcement
     │           "stateRequest"                     │    - Connect to hub
     │<─────────────────────────────────────────────┤
     │                                              │
     │ 3. Send Full State                           │
     │    - Stream URL                              │
     │    - Current track                           │
     │    - Playback state                          │
     ├─────────────────────────────────────────────>│
     │                                              │
```

#### 2️⃣ **Audio Streaming Architecture**

```
┌──────────────────────────────────────────────────────────────────┐
│                     HOST DEVICE                                  │
│                                                                  │
│  ┌─────────────────┐                                            │
│  │  Track Source   │                                            │
│  │  ┌───────────┐  │                                            │
│  │  │ content:// │  │  Content URIs (Android MediaStore)       │
│  │  │ file://    │  │  Local files                             │
│  │  │ http://    │  │  Remote URLs                             │
│  │  └─────┬─────┘  │                                            │
│  └────────┼────────┘                                            │
│           │                                                      │
│           ▼                                                      │
│  ┌────────────────────────────────────────┐                    │
│  │  Content URI Caching (Android)         │                    │
│  │  ┌──────────────────────────────────┐  │                    │
│  │  │ 1. Detect content:// scheme      │  │                    │
│  │  │ 2. Copy to cache via MethodCall  │  │                    │
│  │  │ 3. Store at /cache/audio_stream_ │  │                    │
│  │  └──────────────┬───────────────────┘  │                    │
│  └─────────────────┼───────────────────────┘                    │
│                    │                                             │
│           ┌────────▼─────────┐                                  │
│           │  HTTP Server     │                                  │
│           │  Port 8888       │                                  │
│           │                  │                                  │
│           │  GET /stream     │  Serves audio file               │
│           │  GET /metadata   │  Track information               │
│           │  GET /health     │  Server status                   │
│           └────────┬─────────┘                                  │
│                    │                                             │
└────────────────────┼─────────────────────────────────────────────┘
                     │
                     │ HTTP/1.1 Audio Stream
                     │ Content-Type: audio/mpeg
                     │ Transfer-Encoding: chunked
                     │
        ┌────────────┼───────────────┬──────────────┐
        │            │               │              │
┌───────▼─────┐ ┌───▼────────┐ ┌───▼────────┐ ┌──▼─────────┐
│  Speaker 1  │ │ Speaker 2  │ │ Speaker 3  │ │ Speaker N  │
│             │ │            │ │            │ │            │
│ AudioPlayer │ │AudioPlayer │ │AudioPlayer │ │AudioPlayer │
│ (just_audio)│ │(just_audio)│ │(just_audio)│ │(just_audio)│
└─────────────┘ └────────────┘ └────────────┘ └────────────┘
```

**Key Points**:
- **Content URI Caching**: Android MediaStore URIs are copied to cache before streaming
- **Single Source**: Only host reads the audio file, speakers stream over network
- **Efficient Streaming**: HTTP chunked encoding for minimal latency
- **Multi-Format Support**: MP3, M4A, FLAC, OGG, WAV

#### 3️⃣ **Synchronization Protocol**

JamSync uses a sophisticated sync protocol to keep all devices in lockstep:

```
┌─────────────────────────────────────────────────────────────────┐
│                  SYNCHRONIZATION TIMELINE                       │
└─────────────────────────────────────────────────────────────────┘

TIME    HOST                        SPEAKER
═════   ═════════════════════       ════════════════════════

t=0s    ┌─────────────────┐         ┌─────────────────┐
        │ Play Command    │         │ Receives        │
        │ position: 0:00  │────────>│ Loads stream    │
        │ state: playing  │         │ Starts playback │
        └─────────────────┘         └─────────────────┘

t=2s    ┌─────────────────┐         ┌─────────────────┐
        │ Sync Tick #1    │         │ Compares        │
        │ position: 2.0s  │────────>│ Local: 2.1s     │
        │ timestamp: T1   │         │ Drift: +100ms   │
        └─────────────────┘         └─────────────────┘
                                              │
                                              ▼
                                    ┌───────────────────┐
                                    │ Speed Adjustment  │
                                    │ playbackRate: 0.95│
                                    │ (slow down 5%)    │
                                    └───────────────────┘

t=4s    ┌─────────────────┐         ┌─────────────────┐
        │ Sync Tick #2    │         │ Compares        │
        │ position: 4.0s  │────────>│ Local: 4.02s    │
        │ timestamp: T2   │         │ Drift: +20ms    │
        └─────────────────┘         └─────────────────┘
                                              │
                                              ▼
                                    ┌───────────────────┐
                                    │ Speed Adjustment  │
                                    │ playbackRate: 1.0 │
                                    │ (normal speed)    │
                                    └───────────────────┘

t=6s    ┌─────────────────┐         ┌─────────────────┐
        │ Sync Tick #3    │         │ Compares        │
        │ position: 6.0s  │────────>│ Local: 5.8s     │
        │ timestamp: T3   │         │ Drift: -200ms   │
        └─────────────────┘         └─────────────────┘
                                              │
                                              ▼
                                    ┌───────────────────┐
                                    │ Hard Seek         │
                                    │ seek(6.0s)        │
                                    │ (drift too large) │
                                    └───────────────────┘
```

**Sync Algorithm**:

1. **Sync Tick Broadcast** (every 2 seconds):
   ```
   {
     "type": "syncTick",
     "position": 4.523,      // Host's current playback position
     "timestamp": 1234567890, // UTC timestamp
     "isPlaying": true
   }
   ```

2. **Drift Calculation**:
   ```dart
   drift = speakerPosition - hostPosition
   ```

3. **Correction Strategy**:
   - **< 50ms drift**: No action (acceptable tolerance)
   - **50-150ms drift**: Speed adjustment (0.95x - 1.05x playback rate)
   - **> 150ms drift**: Hard seek to host position

4. **Latency Compensation**:
   - Ping/pong messages measure network round-trip time
   - Adjusts sync calculations for network delay
   - Monitors connection quality

#### 4️⃣ **Message Flow**

```
┌──────────────────────────────────────────────────────────────────┐
│              HTTP MESSAGING HUB (Port 51234)                     │
└──────────────────────────────────────────────────────────────────┘

HOST                                                  SPEAKER
════                                                  ═════════

┌─────────────┐                                      ┌─────────────┐
│ Enqueue Msg │                                      │ Poll Loop   │
│ ┌─────────┐ │                                      │ GET /messages│
│ │syncTick │ │                                      │ every 200ms │
│ │command  │ │                                      └──────┬──────┘
│ │state    │ │                                             │
│ └────┬────┘ │                                             │
└──────┼──────┘                                             │
       │                                                     │
       │ Message Queue                                      │
       │ (In-memory FIFO)                                   │
       │                                                     │
       │    HTTP GET /messages                              │
       │<───────────────────────────────────────────────────┤
       │                                                     │
       │    200 OK                                          │
       │    [                                               │
       │      {"type":"syncTick","position":4.5},           │
       │      {"type":"playbackCommand","action":"play"}    │
       │    ]                                               │
       ├────────────────────────────────────────────────────>│
       │                                                     │
       │                                                     ▼
       │                                              ┌────────────┐
       │                                              │ Process    │
       │                                              │ - Sync pos │
       │                                              │ - Execute  │
       │                                              └────────────┘
       │                                                     │
       │    HTTP POST /messages                             │
       │    {"type":"ping"}                                 │
       │<───────────────────────────────────────────────────┤
       │                                                     │
       │    Enqueue Response                                │
       │    {"type":"pong","timestamp":...}                 │
       ├────────────────────────────────────────────────────>│
```

**Message Types**:

| Type | Direction | Purpose |
|------|-----------|---------|
| `stateRequest` | Speaker → Host | Request current playback state |
| `streamUrl` | Host → Speaker | Share audio stream URL |
| `queueUpdate` | Host → Speaker | Notify of playlist changes |
| `playbackCommand` | Host → Speaker | Control playback (play/pause/seek) |
| `syncTick` | Host → Speaker | Periodic position sync |
| `ping` / `pong` | Bidirectional | Measure latency |

#### 5️⃣ **State Management**

```
┌──────────────────────────────────────────────────────────────────┐
│                         GetX Controllers                         │
└──────────────────────────────────────────────────────────────────┘

HOST Device                          SPEAKER Device
═══════════                          ══════════════

┌──────────────────┐                ┌──────────────────┐
│ HomeController   │                │ HomeController   │
│ - Device info    │                │ - Device info    │
│ - Session list   │                │ - Discovery      │
└────────┬─────────┘                └────────┬─────────┘
         │                                   │
         ▼                                   ▼
┌──────────────────┐                ┌──────────────────┐
│SessionController │                │SessionController │
│ - Session info   │                │ - Session info   │
│ - Member list    │                │ - Connection     │
└────────┬─────────┘                └────────┬─────────┘
         │                                   │
         ▼                                   ▼
┌──────────────────┐                ┌──────────────────┐
│PlayerController  │                │SpeakerController │
│ - Track queue    │                │ - Stream URL     │
│ - Playback state │                │ - Sync engine    │
│ - HTTP server    │                │ - Audio player   │
│ - Audio stream   │                │ - Drift monitor  │
│ - Sync broadcast │                │ - Reconnection   │
└────────┬─────────┘                └────────┬─────────┘
         │                                   │
         ▼                                   ▼
┌──────────────────┐                ┌──────────────────┐
│ Services Layer   │                │ Services Layer   │
│ - PlaybackSvc    │                │ - PlaybackSvc    │
│ - StreamSvc      │                │ - SyncEngine     │
│ - MediaScanner   │                │ - AudioStream    │
│ - RoleService    │                │ - RoleService    │
└──────────────────┘                └──────────────────┘
```

### Component Diagram

```
┌────────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                          │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐     │
│  │  Home    │  │ Session  │  │  Player  │  │ Speaker  │     │
│  │  View    │  │  View    │  │  View    │  │  View    │     │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘     │
│       │             │              │             │            │
│       ▼             ▼              ▼             ▼            │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐     │
│  │  Home    │  │ Session  │  │  Player  │  │ Speaker  │     │
│  │Controller│  │Controller│  │Controller│  │Controller│     │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘     │
└───────┼─────────────┼──────────────┼─────────────┼───────────┘
        │             │              │             │
┌───────┼─────────────┼──────────────┼─────────────┼───────────┐
│       │             │      DOMAIN LAYER           │           │
│       │             │              │             │            │
│  ┌────▼─────────────▼──────────────▼─────────────▼────┐      │
│  │              Service Interfaces                    │      │
│  │  - ISessionService    - IPlaybackService          │      │
│  │  - IMessagingService  - IAudioStreamService       │      │
│  │  - IDiscoveryService  - ISyncEngine               │      │
│  │  - IDeviceService     - IRoleService              │      │
│  │  - IMediaScannerService                           │      │
│  └───────────────────────┬───────────────────────────┘      │
└──────────────────────────┼──────────────────────────────────┘
                           │
┌──────────────────────────┼──────────────────────────────────┐
│           INFRASTRUCTURE LAYER (Implementations)             │
│                          │                                   │
│  ┌───────────────────────▼────────────────────────┐         │
│  │         Network Services                       │         │
│  │  ┌─────────────────┐  ┌──────────────────┐   │         │
│  │  │ UDP Discovery   │  │ HTTP Messaging   │   │         │
│  │  │ Multicast 53333 │  │ Hub Port 51234   │   │         │
│  │  └─────────────────┘  └──────────────────┘   │         │
│  └────────────────────────────────────────────────┘         │
│                                                              │
│  ┌────────────────────────────────────────────────┐         │
│  │         Audio Services                         │         │
│  │  ┌──────────────────┐  ┌──────────────────┐   │         │
│  │  │ HTTP Audio Stream│  │ Playback Service │   │         │
│  │  │ Server Port 8888 │  │ (just_audio)     │   │         │
│  │  └──────────────────┘  └──────────────────┘   │         │
│  └────────────────────────────────────────────────┘         │
│                                                              │
│  ┌────────────────────────────────────────────────┐         │
│  │         Sync Services                          │         │
│  │  ┌──────────────────┐  ┌──────────────────┐   │         │
│  │  │ Sync Engine      │  │ Role Service     │   │         │
│  │  │ Drift Correction │  │ Admin/Speaker    │   │         │
│  │  └──────────────────┘  └──────────────────┘   │         │
│  └────────────────────────────────────────────────┘         │
│                                                              │
│  ┌────────────────────────────────────────────────┐         │
│  │         Platform Services                      │         │
│  │  ┌──────────────────┐  ┌──────────────────┐   │         │
│  │  │ Media Scanner    │  │ Local Storage    │   │         │
│  │  │ (on_audio_query) │  │ (SharedPrefs)    │   │         │
│  │  └──────────────────┘  └──────────────────┘   │         │
│  └────────────────────────────────────────────────┘         │
└──────────────────────────────────────────────────────────────┘
```

## 🚀 Getting Started

### Prerequisites

- Flutter 3.38.3 or higher
- All devices on the same Wi-Fi network or hotspot
- Android: API 21+ (Lollipop)
- iOS: iOS 12.0+
- macOS: macOS 10.14+

### Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/jamsync.git
cd jamsync

# Install dependencies
flutter pub get

# Run on device
flutter run
```

### Building for Production

```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release

# macOS
flutter build macos --release
```

## 📱 Usage Guide

### 1. Create a Session (Host Device)

1. Launch JamSync
2. Tap **Create Session**
3. Enter session name
4. Navigate to **Player** screen
5. Select tracks from your library
6. Press **Play**

### 2. Join as Speaker

1. Launch JamSync on other devices
2. Wait for session to appear in discovery list
3. Tap session name to join
4. Navigate to **Speaker** mode
5. Audio will automatically sync with host

### 3. Monitor Synchronization

- **Drift Indicator**: Shows how far ahead/behind speaker is
- **Latency**: Network round-trip time
- **Connection Status**: Real-time connection health
- **Sync Quality**: Visual feedback on sync accuracy

## 🛠️ Technical Stack

| Component | Technology |
|-----------|-----------|
| Framework | Flutter 3.38.3+ |
| State Management | GetX |
| Audio Playback | just_audio, audio_service |
| HTTP Server | shelf (Dart) |
| Discovery | UDP Multicast |
| Messaging | HTTP Long-polling |
| Storage | shared_preferences |
| Media Query | on_audio_query_plus |

## 📊 Performance Metrics

- **Sync Accuracy**: < 50ms typical, < 150ms maximum
- **Network Latency**: 10-100ms LAN, varies by network
- **Sync Interval**: 2 seconds (configurable)
- **Discovery Time**: 1-3 seconds typical
- **Audio Formats**: MP3, M4A, FLAC, OGG, WAV
- **Max Speakers**: Limited only by network bandwidth

## 🔧 Configuration

### Adjusting Sync Tolerance

Edit `lib/infrastructure/sync/sync_engine_impl.dart`:

```dart
static const _minorDriftThreshold = 50.0;   // Speed adjustment
static const _largeDriftThreshold = 150.0;  // Hard seek
```

### Changing Port Numbers

Edit respective service files:

- HTTP Stream: `8888` in `http_audio_stream_service.dart`
- Messaging Hub: `51234` in `socket_messaging_service.dart`  
- Discovery: `53333` in `udp_discovery_service.dart`

## 🐛 Troubleshooting

### Speakers Not Discovering Host

- Ensure all devices on same network
- Check firewall allows UDP multicast (239.255.255.250)
- Verify UDP port 53333 not blocked
- Try creating hotspot from host device

### Audio Stuttering on Speakers

- Reduce number of connected speakers
- Check network bandwidth (WiFi speed)
- Move devices closer to router
- Disable other network-heavy apps

### Large Drift (> 150ms)

- Check network latency with ping test
- Reduce distance between router and devices
- Switch to 5GHz WiFi if available
- Check for network congestion

### Content URI Streaming Issues

- Ensure READ_MEDIA_AUDIO permission granted (Android 13+)
- Check that tracks are in MediaStore
- Try re-scanning media library
- Check logs for cache file creation

## 📁 Project Structure

```
lib/
├── main.dart                          # App entry point
├── app/
│   └── routes/                        # Navigation
├── core/
│   ├── di/                           # Dependency injection
│   └── logging/                      # Logging utilities
├── domain/
│   ├── entities/                     # Data models (Track, Session, etc.)
│   └── services_interfaces/          # Service contracts
├── infrastructure/
│   ├── audio/                        # Audio streaming & playback
│   ├── network/                      # Discovery & messaging
│   ├── storage/                      # Local persistence
│   └── sync/                         # Synchronization engine
└── presentation/
    ├── home/                         # Home screen
    ├── session/                      # Session management
    ├── player/                       # Host player UI
    └── speaker/                      # Speaker UI

android/                              # Android-specific code
├── app/src/main/kotlin/.../          
│   └── MainActivity.kt               # Platform channels

ios/                                  # iOS-specific code
macos/                               # macOS-specific code
```

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [just_audio](https://pub.dev/packages/just_audio) - Audio playback
- [audio_service](https://pub.dev/packages/audio_service) - Background audio
- [GetX](https://pub.dev/packages/get) - State management
- [shelf](https://pub.dev/packages/shelf) - HTTP server

## 📞 Support

- 📧 Email: support@jamsync.dev
- 🐛 Issues: [GitHub Issues](https://github.com/yourusername/jamsync/issues)
- 💬 Discussions: [GitHub Discussions](https://github.com/yourusername/jamsync/discussions)

---

**Made with ❤️ by the JamSync Team**

