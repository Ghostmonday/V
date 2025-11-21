/**
 * Example Usage: Telemetry Opt-Out Flow
 * 
 * This demonstrates how to integrate the TelemetryOptOutFlow component
 * into your application.
 */

import React, { useState } from 'react';
import TelemetryOptOutFlow from './TelemetryOptOutFlow';

export default function TelemetryExample() {
    const [showFlow, setShowFlow] = useState(true);
    const [userPreferences, setUserPreferences] = useState<any>(null);

    const handleComplete = (settings: any) => {
        console.log('User telemetry preferences:', settings);

        // Save to your backend
        // await saveTelemetryPreferences(settings);

        // Store in local state
        setUserPreferences(settings);

        // Hide the flow
        setShowFlow(false);
    };

    const openSettings = () => {
        setShowFlow(true);
    };

    if (!showFlow && userPreferences) {
        return (
            <div style={{ padding: '40px', fontFamily: 'system-ui' }}>
                <h1>Welcome to Your App! 🎉</h1>
                <p>Your privacy preferences have been saved.</p>

                <div style={{ marginTop: '32px', padding: '24px', background: '#f9fafb', borderRadius: '12px' }}>
                    <h3>Your Current Settings:</h3>
                    <ul>
                        <li>Crash Reports: {userPreferences.crashReports ? '✅ Enabled' : '❌ Disabled'}</li>
                        <li>Usage Analytics: {userPreferences.usageAnalytics ? '✅ Enabled' : '❌ Disabled'}</li>
                        <li>Performance Metrics: {userPreferences.performanceMetrics ? '✅ Enabled' : '❌ Disabled'}</li>
                        <li>Feature Usage: {userPreferences.featureUsage ? '✅ Enabled' : '❌ Disabled'}</li>
                    </ul>

                    <button
                        onClick={openSettings}
                        style={{
                            marginTop: '16px',
                            padding: '12px 24px',
                            background: '#8b5cf6',
                            color: 'white',
                            border: 'none',
                            borderRadius: '8px',
                            cursor: 'pointer',
                            fontWeight: '600',
                        }}
                    >
                        Change Preferences
                    </button>
                </div>
            </div>
        );
    }

    return <TelemetryOptOutFlow onComplete={handleComplete} />;
}

/**
 * Integration Tips:
 * 
 * 1. Show on First Launch:
 *    - Check if user has completed onboarding
 *    - Show this flow before main app
 * 
 * 2. Save Preferences:
 *    - Store in backend database
 *    - Also cache locally for offline access
 *    - Respect user choices in all telemetry code
 * 
 * 3. Allow Changes:
 *    - Add a settings page with link to reopen flow
 *    - Or just show individual toggles in settings
 * 
 * 4. Backend Integration:
 *    async function saveTelemetryPreferences(settings) {
 *      await fetch('/api/user/telemetry-preferences', {
 *        method: 'POST',
 *        headers: { 'Content-Type': 'application/json' },
 *        body: JSON.stringify(settings),
 *      });
 *    }
 * 
 * 5. Respect Choices:
 *    - Before sending any telemetry, check preferences:
 *    
 *    if (userPreferences.crashReports) {
 *      Sentry.captureException(error);
 *    }
 *    
 *    if (userPreferences.usageAnalytics) {
 *      analytics.track('feature_used', { feature: 'chat' });
 *    }
 */
