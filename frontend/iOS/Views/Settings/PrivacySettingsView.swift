import SwiftUI

struct PrivacySettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var disappearingMessages = false
    
    var body: some View {
        ZStack {
            VibezBackground()
            
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "arrow.left")
                            .foregroundColor(Color.Vibez.textPrimary)
                            .font(.system(size: 20))
                    }
                    Text("Privacy Control Center")
                        .vibezHeaderMedium()
                        .padding(.leading, 8)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 20)
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Status Card
                        GlassCard {
                            HStack {
                                Image(systemName: "shield.check.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(Color.Vibez.success)
                                VStack(alignment: .leading) {
                                    Text("Privacy Shield Active")
                                        .font(VibezTypography.bodyLarge)
                                        .foregroundColor(Color.Vibez.textPrimary)
                                    Text("Your data is local-first and encrypted.")
                                        .font(VibezTypography.caption)
                                        .foregroundColor(Color.Vibez.textSecondary)
                                }
                                Spacer()
                            }
                        }
                        
                        // Chat Privacy
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Chat Security")
                                .vibezHeaderSmall()
                            
                            PrivacyToggleRow(
                                title: "Disappearing Messages",
                                description: "Auto-delete messages after 24 hours.",
                                isOn: $disappearingMessages
                            )
                        }
                        
                        // Toggles
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Data Permissions")
                                .vibezHeaderSmall()
                            
                            PrivacyToggleRow(
                                title: "Crash Reporting",
                                description: "Send anonymous logs to help fix bugs.",
                                isOn: $appState.allowCrashReporting
                            )
                            
                            PrivacyToggleRow(
                                title: "Discoverability",
                                description: "Allow others to find you by handle.",
                                isOn: $appState.allowDiscoverability
                            )
                            
                            PrivacyToggleRow(
                                title: "Usage Analytics",
                                description: "Share anonymous usage stats.",
                                isOn: $appState.allowUsageAnalytics
                            )
                        }
                        
                        // Danger Zone
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Data Management")
                                .vibezHeaderSmall()
                            
                            Button(action: {
                                // Action to export data
                            }) {
                                GlassCard {
                                    HStack {
                                        Text("Export My Data")
                                            .foregroundColor(Color.Vibez.textPrimary)
                                        Spacer()
                                        Image(systemName: "square.and.arrow.up")
                                            .foregroundColor(Color.Vibez.textSecondary)
                                    }
                                }
                            }
                            
                            Button(action: {
                                // Action to delete account
                            }) {
                                GlassCard {
                                    HStack {
                                        Text("Delete Account & Data")
                                            .foregroundColor(Color.Vibez.error)
                                        Spacer()
                                        Image(systemName: "trash")
                                            .foregroundColor(Color.Vibez.error)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationBarHidden(true)
    }
}
