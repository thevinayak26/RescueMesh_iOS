# RescueMesh — Emergency SOS via Bluetooth Mesh

> **When there's no signal, there's still RescueMesh.**

RescueMesh is an iOS emergency SOS system that works **without cellular, WiFi, or internet**. It uses **Bluetooth Low Energy mesh networking** to broadcast crash alerts, GPS location, medical info, and emergency contacts to nearby devices — even in dead zones.

---

## Key Features

- **Crash Detection** — Accelerometer detects impacts > 2.2g (configurable)
- **Smart Countdown** — 10-second window to cancel false alarms ("I'm OK" button)
- **Alarm & Haptics** — Alarm sound + triple-pulse vibration pattern every second
- **Bluetooth Mesh** — SOS broadcast via BLE mesh, relays up to 7 hops with no infrastructure
- **GPS Tracking** — Continuous location updates, cached for airplane mode
- **Battery Level** — Victim's battery percentage included in SOS
- **Medical Info** — Blood group displayed in emergency alert
- **Emergency Contacts** — Victim's contact number + family member number
- **One-Tap Navigation** — Rescuer can open Apple Maps with driving directions
- **Call 112** — Direct emergency call button on receiver's screen
- **Critical Notifications** — Bypass Do Not Disturb mode
- **Force SOS** — Instant trigger button for demo/testing (skips countdown)

---

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Language | Swift 5.9 |
| UI | SwiftUI |
| Communication | CoreBluetooth (BLE Mesh) |
| Crash Detection | CoreMotion (Accelerometer @ 50Hz) |
| GPS | CoreLocation (CLLocationManager) |
| Notifications | UserNotifications (Critical) |
| Haptics | UIImpactFeedbackGenerator + AudioServices |
| Navigation | MapKit |
| Battery | UIDevice |
| Architecture | MVVM |

---

## Architecture

```
+------------------------------------------------------+
|                    SwiftUI Layer                      |
|  ContentView <- SOSCountdownOverlay <- TextMessageView|
+------------------------------------------------------+
|                  ViewModel Layer                      |
|              ChatViewModel (MVVM)                     |
+------------------------------------------------------+
|                  Service Layer                        |
|  EmergencySensorService    SOSLocationManager         |
|  CommunicationDecisionEngine    NotificationService   |
+------------------------------------------------------+
|                 Network Layer                         |
|          BLEService (Bluetooth Mesh)                  |
|       EmergencyPacket (SOS Protocol)                  |
+------------------------------------------------------+
```

---

## How It Works

```
Impact Detected (> 2.2g)
  -> Alarm + Vibration + Push Notification
  -> 10-second countdown (user can cancel)
  -> EmergencyPacket created with:
      GPS coordinates, battery %, blood group, contacts
  -> CommunicationDecisionEngine evaluates:
      Cellular -> Satellite -> Bluetooth Mesh
  -> Packet broadcast over BLE mesh (highest priority)
  -> Relayed up to 7 hops to extend range
  -> Receiver gets: notification + red banner + MapKit + Call 112
```

---

## SOS Packet Format

```
EMERGENCY_SOS|<uuid>|<timestamp>|<type>|<lat>|<lon>|<hops>|<ttl>|<battery>
```

| Field | Example |
|-------|---------|
| Type | `crash` or `manual` |
| Lat/Lon | `28.6139, 77.2090` |
| Hops | `0` (increments per relay) |
| TTL | `7` (max relay hops) |
| Battery | `72` (percentage) |

---

## Configuration

### Drop Sensitivity

Located in `EmergencySensorService.swift`:

```swift
public var crashAccelerationThreshold: Double = 2.2  // in g-force
```

| Scenario | Recommended Value |
|----------|------------------|
| Demo (bag drop) | 2.0 - 2.5g |
| Bike/scooter fall | 3.0 - 4.0g |
| Car crash | 4.0 - 6.0g |

### Demo Mode

Located in `CommunicationDecisionEngine.swift`:

```swift
public var demoMode: Bool = true  // Skips cellular/satellite, goes straight to mesh
```

Set to `false` for production to enable cellular/satellite fallback checks.

---

## Setup & Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/thevinayak26/BitBenders_iOS.git
   ```

2. **Open in Xcode**
   ```
   Open bitchat_base/bitchat.xcodeproj
   ```

3. **Configure Signing**
   - Select each target under Signing & Capabilities
   - Check "Automatically manage signing"
   - Select your Apple ID team
   - Set unique Bundle Identifiers

4. **Connect iPhone via USB**
   - Enable Developer Mode: Settings > Privacy & Security > Developer Mode
   - Trust the developer certificate: Settings > General > VPN & Device Management

5. **Build & Run**
   ```
   Cmd+R
   ```

---

## Demo Instructions

### Setup (2 iPhones)
1. Install app on both phones
2. Set nicknames: "Victim" (Phone A) and "Rescuer" (Phone B)
3. Enable Airplane Mode on both, then re-enable Bluetooth only

### Trigger SOS
| Method | Action |
|--------|--------|
| **Drop** | Drop Phone A onto a bag (~1m height) |
| **SOS Button** | Tap red SOS button in header |
| **Force SOS** | Tap orange FORCE SOS button (instant, no countdown) |

### What Happens
- **Phone A**: Alarm + vibration + 10s countdown overlay
- **Phone B**: Push notification + red SOS banner with GPS, battery, blood group, contacts, Navigate button, Call 112 button

---

## Team

**BitBenders** — Built for Hackathon for Impact (H4I)

---

## License

This project is released into the public domain. See [LICENSE](LICENSE) for details.
