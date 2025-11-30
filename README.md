# jamSync

jamSync keeps multiple devices on the same LAN or hotspot in lockstep audio playback. The Admin/Player leads playback and Speakers follow via LAN sync ticks.

## Requirements

- Flutter 3.24+
- Devices on the same Wi-Fi network or manually created hotspot (jamSync does not create a hotspot)

## Quick Start

```bash
flutter pub get
flutter run
```

During development you can run the player and speaker UIs on different emulators/devices:

```bash
flutter run -d device_id --target=lib/main.dart
```

## Architecture Highlights

- Discovery via UDP multicast (see `infrastructure/network/udp_discovery_service.dart`).
- Messaging hub over TCP sockets (see `infrastructure/network/socket_messaging_service.dart`).
- Sync engine adjusts drift using ping/pong + sync ticks (`infrastructure/sync/sync_engine_impl.dart`).
- Presentation uses GetX controllers (`presentation/player`, `presentation/speaker`, `presentation/session`).

## Daily Use Tips

1. Connect all devices to the same LAN or enable a hotspot from the Admin device.
2. Launch jamSync on the Admin device, create a session, and leave the app in the foreground.
3. Other devices join via the discovery list; Speakers display drift/latency metrics to help you position audio gear.
4. If a connection drops, jamSync auto-retries and shows a retry button banner.

## Troubleshooting

- Use the reconnect button on the session screen if Speakers lose connection.
- Ensure the hotspot/LAN allows multicast traffic for discovery.
- Drift above 150 ms triggers hard seeks; watch the drift bar on the Speaker page to diagnose.
