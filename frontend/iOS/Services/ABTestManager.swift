import Foundation

/// A/B Test Manager
/// Manages A/B testing experiments, variant assignment, and conversion tracking
class ABTestManager {
    static let shared = ABTestManager()
    
    private var experiments: [String: ABTestExperiment] = [:]
    private var userVariants: [String: ABTestVariant] = [:]
    private let userDefaults = UserDefaults.standard
    
    // MARK: - Public API
    
    /// Start a new A/B test experiment
    func startExperiment(_ experiment: ABTestExperiment) {
        experiments[experiment.id] = experiment
        
        // Assign variant to user (persistent)
        let variant = assignVariant(for: experiment)
        userVariants[experiment.id] = variant
        
        print("[ABTestManager] Started experiment: \(experiment.id), assigned variant: \(variant)")
    }
    
    /// Get variant for a component
    func getVariant(for componentId: String) -> ABTestVariant {
        // Check if component is part of an active experiment
        if let experiment = findExperiment(for: componentId) {
            return userVariants[experiment.id] ?? .control
        }
        
        return .control
    }
    
    /// Record conversion for an experiment
    func recordConversion(experimentId: String, variant: ABTestVariant) {
        guard var experiment = experiments[experimentId] else {
            return
        }
        
        let key = variant.rawValue
        experiment.conversions[key, default: 0] += 1
        
        experiments[experimentId] = experiment
        
        print("[ABTestManager] Recorded conversion for \(experimentId), variant: \(variant)")
        
        // Check if we should conclude the experiment
        checkExperimentCompletion(experiment)
    }
    
    /// Check if experiment should be rolled back
    func shouldRollback(_ experiment: ABTestExperiment) -> Bool {
        guard experiment.status == .active else {
            return false
        }
        
        // Rollback if treatment performs significantly worse
        let controlConversions = experiment.conversions["control"] ?? 0
        let treatmentConversions = experiment.conversions["treatment"] ?? 0
        
        let totalConversions = controlConversions + treatmentConversions
        guard totalConversions > 100 else {
            return false // Not enough data
        }
        
        let controlRate = Double(controlConversions) / Double(totalConversions)
        let treatmentRate = Double(treatmentConversions) / Double(totalConversions)
        
        // Rollback if treatment is 20% worse than control
        if treatmentRate < controlRate * 0.8 {
            return true
        }
        
        return false
    }
    
    // MARK: - Private Methods
    
    private func assignVariant(for experiment: ABTestExperiment) -> ABTestVariant {
        // Check if user already has a variant assigned
        let key = "ab_test_\(experiment.id)"
        if let savedVariant = userDefaults.string(forKey: key),
           let variant = ABTestVariant(rawValue: savedVariant) {
            return variant
        }
        
        // Assign variant randomly (50/50 split)
        let variant: ABTestVariant = Bool.random() ? .control : .treatment
        
        // Save assignment
        userDefaults.set(variant.rawValue, forKey: key)
        
        return variant
    }
    
    private func findExperiment(for componentId: String) -> ABTestExperiment? {
        return experiments.values.first { experiment in
            experiment.recommendation.target == componentId
        }
    }
    
    private func checkExperimentCompletion(_ experiment: ABTestExperiment) {
        let totalConversions = experiment.conversions.values.reduce(0, +)
        
        // Conclude experiment after 1000 conversions
        if totalConversions >= 1000 {
            var updatedExperiment = experiment
            updatedExperiment.status = .completed
            experiments[experiment.id] = updatedExperiment
            
            print("[ABTestManager] Experiment \(experiment.id) completed")
        }
    }
}

