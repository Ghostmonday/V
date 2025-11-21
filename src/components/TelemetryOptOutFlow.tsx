/**
 * Telemetry Opt-Out Flow
 * Privacy-first onboarding flow for telemetry preferences
 */

import React, { useState } from 'react';
import './TelemetryOptOutFlow.css';

interface TelemetrySettings {
    crashReports: boolean;
    usageAnalytics: boolean;
    performanceMetrics: boolean;
    featureUsage: boolean;
}

type Step = 'intro' | 'crashReports' | 'usageAnalytics' | 'performanceMetrics' | 'featureUsage' | 'summary';

const TELEMETRY_STEPS: Step[] = ['intro', 'crashReports', 'usageAnalytics', 'performanceMetrics', 'featureUsage', 'summary'];

interface TelemetryInfo {
    title: string;
    description: string;
    whatWeCollect: string;
    whyItHelps: string;
}

const TELEMETRY_INFO: Record<Exclude<Step, 'intro' | 'summary'>, TelemetryInfo> = {
    crashReports: {
        title: 'Crash Reports',
        description: 'Help us fix bugs faster and keep your app running smoothly.',
        whatWeCollect: 'Error messages, device type, and app version when something goes wrong.',
        whyItHelps: 'Lets us quickly identify and fix issues before they affect more people.',
    },
    usageAnalytics: {
        title: 'Usage Analytics',
        description: 'Understand how people use the app to make it better for everyone.',
        whatWeCollect: 'Which features you use and how often (no personal content or messages).',
        whyItHelps: 'Shows us what works well and what needs improvement.',
    },
    performanceMetrics: {
        title: 'Performance Metrics',
        description: 'Keep the app fast and responsive on all devices.',
        whatWeCollect: 'Load times, battery usage, and network speed.',
        whyItHelps: 'Helps us optimize the app for your specific device and connection.',
    },
    featureUsage: {
        title: 'Feature Usage',
        description: 'Learn which features you love and which ones need work.',
        whatWeCollect: 'How often you use different features and settings.',
        whyItHelps: 'Guides our development to focus on what matters most to you.',
    },
};

