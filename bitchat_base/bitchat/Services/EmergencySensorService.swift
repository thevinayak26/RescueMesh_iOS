import Foundation
import CoreMotion
import Combine
import AVFoundation
#if os(iOS)
import UIKit
import AudioToolbox
#endif

/// A protocol for the Emergency Sensor Service.
public protocol EmergencySensorServiceProtocol {
    var emergencyEventPublisher: AnyPublisher<EmergencyType, Never> { get }
    func startMonitoring()
    func stopMonitoring()
    func triggerManualSOS()
}

public enum EmergencyType: String, Codable {
    case manual = "manual"
    case crash = "crash"
}

/// A service responsible for detecting emergencies using CoreMotion and manual triggers.
/// Includes alarm sound, countdown, and automatic SOS broadcast.
public final class EmergencySensorService: ObservableObject, EmergencySensorServiceProtocol {
    public static let shared = EmergencySensorService()
    
    private let motionManager = CMMotionManager()
    private let emergencyEventSubject = PassthroughSubject<EmergencyType, Never>()
    
    public var emergencyEventPublisher: AnyPublisher<EmergencyType, Never> {
        emergencyEventSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Published State for UI
    
    /// Whether the SOS countdown overlay should be shown
    @Published public var isCountdownActive: Bool = false
    /// Seconds remaining in the countdown
    @Published public var countdownSeconds: Int = 10
    /// Whether an SOS has been confirmed and sent
    @Published public var sosSent: Bool = false
    /// The type of emergency that triggered the countdown
    @Published public var activeEmergencyType: EmergencyType? = nil
    
    // MARK: - Configuration
    
    /// Drop detection threshold in g-force.
    /// A phone dropped ~1m onto a soft bag typically registers 2.0-3.0g on impact.
    /// Set to 2.2g for reliable bag-drop detection during demo.
    public var crashAccelerationThreshold: Double = 2.2
    
    /// Countdown duration in seconds before SOS is auto-sent
    public var countdownDuration: Int = 10
    
    // MARK: - Private State
    
    private var countdownTimer: Timer?
    private var alarmPlayer: AVAudioPlayer?
    private var isCooldown: Bool = false // Prevent rapid re-triggers
    
    private init() {}
    
    // MARK: - Monitoring
    
    public func startMonitoring() {
        #if os(iOS)
        guard motionManager.isAccelerometerAvailable else {
            print("⚠️ Accelerometer not available. Crash detection disabled.")
            return
        }
        
        guard !motionManager.isAccelerometerActive else {
            print("ℹ️ Accelerometer already active.")
            return
        }
        
        motionManager.accelerometerUpdateInterval = 1.0 / 50.0 // 50 Hz for better accuracy
        motionManager.startAccelerometerUpdates(to: OperationQueue()) { [weak self] (data, error) in
            guard let self = self, let data = data, error == nil else { return }
            
            // Calculate magnitude of acceleration vector
            let magnitude = sqrt(
                data.acceleration.x * data.acceleration.x +
                data.acceleration.y * data.acceleration.y +
                data.acceleration.z * data.acceleration.z
            )
            
            // Normal gravity = ~1.0g. A drop impact = sharp spike above threshold.
            if magnitude > self.crashAccelerationThreshold && !self.isCooldown && !self.isCountdownActive {
                DispatchQueue.main.async {
                    self.handleCrashDetected()
                }
            }
        }
        print("✅ Crash detection monitoring started (threshold: \(crashAccelerationThreshold)g)")
        #endif
    }
    
    public func stopMonitoring() {
        if motionManager.isAccelerometerActive {
            motionManager.stopAccelerometerUpdates()
            print("⏹ Crash detection monitoring stopped")
        }
    }
    
    // MARK: - Manual SOS (Button Press)
    
    public func triggerManualSOS() {
        print("🆘 Manual SOS Triggered!")
        DispatchQueue.main.async {
            self.activeEmergencyType = .manual
            self.startCountdown()
        }
    }
    
    // MARK: - Force Trigger (Demo Button — skips countdown)
    
    /// Force-triggers an immediate SOS with no countdown. Use for demo purposes.
    public func forceTriggerSOS() {
        print("⚡ FORCE SOS — Skipping countdown, sending immediately!")
        DispatchQueue.main.async {
            self.activeEmergencyType = .manual
            self.sosSent = true
            self.isCountdownActive = false
            self.playAlarmSound()
            
            // Heavy vibration burst
            #if os(iOS)
            let heavy = UIImpactFeedbackGenerator(style: .heavy)
            heavy.prepare()
            heavy.impactOccurred()
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            // Triple vibrate
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { AudioServicesPlaySystemSound(kSystemSoundID_Vibrate) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { AudioServicesPlaySystemSound(kSystemSoundID_Vibrate) }
            #endif
            
            // Fire local notification
            NotificationService.shared.sendLocalNotification(
                title: "🚨 EMERGENCY SOS ACTIVATED",
                body: "SOS has been force-triggered. Broadcasting your location via mesh network.",
                identifier: "sos-force-\(UUID().uuidString)",
                interruptionLevel: .critical
            )
            
            // Send immediately
            self.emergencyEventSubject.send(.manual)
            
            // Reset after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                self.sosSent = false
                self.activeEmergencyType = nil
                self.stopAlarmSound()
            }
        }
    }
    
    // MARK: - Crash Detection Handler
    
    private func handleCrashDetected() {
        guard !isCooldown && !isCountdownActive else { return }
        
        print("💥 CRASH DETECTED! Acceleration exceeded \(crashAccelerationThreshold)g")
        
        // Set cooldown to prevent rapid re-triggers
        isCooldown = true
        
        activeEmergencyType = .crash
        startCountdown()
        
        // Heavy haptic burst + vibrate
        #if os(iOS)
        let heavy = UIImpactFeedbackGenerator(style: .heavy)
        heavy.prepare()
        heavy.impactOccurred()
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        // Double vibrate for emphasis
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
        #endif
        
        // Fire local notification immediately (visible even if app is in background)
        NotificationService.shared.sendLocalNotification(
            title: "💥 CRASH DETECTED",
            body: "Impact detected! SOS will be sent in \(countdownDuration) seconds. Open app to cancel.",
            identifier: "crash-detect-\(UUID().uuidString)",
            interruptionLevel: .critical
        )
    }
    
    // MARK: - Countdown System
    
    private func startCountdown() {
        // Cancel any existing countdown
        cancelCountdown()
        
        countdownSeconds = countdownDuration
        isCountdownActive = true
        sosSent = false
        
        // Start alarm
        playAlarmSound()
        
        print("⏱ SOS Countdown started: \(countdownDuration) seconds")
        
        // Countdown timer — fires every second
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            
            DispatchQueue.main.async {
                self.countdownSeconds -= 1
                
                // Strong vibration every second — triple pulse pattern
                #if os(iOS)
                let heavy = UIImpactFeedbackGenerator(style: .heavy)
                heavy.prepare()
                heavy.impactOccurred()
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
                // Second pulse after 150ms
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    let medium = UIImpactFeedbackGenerator(style: .medium)
                    medium.impactOccurred()
                }
                // Third pulse after 300ms
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    let rigid = UIImpactFeedbackGenerator(style: .rigid)
                    rigid.impactOccurred()
                }
                #endif
                
                if self.countdownSeconds <= 0 {
                    // Time's up — send SOS!
                    self.confirmSOS()
                }
            }
        }
    }
    
    /// User cancelled the SOS during countdown
    public func cancelCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        isCountdownActive = false
        countdownSeconds = countdownDuration
        sosSent = false
        activeEmergencyType = nil
        stopAlarmSound()
        
        // Release cooldown after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.isCooldown = false
        }
        
        print("❌ SOS Cancelled by user")
    }
    
    /// Countdown reached zero — confirm and broadcast SOS
    private func confirmSOS() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        isCountdownActive = false
        sosSent = true
        
        let type = activeEmergencyType ?? .manual
        
        print("🚨🚨🚨 SOS CONFIRMED — Broadcasting \(type.rawValue) emergency!")
        
        // Heavy confirmation haptic
        #if os(iOS)
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.error)
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        #endif
        
        // Fire a local notification confirming SOS was sent
        NotificationService.shared.sendLocalNotification(
            title: "🚨 SOS SENT",
            body: "Emergency SOS has been broadcast to nearby devices via Bluetooth mesh.",
            identifier: "sos-confirmed-\(UUID().uuidString)",
            interruptionLevel: .critical
        )
        
        // Send the event to the pipeline
        emergencyEventSubject.send(type)
        
        // Keep alarm going for 3 more seconds, then stop
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.stopAlarmSound()
        }
        
        // Reset state after 8 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) { [weak self] in
            self?.sosSent = false
            self?.activeEmergencyType = nil
            self?.isCooldown = false
        }
    }
    
    // MARK: - Alarm Sound
    
    private func playAlarmSound() {
        #if os(iOS)
        // Use system alarm sound — no audio file needed
        // Play the SOS tone repeatedly
        AudioServicesPlayAlertSound(SystemSoundID(1005)) // Alarm sound
        
        // Also set up repeating vibration + sound
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self, (self.isCountdownActive || self.sosSent) else { return }
            AudioServicesPlayAlertSound(SystemSoundID(1005))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self, (self.isCountdownActive || self.sosSent) else { return }
            AudioServicesPlayAlertSound(SystemSoundID(1005))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            guard let self = self, (self.isCountdownActive || self.sosSent) else { return }
            self.playAlarmSound() // Loop
        }
        #endif
    }
    
    private func stopAlarmSound() {
        alarmPlayer?.stop()
        alarmPlayer = nil
    }
}
