# MotoCom 🏍️
### Offline Motorcycle Intercom for Rider & Pillion with YouTube Music Ducking

MotoCom is a peer-to-peer motorcycle intercom application built with Flutter, Kotlin, and Swift. It requires **zero cellular data and zero phone network**. It creates a high-speed direct Wi-Fi link between Rider and Pillion, allowing full-duplex hands-free voice communication while seamlessly coexisting with **YouTube Music**.

---

## Key Features

1. **100% Offline (Zero Data / Calling):**
   - Connects Rider and Pillion directly via a local Wi-Fi Hotspot (SoftAP).
   - Ultra-low latency (<20ms) and high bandwidth compared to legacy Bluetooth intercoms.

2. **One-Tap QR Code Auto-Join:**
   - **Rider (Host):** Generates a dynamic pairing QR code with local network credentials.
   - **Pillion (Client):** Scans the QR code with the in-app camera.
   - **Zero Manual Configuration:** Uses native `WifiNetworkSpecifier` (Android) and `NEHotspotConfigurationManager` (iOS) to automatically join the Wi-Fi network without leaving the app.

3. **YouTube Music Smart Audio Ducking:**
   - Both riders can play their downloaded offline tracks directly inside YouTube Music.
   - When either rider speaks, MotoCom automatically ducks YouTube Music volume to **20%** via OS-level audio focus (`duckOthers` on iOS / `AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK` on Android).
   - Smoothly fades YouTube Music back to 100% when speech ends.

4. **Motorcycle Helmet Audio Routing:**
   - Routes mic and speaker to Bluetooth helmet communicators (Cardo, Sena, FreedConn) or earbuds (AirPods, Galaxy Buds).
   - Hardware Acoustic Echo Cancellation (AEC) and Noise Suppression to filter out motorcycle exhaust and wind noise.

5. **Glove-Friendly Interface:**
   - Oversized tap targets (>64dp) and high-contrast dark OLED theme designed for motorcycle mounts.
   - Push-to-Talk (PTT) or Hands-Free Voice Activation (VOX) with adjustable wind noise gate.

---

## Project Structure

```text
motocom/
├── android/
│   ├── app/
│   │   ├── build.gradle
│   │   └── src/main/
│   │       ├── AndroidManifest.xml
│   │       └── kotlin/com/motocom/intercom/
│   │           ├── MainActivity.kt        # QR Wi-Fi auto-connect & PlatformChannel
│   │           └── MotoComAndroidEngine.kt # Hotspot, SCO audio, and ducking focus
├── ios/
│   └── Runner/
│       ├── Info.plist                     # Mic, Camera, Local Network permissions
│       ├── AppDelegate.swift              # NEHotspotConfiguration QR auto-join
│       └── MotoComAudioSession.swift      # AVAudioSession with .duckOthers & SCO
├── lib/
│   ├── main.dart                          # App bootstrap & permission handling
│   ├── intercom_screen.dart               # Glove-optimized rider interface
│   ├── services/
│   │   ├── intercom_platform_service.dart # Platform channel bridge
│   │   └── qr_connection_model.dart       # QR credentials serialization
│   └── widgets/
│       └── qr_pair_dialog.dart            # QR Generator (Host) & QR Scanner (Client)
├── core/
│   └── intercom_engine.py                 # Protocol simulator, VAD, and ducker tests
└── pubspec.yaml                           # Flutter dependencies
```

---

## How to Run & Build

### Prerequisites
- [Flutter SDK](https://flutter.dev) (v3.10+)
- Android Studio / Xcode for deploying to physical devices.

### 1. Install Dependencies
```bash
cd motocom
flutter pub get
```

### 2. Run on Android Device
Connect your Android phone via USB with USB debugging enabled:
```bash
flutter run -d <android-device-id>
```

### 3. Run on iPhone
Connect your iPhone via USB and open `ios/Runner.xcworkspace` in Xcode:
1. Select your Development Team under **Signing & Capabilities**.
2. Run from Xcode or terminal:
```bash
flutter run -d <iphone-device-id>
```

---

## Testing Protocol & Audio Math Locally

You can test the audio ducking math and packet framing on your Mac without a phone:
```bash
python3 motocom/core/intercom_engine.py
```
Expected output:
```text
✅ Packet framing test passed (Header size: 17 bytes)
✅ VAD & Noise Gate test passed
✅ Audio ducking simulation passed (YouTube Music volume ducks to 20% on speech)
```
