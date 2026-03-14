import SwiftUI
#if os(iOS)
import AudioToolbox
#endif

/// Full-screen SOS countdown overlay.
/// Shows when a crash is detected or manual SOS is triggered.
/// User can cancel within the countdown or let it auto-send.
struct SOSCountdownOverlay: View {
    @ObservedObject var sensor = EmergencySensorService.shared
    
    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.85)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                if sensor.sosSent {
                    // SOS has been sent
                    sosSentView
                } else {
                    // Countdown in progress
                    countdownView
                }
            }
            .padding(32)
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.3), value: sensor.isCountdownActive)
        .animation(.easeInOut(duration: 0.3), value: sensor.sosSent)
    }
    
    // MARK: - Countdown View
    
    private var countdownView: some View {
        VStack(spacing: 20) {
            // Pulsing warning icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 70))
                .foregroundColor(.red)
                .shadow(color: .red.opacity(0.6), radius: 20)
            
            Text(sensor.activeEmergencyType == .crash ? "CRASH DETECTED" : "SOS ACTIVATED")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundColor(.white)
            
            Text("Emergency SOS will be sent in")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
            
            // Big countdown number
            Text("\(sensor.countdownSeconds)")
                .font(.system(size: 100, weight: .black, design: .rounded))
                .foregroundColor(.red)
                .shadow(color: .red.opacity(0.5), radius: 15)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.3), value: sensor.countdownSeconds)
            
            Text("seconds")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
            
            Spacer().frame(height: 20)
            
            // Cancel button
            Button(action: {
                sensor.cancelCountdown()
            }) {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                    Text("I'M OK — CANCEL SOS")
                        .font(.system(size: 18, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.green)
                .cornerRadius(16)
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - SOS Sent View
    
    private var sosSentView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 70))
                .foregroundColor(.green)
            
            Text("SOS SENT!")
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundColor(.white)
            
            Text("Your location has been broadcast\nto nearby devices via mesh network")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
            
            HStack(spacing: 12) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundColor(.green)
                Text("Broadcasting via Bluetooth Mesh...")
                    .foregroundColor(.white.opacity(0.7))
            }
            .font(.system(size: 14))
            .padding(.top, 8)
        }
    }
}

/// A prominent "Force SOS" button for use inside the app (demo purposes)
struct ForceSOSButton: View {
    @ObservedObject var sensor = EmergencySensorService.shared
    
    var body: some View {
        Button(action: {
            sensor.forceTriggerSOS()
        }) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.trianglebadge.exclamationmark.fill")
                    .font(.system(size: 16))
                Text("FORCE SOS")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                LinearGradient(
                    colors: [Color.red, Color.orange],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(20)
            .shadow(color: .red.opacity(0.4), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }
}
