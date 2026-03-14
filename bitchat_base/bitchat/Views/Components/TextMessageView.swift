//
// TextMessageView.swift
// bitchat
//
// This is free and unencumbered software released into the public domain.
// For more information, see <https://unlicense.org>
//

import SwiftUI
import MapKit

struct TextMessageView: View {
    @Environment(\.colorScheme) private var colorScheme: ColorScheme
    @EnvironmentObject private var viewModel: ChatViewModel
    
    let message: BitchatMessage
    @Binding var expandedMessageIDs: Set<String>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Precompute heavy token scans once per row
            let cashuLinks = message.content.extractCashuLinks()
            let lightningLinks = message.content.extractLightningLinks()
            HStack(alignment: .top, spacing: 0) {
                let isLong = (message.content.count > TransportConfig.uiLongMessageLengthThreshold || message.content.hasVeryLongToken(threshold: TransportConfig.uiVeryLongTokenThreshold)) && cashuLinks.isEmpty
                let isExpanded = expandedMessageIDs.contains(message.id)
                
                if message.content.hasPrefix("EMERGENCY_SOS") {
                    // Custom Emergency SOS UI
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.white)
                            Text("EMERGENCY: SOS")
                                .font(.bitchatSystem(size: 14, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        
                        if let packet = EmergencyPacket.decodeFromPayload(message.content) {
                            Text("Type: \(packet.emergencyType.rawValue.capitalized)")
                                .font(.bitchatSystem(size: 12))
                                .foregroundColor(.white)
                            Text("Location: \(String(format: "%.4f", packet.latitude)), \(String(format: "%.4f", packet.longitude))")
                                .font(.bitchatSystem(size: 12))
                                .foregroundColor(.white)
                            if packet.batteryLevel >= 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: packet.batteryLevel > 50 ? "battery.75percent" : (packet.batteryLevel > 20 ? "battery.25percent" : "battery.0percent"))
                                        .foregroundColor(packet.batteryLevel > 20 ? .white : .yellow)
                                    Text("Battery: \(packet.batteryLevel)%")
                                        .font(.bitchatSystem(size: 12))
                                        .foregroundColor(.white)
                                }
                            }
                            HStack(spacing: 4) {
                                Image(systemName: "phone.fill")
                                    .foregroundColor(.white)
                                    .font(.system(size: 10))
                                Text("Contact: +91 98765 43210")
                                    .font(.bitchatSystem(size: 12))
                                    .foregroundColor(.white)
                            }
                            HStack(spacing: 4) {
                                Image(systemName: "person.2.fill")
                                    .foregroundColor(.white)
                                    .font(.system(size: 10))
                                Text("Family: +91 91234 56789")
                                    .font(.bitchatSystem(size: 12))
                                    .foregroundColor(.white)
                            }
                            HStack(spacing: 4) {
                                Image(systemName: "cross.case.fill")
                                    .foregroundColor(.white)
                                    .font(.system(size: 10))
                                Text("Blood Group: B+")
                                    .font(.bitchatSystem(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            
                            HStack {
                                Button(action: {
                                    let coordinate = CLLocationCoordinate2D(latitude: packet.latitude, longitude: packet.longitude)
                                    let placemark = MKPlacemark(coordinate: coordinate)
                                    let mapItem = MKMapItem(placemark: placemark)
                                    mapItem.name = "SOS Location"
                                    mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
                                }) {
                                    Label("Navigate to Victim", systemImage: "location.fill")
                                        .font(.bitchatSystem(size: 12, weight: .bold))
                                        .padding(6)
                                        .background(Color.white)
                                        .foregroundColor(.red)
                                        .cornerRadius(6)
                                }
                                
                                Button(action: {
                                    if let phoneCallURL = URL(string: "tel://112") {
                                        UIApplication.shared.open(phoneCallURL)
                                    }
                                }) {
                                    Label("Call 112", systemImage: "phone.fill")
                                        .font(.bitchatSystem(size: 12, weight: .bold))
                                        .padding(6)
                                        .background(Color.white)
                                        .foregroundColor(.red)
                                        .cornerRadius(6)
                                }
                            }
                            .padding(.top, 4)
                        } else {
                            Text("SOS signal received. Awaiting location data...")
                                .font(.bitchatSystem(size: 12))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(12)
                    .background(Color.red)
                    .cornerRadius(12)
                    .shadow(radius: 4)
                } else {
                    Text(viewModel.formatMessageAsText(message, colorScheme: colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(isLong && !isExpanded ? TransportConfig.uiLongMessageLineLimit : nil)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Delivery status indicator for private messages
                if message.isPrivate && message.sender == viewModel.nickname,
                   let status = message.deliveryStatus {
                    DeliveryStatusView(status: status)
                        .padding(.leading, 4)
                }
            }
            
            // Expand/Collapse for very long messages
            if (message.content.count > TransportConfig.uiLongMessageLengthThreshold || message.content.hasVeryLongToken(threshold: TransportConfig.uiVeryLongTokenThreshold)) && cashuLinks.isEmpty {
                let isExpanded = expandedMessageIDs.contains(message.id)
                let labelKey = isExpanded ? LocalizedStringKey("content.message.show_less") : LocalizedStringKey("content.message.show_more")
                Button(labelKey) {
                    if isExpanded { expandedMessageIDs.remove(message.id) }
                    else { expandedMessageIDs.insert(message.id) }
                }
                .font(.bitchatSystem(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(Color.blue)
                .padding(.top, 4)
            }

            // Render payment chips (Lightning / Cashu) with rounded background
            if !lightningLinks.isEmpty || !cashuLinks.isEmpty {
                HStack(spacing: 8) {
                    ForEach(lightningLinks, id: \.self) { link in
                        PaymentChipView(paymentType: .lightning(link))
                    }
                    ForEach(cashuLinks, id: \.self) { link in
                        PaymentChipView(paymentType: .cashu(link))
                    }
                }
                .padding(.top, 6)
                .padding(.leading, 2)
            }
        }
    }
}

@available(macOS 14, iOS 17, *)
#Preview {
    @Previewable @State var ids: Set<String> = []
    let keychain = PreviewKeychainManager()
    
    Group {
        List {
            TextMessageView(message: .preview, expandedMessageIDs: $ids)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets())
                .listRowBackground(EmptyView())
        }
        .environment(\.colorScheme, .light)
        
        List {
            TextMessageView(message: .preview, expandedMessageIDs: $ids)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets())
                .listRowBackground(EmptyView())
        }
        .environment(\.colorScheme, .dark)
    }
    .environmentObject(
        ChatViewModel(
            keychain: keychain,
            idBridge: NostrIdentityBridge(),
            identityManager: SecureIdentityStateManager(keychain)
        )
    )
}
