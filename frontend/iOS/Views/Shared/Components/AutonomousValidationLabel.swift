import SwiftUI

/// Autonomous Validation Label
/// Validation label that automatically smooths based on emotional curves and dropoffs
struct AutonomousValidationLabel: View {
    let componentId: String
    let errorText: String?
    // @Environment(\.autonomyCoordinator) var coordinator // TODO: Add autonomy coordinator environment
    
    @State private var displayText: String?
    @State private var isSmooth: Bool = false
    
    init(componentId: String, errorText: String?) {
        self.componentId = componentId
        self.errorText = errorText
    }
    
    var body: some View {
        if let text = displayText ?? errorText {
            Text(text)
                .font(.caption)
                .foregroundColor(isSmooth ? .secondary : .red)
                .animation(.easeInOut, value: displayText)
                .onAppear {
                    if let error = errorText {
                        checkForSmoothing(error: error)
                    }
                }
                .onChange(of: errorText) { oldValue, newError in
                    if let error = newError {
                        checkForSmoothing(error: error)
                    } else {
                        displayText = nil
                    }
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
                //         displayText = errorText
                //         isSmooth = false
                //     }
                // }
        }
    }
    
    private func checkForSmoothing(error: String) {
        // Check if label should be smoothed based on emotional state or dropoff
        // TODO: Re-enable when autonomy coordinator is available
        // let shouldSmooth = coordinator.emotionalMonitor.emotionalState.trend == .negative ||
        //                   coordinator.executor.lastDropoffPoint?.rate ?? 0 > 0.3
        
        // For now, just display the error
        displayText = error
        isSmooth = false
    }
    
    private func smoothLabel(error: String) {
        // Smooth the error text
        let smoothed = smoothErrorText(error)
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
        
        // Log validation irritation if repeated
        logValidationIrritation()
    }
    
    private func smoothErrorText(_ text: String) -> String {
        // Smooth error messages
        var smoothed = text.lowercased()
        
        let harshReplacements: [String: String] = [
            "error": "please check",
            "invalid": "needs attention",
            "wrong": "incorrect",
            "failed": "didn't work",
            "required": "this is required",
            "must be": "should be",
            "cannot": "can't"
        ]
        
        for (harsh, smooth) in harshReplacements {
            smoothed = smoothed.replacingOccurrences(of: harsh, with: smooth)
        }
        
        return smoothed.capitalized
    }
    
    private func logValidationIrritation() {
        // Track validation errors for irritation score
        // This would track consecutive errors
        UXTelemetryService.logValidationError(
            componentId: componentId,
            errorType: "validation",
            metadata: ["smoothed": isSmooth]
        )
    }
}

