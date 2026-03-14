import Foundation
#if os(iOS)
import UIKit
#endif
import CoreLocation

/// Defines the priority order for emergency communications.
public enum CommunicationLayer {
    case cellular
    case satellite
    case mesh
}

public protocol CommunicationDecisionEngineProtocol {
    func evaluateAndExecute(for type: EmergencyType, location: CLLocationCoordinate2D?)
}

public final class CommunicationDecisionEngine: CommunicationDecisionEngineProtocol {
    public static let shared = CommunicationDecisionEngine()
    
    /// Set to `true` for hackathon demo: skips cellular/satellite and goes straight to mesh.
    public var demoMode: Bool = true
    
    private init() {}
    
    public func evaluateAndExecute(for type: EmergencyType, location: CLLocationCoordinate2D?) {
        if demoMode {
            // DEMO MODE: Skip all connectivity checks, go straight to mesh
            print("⚠️ DEMO MODE: Simulating no cellular/satellite. Falling back to Mesh immediately.")
            activateMeshFallback(type: type, location: location)
            return
        }
        
        // Production path (not used during demo)
        if attemptCellular() {
            print("Cellular emergency active. Pausing further routing.")
        }
        print("Satellite SOS not available natively. Bypassing...")
        activateMeshFallback(type: type, location: location)
    }
    
    private func attemptCellular() -> Bool {
        #if os(iOS)
        return false
        #else
        return false
        #endif
    }
    
    private func activateMeshFallback(type: EmergencyType, location: CLLocationCoordinate2D?) {
        print("🚨 Activating BitChat Mesh Emergency Fallback...")
        
        // Construct a proper EmergencyPacket and encode it
        let packet = EmergencyPacket(type: type, location: location)
        let payload = packet.encodeToPayload()
        
        print("📡 Broadcasting SOS payload: \(payload)")
        
        // Post notification for ChatViewModel to pick up and broadcast
        NotificationCenter.default.post(
            name: NSNotification.Name("BitChatEmergencyFallbackTriggered"),
            object: nil,
            userInfo: ["payload": payload]
        )
    }
}
