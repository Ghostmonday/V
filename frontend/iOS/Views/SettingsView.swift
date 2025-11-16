import SwiftUI

/// Settings with hosting options
struct SettingsView: View {
    @State private var aiOn = false
    @State private var isEnterprise = false // TODO: Check subscription
    @State private var haptic = UIImpactFeedbackGenerator(style: .light)
    
    var body: some View {
        NavigationStack {
            List {
                Section("Rooms") {
                    Toggle("AI Moderation", isOn: $aiOn)
                        .disabled(!isEnterprise)
                        .font(.body) // Dynamic Type support
                        .onChange(of: aiOn) { _ in
                            haptic.impactOccurred()
                        }
                        .accessibleToggle("AI Moderation", isOn: aiOn, hint: isEnterprise ? "Enable AI content moderation" : "Available in enterprise rooms only")
                    
                    if !isEnterprise {
                        Text("Only in enterprise rooms.")
                            .foregroundColor(.secondary)
                            .font(.caption)
                            .accessibilityLabel("AI Moderation is only available in enterprise rooms")
                    }
                }
                
                Section("Performance") {
                    Toggle("Low-bandwidth mode", isOn: Binding(
                        get: { UserSettings.shared.lowBandwidth },
                        set: { UserSettings.shared.lowBandwidth = $0 }
                    ))
                    .font(.body) // Dynamic Type support
                    .onChange(of: UserSettings.shared.lowBandwidth) { _, newValue in
                        haptic.impactOccurred()
                        Task {
                            await updateBandwidthPreference(newValue)
                        }
                    }
                    .accessibleToggle("Low-bandwidth mode", isOn: UserSettings.shared.lowBandwidth, hint: "Reduce data usage by downsampling media")
                    
                    Text("Reduces data usage by downsampling images and videos")
                        .foregroundColor(.secondary)
                        .font(.caption)
                        .accessibilityLabel("Low-bandwidth mode reduces data usage")
                }
                
                Section("Nicknames") {
                    NavigationLink("Manage Nicknames", destination: NicknameManagementView())
                        .font(.body)
                        .accessibilityLabel("Manage nicknames")
                        .accessibilityHint("Set custom names for yourself in different rooms")
                }
                
                Section("Hosting") {
                    Button("Export Config") {
                        haptic.impactOccurred()
                        shareJSON()
                    }
                    .disabled(!isEnterprise)
                    
                    Button("Launch on AWS") {
                        haptic.impactOccurred()
                        openTerraformRun()
                    }
                    .disabled(!isEnterprise)
                    
                    NavigationLink("Hosting Guide", destination: HostingGuideView())
                    
                    Text("Self-host with our Docker image - no lock-in.")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                
                Section("Account") {
                    NavigationLink("Subscription", destination: SubscriptionView())
                }
            }
            .navigationTitle("Settings")
        }
    }
    
    private func shareJSON() {
        // Generate Terraform config JSON
        let config: [String: Any] = [
            "room_schema": "rooms",
            "env_vars": [
                "NEXT_PUBLIC_SUPABASE_URL": "your-url",
                "REDIS_URL": "your-redis"
            ],
            "redis_creds": [
                "host": "your-host",
                "port": 6379
            ]
        ]
        
        // TODO: Convert to JSON and share via UIActivityViewController
        print("Exporting config: \(config)")
    }
    
    private func openTerraformRun() {
        // Open Terraform Cloud workspace
        if let url = URL(string: "https://app.terraform.io/runs/new/your-workspace") {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    SettingsView()
}
