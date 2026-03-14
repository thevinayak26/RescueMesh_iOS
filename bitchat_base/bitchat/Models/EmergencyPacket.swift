import Foundation
import CoreLocation
#if os(iOS)
import UIKit
#endif

/// Represents a specialized SOS packet for the mesh network.
public struct EmergencyPacket: Codable, Equatable {
    public let packetId: String
    public let timestamp: TimeInterval
    public let latitude: Double
    public let longitude: Double
    public let emergencyType: EmergencyType
    public var hopCount: Int
    public let ttl: Int
    public let batteryLevel: Int // 0-100 percentage
    
    public init(type: EmergencyType, location: CLLocationCoordinate2D?, ttl: Int = 7) {
        self.packetId = UUID().uuidString
        self.timestamp = Date().timeIntervalSince1970
        self.latitude = location?.latitude ?? 0.0
        self.longitude = location?.longitude ?? 0.0
        self.emergencyType = type
        self.hopCount = 0
        self.ttl = ttl
        
        #if os(iOS)
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = UIDevice.current.batteryLevel // -1.0 if unknown, 0.0–1.0
        self.batteryLevel = level >= 0 ? Int(level * 100) : -1
        #else
        self.batteryLevel = -1
        #endif
    }
    
    public func encodeToPayload() -> String {
        return "EMERGENCY_SOS|\(packetId)|\(timestamp)|\(emergencyType.rawValue)|\(latitude)|\(longitude)|\(hopCount)|\(ttl)|\(batteryLevel)"
    }
    
    public static func decodeFromPayload(_ payload: String) -> EmergencyPacket? {
        let parts = payload.components(separatedBy: "|")
        // Support both old 8-part and new 9-part format
        guard parts.count >= 8, parts[0] == "EMERGENCY_SOS" else { return nil }
        
        guard let timestamp = TimeInterval(parts[2]),
              let type = EmergencyType(rawValue: parts[3]),
              let lat = Double(parts[4]),
              let lon = Double(parts[5]),
              let hops = Int(parts[6]),
              let ttl = Int(parts[7]) else {
            return nil
        }
        
        let battery = parts.count >= 9 ? (Int(parts[8]) ?? -1) : -1
        
        return EmergencyPacket(id: parts[1], timestamp: timestamp, lat: lat, lon: lon, type: type, hops: hops, ttl: ttl, battery: battery)
    }
    
    // Internal reconstructor for decoding
    private init(id: String, timestamp: TimeInterval, lat: Double, lon: Double, type: EmergencyType, hops: Int, ttl: Int, battery: Int) {
        self.packetId = id
        self.timestamp = timestamp
        self.latitude = lat
        self.longitude = lon
        self.emergencyType = type
        self.hopCount = hops
        self.ttl = ttl
        self.batteryLevel = battery
    }
}
