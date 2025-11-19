import SwiftUI

struct SelfHostSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var serverURL: String = ""
    @State private var isConnecting = false
    @State private var connectionStatus: ConnectionStatus = .disconnected
    
    enum ConnectionStatus {
        case disconnected
        case connecting
        case connected
        case error
    }
    
    var body: some View {
        ZStack {
            VibezBackground()
            
            VStack(spacing: 24) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "arrow.left")
                            .foregroundColor(Color.Vibez.textPrimary)
                            .font(.system(size: 20))
                    }
                    Text("Self-Hosted Node")
                        .vibezHeaderMedium()
                        .padding(.leading, 8)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 20)
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Info Card
                        GlassCard {
                            HStack(alignment: .top, spacing: 16) {
                                Image(systemName: "server.rack")
                                    .font(.system(size: 30))
                                    .foregroundColor(Color.Vibez.electricBlue)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Run Your Own Cloud")
                                        .font(VibezTypography.headerSmall)
                                        .foregroundColor(Color.Vibez.textPrimary)
                                    
                                    Text("Connect to a personal VIBEZ Node for complete data sovereignty. No third-party servers involved.")
                                        .font(VibezTypography.bodyMedium)
                                        .foregroundColor(Color.Vibez.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        
                        // Connection Input
                        VStack(alignment: .leading, spacing: 16) {
                            Text("CONNECTION DETAILS")
                                .font(VibezTypography.caption)
                                .foregroundColor(Color.Vibez.textSecondary)
                                .padding(.leading, 4)
                            
                            VStack(spacing: 0) {
                                HStack {
                                    Image(systemName: "globe")
                                        .foregroundColor(Color.Vibez.textSecondary)
                                    TextField("https://vibez.example.com", text: $serverURL)
                                        .foregroundColor(Color.Vibez.textPrimary)
                                        .autocapitalization(.none)
                                        .disableAutocorrection(true)
                                }
                                .padding()
                                .background(Color.Vibez.deepVoid.opacity(0.5))
                                
                                Divider().background(Color.white.opacity(0.1))
                                
                                Button(action: {
                                    // Scan QR Code logic would go here
                                }) {
                                    HStack {
                                        Image(systemName: "qrcode.viewfinder")
                                        Text("Scan QR Code")
                                    }
                                    .foregroundColor(Color.Vibez.electricBlue)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                }
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.Vibez.deepVoid.opacity(0.5))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                            )
                        }
                        
                        // Action Button
                        Button(action: connectToServer) {
                            HStack {
                                if isConnecting {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text(connectionStatus == .connected ? "Connected" : "Connect to Node")
                                        .font(VibezTypography.button)
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                connectionStatus == .connected ? Color.Vibez.success : Color.Vibez.electricBlue
                            )
                            .cornerRadius(16)
                            .shadow(color: connectionStatus == .connected ? Color.Vibez.success.opacity(0.3) : Color.Vibez.electricBlue.opacity(0.3), radius: 10)
                        }
                        .disabled(serverURL.isEmpty || isConnecting)
                        
                        if connectionStatus == .error {
                            Text("Could not connect to server. Please check the URL.")
                                .font(VibezTypography.caption)
                                .foregroundColor(Color.Vibez.error)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationBarHidden(true)
    }
    
    private func connectToServer() {
        isConnecting = true
        connectionStatus = .connecting
        
        // Simulate connection check
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isConnecting = false
            if !serverURL.isEmpty {
                connectionStatus = .connected
            } else {
                connectionStatus = .error
            }
        }
    }
}