export default function TelemetryOptOutFlow({ onComplete }: { onComplete?: (settings: TelemetrySettings) => void }) {
    const [currentStep, setCurrentStep] = useState<Step>('intro');
    const [settings, setSettings] = useState<TelemetrySettings>({
        crashReports: true,
        usageAnalytics: true,
        performanceMetrics: true,
        featureUsage: true,
    });

    const currentStepIndex = TELEMETRY_STEPS.indexOf(currentStep);
    const progress = ((currentStepIndex + 1) / TELEMETRY_STEPS.length) * 100;

    const goToNextStep = () => {
        const nextIndex = currentStepIndex + 1;
        if (nextIndex < TELEMETRY_STEPS.length) {
            setCurrentStep(TELEMETRY_STEPS[nextIndex]);
        }
    };

    const goToPreviousStep = () => {
        const prevIndex = currentStepIndex - 1;
        if (prevIndex >= 0) {
            setCurrentStep(TELEMETRY_STEPS[prevIndex]);
        }
    };

    const goToStep = (step: Step) => {
        setCurrentStep(step);
    };

    const toggleSetting = (key: keyof TelemetrySettings) => {
        setSettings((prev) => ({ ...prev, [key]: !prev[key] }));
    };

    const handleComplete = () => {
        onComplete?.(settings);
    };

    const handleSkip = () => {
        // Skipping means all stay enabled (opt-in)
        onComplete?.({
            crashReports: true,
            usageAnalytics: true,
            performanceMetrics: true,
            featureUsage: true,
        });
    };

    return (
        <div className="telemetry-flow">
            {/* Progress Bar */}
            {currentStep !== 'intro' && (
                <div className="progress-bar-container">
                    <div className="progress-bar" style={{ width: `${progress}%` }} />
                </div>
            )}

            {/* Intro Screen */}
            {currentStep === 'intro' && (
                <div className="telemetry-screen intro-screen">
                    <div className="icon-shield">🛡️</div>
                    <h1>Your Privacy Matters</h1>
                    <p className="subtitle">We believe in complete transparency</p>

                    <div className="privacy-promises">
                        <div className="promise-item">
                            <span className="promise-icon">🔒</span>
                            <div>
                                <h3>Top-Tier Security</h3>
                                <p>Your data is encrypted and protected with industry-leading standards</p>
                            </div>
                        </div>

                        <div className="promise-item">
                            <span className="promise-icon">❌</span>
                            <div>
                                <h3>Never Sold</h3>
                                <p>We will never sell your data to third parties. Period.</p>
                            </div>
                        </div>

                        <div className="promise-item">
                            <span className="promise-icon">👁️</span>
                            <div>
                                <h3>Full Transparency</h3>
                                <p>You control exactly what we collect and can change it anytime</p>
                            </div>
                        </div>
                    </div>

                    <p className="intro-description">
                        We'd like to collect some anonymous data to make this app better.
                        On the next screens, you can choose what you're comfortable sharing.
                    </p>

                    <div className="button-group">
                        <button className="btn btn-primary" onClick={goToNextStep}>
                            Review Options
                        </button>
                        <button className="btn btn-text" onClick={handleSkip}>
                            Skip for Now
                        </button>
                    </div>
                </div>
            )}

            {/* Individual Telemetry Screens */}
            {currentStep !== 'intro' && currentStep !== 'summary' && (
                <div className="telemetry-screen option-screen">
                    <div className="step-indicator">
                        Step {currentStepIndex} of {TELEMETRY_STEPS.length - 2}
                    </div>

                    <h2>{TELEMETRY_INFO[currentStep].title}</h2>
                    <p className="description">{TELEMETRY_INFO[currentStep].description}</p>

                    <div className="toggle-section">
                        <div className="toggle-header">
                            <span className="toggle-label">
                                {settings[currentStep as keyof TelemetrySettings] ? 'Enabled' : 'Disabled'}
                            </span>
                            <label className="toggle-switch">
                                <input
                                    type="checkbox"
                                    checked={settings[currentStep as keyof TelemetrySettings]}
                                    onChange={() => toggleSetting(currentStep as keyof TelemetrySettings)}
                                />
                                <span className="toggle-slider"></span>
                            </label>
                        </div>
                    </div>

                    <div className="info-cards">
                        <div className="info-card">
                            <h4>📊 What We Collect</h4>
                            <p>{TELEMETRY_INFO[currentStep].whatWeCollect}</p>
                        </div>

                        <div className="info-card">
                            <h4>✨ Why It Helps</h4>
                            <p>{TELEMETRY_INFO[currentStep].whyItHelps}</p>
                        </div>
                    </div>

                    <div className="button-group">
                        {currentStepIndex > 1 && (
                            <button className="btn btn-secondary" onClick={goToPreviousStep}>
                                ← Back
                            </button>
                        )}
                        <button className="btn btn-primary" onClick={goToNextStep}>
                            {currentStepIndex < TELEMETRY_STEPS.length - 2 ? 'Next →' : 'Review Choices'}
                        </button>
                    </div>
                </div>
            )}

            {/* Summary Screen */}
            {currentStep === 'summary' && (
                <div className="telemetry-screen summary-screen">
                    <h2>Your Privacy Choices</h2>
                    <p className="subtitle">Here's what you've selected:</p>

                    <div className="summary-list">
                        {Object.entries(TELEMETRY_INFO).map(([key, info]) => (
                            <div
                                key={key}
                                className={`summary-item ${settings[key as keyof TelemetrySettings] ? 'enabled' : 'disabled'}`}
                                onClick={() => goToStep(key as Step)}
                            >
                                <div className="summary-item-header">
                                    <h3>{info.title}</h3>
                                    <span className={`status-badge ${settings[key as keyof TelemetrySettings] ? 'enabled' : 'disabled'}`}>
                                        {settings[key as keyof TelemetrySettings] ? '✓ Enabled' : '✗ Disabled'}
                                    </span>
                                </div>
                                <p>{info.description}</p>
                                <button className="change-btn">Change →</button>
                            </div>
                        ))}
                    </div>

                    <div className="summary-note">
                        <p>💡 You can change these settings anytime in your account preferences.</p>
                    </div>

                    <div className="button-group">
                        <button className="btn btn-secondary" onClick={goToPreviousStep}>
                            ← Back
                        </button>
                        <button className="btn btn-primary" onClick={handleComplete}>
                            Confirm Choices
                        </button>
                    </div>
                </div>
            )}
        </div>
    );
}
