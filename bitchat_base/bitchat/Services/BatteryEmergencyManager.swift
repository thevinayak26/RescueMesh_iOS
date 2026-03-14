import Foundation
#if os(iOS)
import UIKit
#endif
import Combine

/// Manages battery-aware emergency behavior.
///
/// When an SOS is active AND battery is critically low (< 20%),
/// the BLE radio transmission pulse rate is increased 10x to maximize
/// the chance of the SOS reaching nearby devices before the phone dies.
///
/// Normal BLE rebroadcast: every ~5 seconds
/// Emergency low-battery:  every ~50 seconds (10x slower)
///
/// This conserves battery during emergencies so the device
/// stays alive longer and can keep transmitting the SOS signal.
final class BatteryEmergencyManager: ObservableObject {
    static let shared = BatteryEmergencyManager()
    
    // MARK: - Configuration
    
    /// Battery percentage below which we consider it "critical" during an emergency
    let criticalBatteryThreshold: Float = 0.20  // 20%
    
    /// Normal interval between SOS rebroadcasts (seconds)
    let normalPulseInterval: TimeInterval = 5.0
    
    /// Low-battery interval — 10x slower to conserve power
    let lowBatteryPulseInterval: TimeInterval = 50.0
    
    // MARK: - State
    
    @Published private(set) var currentBatteryLevel: Float = 1.0
    @Published private(set) var isBatteryLow: Bool = false
    @Published private(set) var isEmergencyActive: Bool = false
    @Published private(set) var isPulseSlowed: Bool = false
    
    private var pulseTimer: Timer?
    private var batteryMonitorTimer: Timer?
    private var sosPayload: String?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Init
    
    private init() {
        #if os(iOS)
        UIDevice.current.isBatteryMonitoringEnabled = true
        currentBatteryLevel = UIDevice.current.batteryLevel
        isBatteryLow = currentBatteryLevel >= 0 && currentBatteryLevel < criticalBatteryThreshold
        
        // Listen for battery level changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(batteryLevelChanged),
            name: UIDevice.batteryLevelDidChangeNotification,
            object: nil
        )
        
        print("[BatteryManager] Init — Battery: \(Int(currentBatteryLevel * 100))%, Low: \(isBatteryLow)")
        #endif
    }
    
    // MARK: - Public API
    
    /// Call when an SOS is triggered. Starts monitoring battery and adjusts pulse rate.
    func activateEmergencyMode(payload: String) {
        isEmergencyActive = true
        sosPayload = payload
        
        #if os(iOS)
        currentBatteryLevel = UIDevice.current.batteryLevel
        isBatteryLow = currentBatteryLevel >= 0 && currentBatteryLevel < criticalBatteryThreshold
        #endif
        
        evaluateAndSetPulseRate()
        startBatteryMonitoring()
        
        print("[BatteryManager] Emergency ACTIVATED — Battery: \(Int(currentBatteryLevel * 100))%")
        print("[BatteryManager] Pulse interval: \(isPulseBoosted ? boostedPulseInterval : normalPulseInterval)s")
    }
    
    /// Call when the emergency is resolved or cancelled.
    func deactivateEmergencyMode() {
        isEmergencyActive = false
        isPulseSlowed = false
        sosPayload = nil
        
        pulseTimer?.invalidate()
        pulseTimer = nil
        batteryMonitorTimer?.invalidate()
        batteryMonitorTimer = nil
        
        print("[BatteryManager] Emergency DEACTIVATED — pulse timer stopped")
    }
    
    /// Returns the current recommended pulse interval based on battery + emergency state.
    var currentPulseInterval: TimeInterval {
        if isEmergencyActive && isBatteryLow {
            return lowBatteryPulseInterval  // 50s — 10x slower to save battery
        }
        return normalPulseInterval          // 5.0s — normal
    }
    
    /// Returns a human-readable status for debugging/UI
    var statusDescription: String {
        let batteryPct = Int(currentBatteryLevel * 100)
        if !isEmergencyActive {
            return "Standby | Battery: \(batteryPct)%"
        }
        if isPulseSlowed {
            return "EMERGENCY | Battery: \(batteryPct)% | Pulse: POWER SAVE (\(lowBatteryPulseInterval)s)"
        }
        return "EMERGENCY | Battery: \(batteryPct)% | Pulse: Normal (\(normalPulseInterval)s)"
    }
    
    // MARK: - Private
    
    private func evaluateAndSetPulseRate() {
        guard isEmergencyActive else { return }
        
        let shouldSlow = isBatteryLow
        
        if shouldSlow != isPulseSlowed {
            isPulseSlowed = shouldSlow
            restartPulseTimer()
            
            if shouldSlow {
                print("[BatteryManager] LOW BATTERY — BLE pulse SLOWED to 10x (\(lowBatteryPulseInterval)s) to conserve power")
                
                NotificationCenter.default.post(
                    name: NSNotification.Name("BLEPulseRateChanged"),
                    object: nil,
                    userInfo: [
                        "interval": lowBatteryPulseInterval,
                        "slowed": true,
                        "batteryLevel": currentBatteryLevel
                    ]
                )
            } else {
                print("[BatteryManager] Battery OK — BLE pulse at normal rate (\(normalPulseInterval)s)")
                
                NotificationCenter.default.post(
                    name: NSNotification.Name("BLEPulseRateChanged"),
                    object: nil,
                    userInfo: [
                        "interval": normalPulseInterval,
                        "slowed": false,
                        "batteryLevel": currentBatteryLevel
                    ]
                )
            }
        }
    }
    
    private func restartPulseTimer() {
        pulseTimer?.invalidate()
        
        guard isEmergencyActive, let payload = sosPayload else { return }
        
        let interval = isPulseSlowed ? lowBatteryPulseInterval : normalPulseInterval
        
        pulseTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self, self.isEmergencyActive else { return }
            
            // Re-broadcast the SOS payload at the boosted rate
            NotificationCenter.default.post(
                name: NSNotification.Name("BatteryManagerSOSRetransmit"),
                object: nil,
                userInfo: ["payload": payload]
            )
            
            print("[BatteryManager] SOS pulse sent (interval: \(interval)s, battery: \(Int(self.currentBatteryLevel * 100))%)")
        }
    }
    
    private func startBatteryMonitoring() {
        batteryMonitorTimer?.invalidate()
        
        // Check battery every 10 seconds during emergency
        batteryMonitorTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.refreshBatteryLevel()
        }
    }
    
    private func refreshBatteryLevel() {
        #if os(iOS)
        let newLevel = UIDevice.current.batteryLevel
        guard newLevel >= 0 else { return }
        
        currentBatteryLevel = newLevel
        let wasLow = isBatteryLow
        isBatteryLow = newLevel < criticalBatteryThreshold
        
        // Re-evaluate pulse rate if battery state changed
        if wasLow != isBatteryLow {
            print("[BatteryManager] Battery state changed: \(Int(newLevel * 100))% — Low: \(isBatteryLow)")
            evaluateAndSetPulseRate()
        }
        #endif
    }
    
    @objc private func batteryLevelChanged() {
        refreshBatteryLevel()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        pulseTimer?.invalidate()
        batteryMonitorTimer?.invalidate()
    }
}
