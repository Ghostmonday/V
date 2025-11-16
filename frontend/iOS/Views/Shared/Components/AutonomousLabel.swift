import SwiftUI

/// Autonomous Label
/// Label component that automatically smooths based on emotional curves and dropoffs
struct AutonomousLabel: View {
    let componentId: String
    let defaultText: String
    // @Environment(\.autonomyCoordinator) var coordinator // TODO: Add autonomy coordinator environment
    
    @State private var displayText: String
    @State private var isSmooth: Bool = false
    
    init(componentId: String, text: String) {
        self.componentId = componentId
        self.defaultText = text
        self._displayText = State(initialValue: text)
    }
    
    var body: some View {
        Text(displayText)
            .foregroundColor(isSmooth ? .secondary : .primary)
            .animation(.easeInOut, value: displayText)
            .onAppear {
                checkForSmoothing()
            }
            // TODO: Re-enable when ViewModification notifications are available
            // .onReceive(NotificationCenter.default.publisher(for: .viewModificationApplied)) { notification in
            //     if let mod = notification.object as? ViewModification,
            //        mod.componentId == componentId,
            //        mod.type == .labelChange,
            //        let newText = mod.value as? String {
            //         displayText = newText
            //         isSmooth = true
            //     }
            // }
            // .onReceive(NotificationCenter.default.publisher(for: .viewModificationRolledBack)) { notification in
            //     if let checkpoint = notification.object as? RollbackCheckpoint,
            //        checkpoint.componentId == componentId {
            //         displayText = defaultText
            //         isSmooth = false
            //     }
            // }
    }
    
    private func checkForSmoothing() {
        // Check if label should be smoothed based on emotional state
        // TODO: Re-enable when autonomy coordinator is available
        // if coordinator.emotionalMonitor.emotionalState.trend == .negative {
        //     smoothLabel()
        // }
    }
    
    private func smoothLabel() {
        // Smooth the label text
        let smoothed = smoothText(defaultText)
        displayText = smoothed
        isSmooth = true
        
        // Apply modification
        // TODO: Re-enable when autonomy coordinator is available
        // let modification = ViewModification(
        //     componentId: componentId,
        //     type: .labelChange,
        //     value: smoothed
        // )
        //
        // Task { @MainActor in
        //     await coordinator.viewGenerator.applyModification(modification)
        // }
    }
    
    private func smoothText(_ text: String) -> String {
        // Simple text smoothing
        var smoothed = text.lowercased()
        
        let harshReplacements: [String: String] = [
            "error": "please check",
            "invalid": "needs attention",
            "wrong": "incorrect",
            "failed": "didn't work",
            "rejected": "not accepted"
        ]
        
        for (harsh, smooth) in harshReplacements {
            smoothed = smoothed.replacingOccurrences(of: harsh, with: smooth)
        }
        
        return smoothed.capitalized
    }
}

