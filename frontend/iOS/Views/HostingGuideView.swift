import SwiftUI

/// Hosting guide - pulls from docs/SELF-HOSTING.md
struct HostingGuideView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Self-Hosting Guide")
                    .font(.system(.largeTitle, weight: .bold))
                    .padding(.top)
                
                GuideSection(
                    title: "Quick Start",
                    content: "Use our Terraform configs in infra/aws/ for one-click AWS deployment."
                )
                
                GuideSection(
                    title: "Docker",
                    content: "docker-compose up -d for local testing."
                )
                
                GuideSection(
                    title: "Enterprise",
                    content: "Full control, GDPR compliance, custom retention policies."
                )
                
                GuideSection(
                    title: "Run Once, Own Forever",
                    content: "No servers from us, no third-party mess. Just freedom."
                )
                
                // Code block example
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quick Deploy:")
                        .font(.headline)
                    
                    Text("cd infra/aws\nterraform init\nterraform apply")
                        .font(.system(.caption, design: .monospaced))
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(.ultraThinMaterial)
                        )
                }
                .padding(.vertical)
            }
            .padding()
        }
        .navigationTitle("Hosting Guide")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct GuideSection: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        HostingGuideView()
    }
}

