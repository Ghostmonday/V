import Foundation
import SwiftUI

/// View Generator
/// Generates SwiftUI views dynamically from pattern templates and recommendations
@MainActor
class ViewGenerator {
    
    /// Generate SwiftUI view from recommendation
    func generateView(for recommendation: WatchdogRecommendation) -> AnyView? {
        switch recommendation.action {
        case "improve_labels_and_validation":
            return generateImprovedValidationView(for: recommendation)
        case "show_draft_recovery_banner":
            return generateDraftRecoveryBanner()
        case "flag_for_ux_review":
            return generateUXReviewFlag()
        default:
            return nil
        }
    }
    
    /// Generate view modification from recommendation
    func generateModification(for recommendation: WatchdogRecommendation) -> ViewModification? {
        switch recommendation.action {
        case "improve_labels_and_validation":
            return ViewModification(
                componentId: recommendation.target,
                type: .labelChange,
                value: generateSmootherLabel(for: recommendation.target)
            )
        case "show_draft_recovery_banner":
            return ViewModification(
                componentId: "draft_banner",
                type: .visibilityChange,
                value: true
            )
        default:
            return nil
        }
    }
    
    /// Apply view modification
    func applyModification(_ modification: ViewModification) async {
        // Store modification in component registry
        ComponentRegistry.shared.applyModification(modification)
        
        // Notify views to update
        NotificationCenter.default.post(
            name: .viewModificationApplied,
            object: modification
        )
        
        print("[ViewGenerator] Applied modification: \(modification.componentId) - \(modification.type)")
    }
    
    // MARK: - View Generation Methods
    
    private func generateImprovedValidationView(for recommendation: WatchdogRecommendation) -> AnyView? {
        // Generate improved validation label view
        let improvedLabel = generateSmootherLabel(for: recommendation.target)
        
        return AnyView(
            Text(improvedLabel)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        )
    }
    
    private func generateDraftRecoveryBanner() -> AnyView? {
        return AnyView(
            HStack {
                Image(systemName: "doc.text")
                Text("Draft saved. Tap to recover.")
                    .font(.caption)
                Spacer()
                Button("Recover") {
                    // Recover draft
                }
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
        )
    }
    
    private func generateUXReviewFlag() -> AnyView? {
        return AnyView(
            HStack {
                Image(systemName: "exclamationmark.triangle")
                Text("UX review recommended")
                    .font(.caption)
            }
            .foregroundColor(.orange)
        )
    }
    
    private func generateSmootherLabel(for componentId: String) -> String {
        // Generate smoother, more friendly label
        let harshLabels: [String: String] = [
            "validation_labels": "Please check this field",
            "email_input": "We'll use this to contact you",
            "password_input": "Choose something secure",
            "message_input": "What's on your mind?"
        ]
        
        return harshLabels[componentId] ?? "Please check this"
    }
}

// MARK: - Component Registry

class ComponentRegistry {
    static let shared = ComponentRegistry()
    
    private var modifications: [String: ViewModification] = [:]
    
    func applyModification(_ modification: ViewModification) {
        modifications[modification.componentId] = modification
    }
    
    func getModification(for componentId: String) -> ViewModification? {
        return modifications[componentId]
    }
    
    func clearModification(for componentId: String) {
        modifications.removeValue(forKey: componentId)
    }
}

extension Notification.Name {
    static let viewModificationApplied = Notification.Name("viewModificationApplied")
}

