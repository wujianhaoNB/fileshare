# FileShare - Setup Guide

## Prerequisites

1. Install Flutter SDK (3.22+): https://docs.flutter.dev/get-started/install
2. Android Studio (for Android builds)
3. Xcode 15+ (for iOS builds, macOS only)
4. Visual Studio 2022 with "Desktop development with C++" (for Windows builds)

## Initial Setup

After cloning/creating the project:

```bash
# 1. Generate platform files
flutter create --project-name fileshare --org com.fileshare .

# 2. Generate drift & Riverpod code
dart run build_runner build --delete-conflicting-outputs

# 3. Get dependencies
flutter pub get
```

## Platform Configuration

### Android

Already configured in `android/app/src/main/AndroidManifest.xml`:
- `usesCleartextTraffic=true` for LAN HTTP
- All permissions for network, Bluetooth, camera, storage
- Foreground service for background transfers

Minimum SDK: 21 (Android 5.0)
Target SDK: 34

### iOS

Add to `ios/Runner/Info.plist`:

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>FileShare needs local network access to find and transfer files to nearby devices.</string>

<key>NSBonjourServices</key>
<array>
    <string>_fileshare._tcp</string>
</array>

<key>NSBluetoothAlwaysUsageDescription</key>
<string>FileShare uses Bluetooth to transfer files when Wi-Fi is unavailable.</string>

<key>NSCameraUsageDescription</key>
<string>Camera access is needed to scan QR codes for device pairing.</string>

<key>UIBackgroundModes</key>
<array>
    <string>bluetooth-central</string>
    <string>bluetooth-peripheral</string>
</array>

<key>UIFileSharingEnabled</key>
<true/>
```

### Windows

No special configuration needed. On first run:
1. Windows Firewall will prompt to allow network access — click "Allow"
2. The app binds to ports 8080 (control) and 9876 (data)

## Running

```bash
# Run on Windows
flutter run -d windows

# Run on Android
flutter run -d android

# Run on iOS (macOS only)
flutter run -d ios

# Build Windows executable
flutter build windows --release
```

## Testing

```bash
# Unit tests
flutter test

# Integration test (needs 2 devices on same network)
flutter test integration_test/
```

## Project Structure

```
lib/
├── main.dart              # Entry point
├── app.dart               # MaterialApp + theme
├── core/                  # Constants, utils, errors
├── data/                  # Database, repositories, models
├── network/               # mDNS, TCP, protocol, server
├── services/              # Discovery, transfer, file manager
├── providers/             # Riverpod state management
└── ui/                    # Screens, widgets, layouts
```
