import Foundation
import OSLog

/// Rollback Manager
/// Manages rollback checkpoints and rollback logic for failed UI changes
class RollbackManager {
    static let shared = RollbackManager()
    
    private var checkpoints: [RollbackCheckpoint] = []
    private let maxCheckpoints = 10
    
    // MARK: - Public API
    
    /// Create a rollback checkpoint before applying a modification
    func createCheckpoint(componentId: String, modification: ViewModification) -> RollbackCheckpoint {
        let checkpoint = RollbackCheckpoint(
            id: UUID().uuidString,
            componentId: componentId,
            modification: modification,
            timestamp: Date(),
            state: .active
        )
        
        checkpoints.append(checkpoint)
        
        // Limit checkpoint history
        if checkpoints.count > maxCheckpoints {
            checkpoints.removeFirst()
        }
        
        Logger(subsystem: "com.vibez.app", category: "RollbackManager").info("[RollbackManager] Created checkpoint: \(checkpoint.id) for \(componentId)")
        
        return checkpoint
    }
    
    /// Monitor checkpoint for rollback conditions
    func monitorCheckpoint(_ checkpoint: RollbackCheckpoint) {
        // Start monitoring in background
        Task {
            await monitorCheckpointAsync(checkpoint)
        }
    }
    
    /// Rollback to last stable state
    func rollbackToLastStableState() async {
        guard let lastCheckpoint = checkpoints.last else {
            Logger(subsystem: "com.vibez.app", category: "RollbackManager").info("[RollbackManager] No checkpoints to rollback")
            return
        }
        
        await rollbackCheckpoint(lastCheckpoint)
    }
    
    /// Rollback a specific experiment
    func rollbackExperiment(_ experimentId: String) async {
        // Find checkpoints related to this experiment
        let relatedCheckpoints = checkpoints.filter { checkpoint in
            checkpoint.modification.componentId.contains(experimentId)
        }
        
        for checkpoint in relatedCheckpoints {
            await rollbackCheckpoint(checkpoint)
        }
    }
    
    // MARK: - Private Methods
    
    private func monitorCheckpointAsync(_ checkpoint: RollbackCheckpoint) async {
        // Monitor for 5 minutes
        try? await Task.sleep(nanoseconds: 5 * 60 * 1_000_000_000)
        
        // Check if checkpoint should be rolled back
        if shouldRollback(checkpoint) {
            await rollbackCheckpoint(checkpoint)
        } else {
            // Mark as stable
            markCheckpointStable(checkpoint)
        }
    }
    
    private func shouldRollback(_ checkpoint: RollbackCheckpoint) -> Bool {
        // Check telemetry for negative indicators
        // This would query actual telemetry data
        // For now, use simple heuristics
        
        // Rollback if checkpoint is older than 1 hour and no positive signals
        let age = Date().timeIntervalSince(checkpoint.timestamp)
        if age > 3600 {
            return true
        }
        
        return false
    }
    
    private func rollbackCheckpoint(_ checkpoint: RollbackCheckpoint) async {
        Logger(subsystem: "com.vibez.app", category: "RollbackManager").info("[RollbackManager] Rolling back checkpoint: \(checkpoint.id)")
        
        // Revert modification
        ComponentRegistry.shared.clearModification(for: checkpoint.componentId)
        
        // Notify views to update
        NotificationCenter.default.post(
            name: .viewModificationRolledBack,
            object: checkpoint
        )
        
        // Mark checkpoint as rolled back
        markCheckpointRolledBack(checkpoint)
        
        // Log rollback
        Task { @MainActor in
            UXTelemetryService.shared.logEvent(
                eventType: .aiEditUndone,
                category: .aiFeedback,
                metadata: [
                    "checkpointId": checkpoint.id,
                    "componentId": checkpoint.componentId,
                    "reason": "rollback"
                ]
            )
        }
    }
    
    private func markCheckpointStable(_ checkpoint: RollbackCheckpoint) {
        if let index = checkpoints.firstIndex(where: { $0.id == checkpoint.id }) {
            var updated = checkpoint
            updated.state = .stable
            checkpoints[index] = updated
        }
    }
    
    private func markCheckpointRolledBack(_ checkpoint: RollbackCheckpoint) {
        if let index = checkpoints.firstIndex(where: { $0.id == checkpoint.id }) {
            var updated = checkpoint
            updated.state = .rolledBack
            checkpoints[index] = updated
        }
    }
}

// MARK: - Supporting Types

struct RollbackCheckpoint {
    let id: String
    let componentId: String
    let modification: ViewModification
    let timestamp: Date
    var state: CheckpointState
    
    enum CheckpointState {
        case active, stable, rolledBack
    }
}

extension Notification.Name {
    static let viewModificationRolledBack = Notification.Name("viewModificationRolledBack")
}

