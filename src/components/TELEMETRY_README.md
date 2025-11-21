# Telemetry Opt-Out Flow 🛡️

A beautiful, privacy-first React component for collecting user telemetry preferences.

## Features ✨

- **Respectful Design**: Clear, jargon-free language that respects user privacy
- **Full Transparency**: Explains exactly what data is collected and why
- **User Control**: Individual toggles for each telemetry type (default: ON)
- **Easy Navigation**: Progress bar, back/forward buttons, summary review
- **Skip-Friendly**: Skipping keeps all options enabled (opt-in by default)
- **Beautiful UI**: Modern gradients, smooth animations, fully responsive
- **Accessible**: Can revisit and change preferences anytime

## Usage

```tsx
import TelemetryOptOutFlow from './components/TelemetryOptOutFlow';

function App() {
  const handleComplete = (settings) => {
    // Save user preferences
    console.log(settings);
    // {
    //   crashReports: true,
    //   usageAnalytics: false,
    //   performanceMetrics: true,
    //   featureUsage: true,
    // }
  };

  return <TelemetryOptOutFlow onComplete={handleComplete} />;
}
```

## Flow Screens

### 1. Intro Screen
- Security promises (🔒 Top-tier security, ❌ Never sold, 👁️ Full transparency)
- Clear explanation of what's happening next
- "Review Options" or "Skip for Now" buttons

### 2. Individual Option Screens (4 screens)
Each telemetry type gets its own screen:
- **Crash Reports**: Error logs to fix bugs faster
- **Usage Analytics**: Feature usage patterns (no personal content)
- **Performance Metrics**: Load times, battery, network speed
- **Feature Usage**: Which features are most popular

Each screen includes:
- Toggle switch (ON by default)
- "What We Collect" card
- "Why It Helps" card  
- Back/Next navigation
- Progress bar at top

### 3. Summary Screen
- Shows all choices in one place
- Click any item to jump back and change it
- Reminder that settings can be changed later
- "Confirm Choices" button

## Customization

### Add/Remove Telemetry Types

Edit the `TELEMETRY_INFO` object in `TelemetryOptOutFlow.tsx`:

```tsx
const TELEMETRY_INFO = {
  yourNewType: {
    title: 'Your Feature',
    description: 'Brief explanation',
    whatWeCollect: 'Specific data points',
    whyItHelps: 'How it improves the app',
  },
};
```

Then add it to the `TelemetrySettings` interface and `TELEMETRY_STEPS` array.

### Change Styling

All styles are in `TelemetryOptOutFlow.css`. Key variables:
- Gradient: `linear-gradient(135deg, #667eea 0%, #764ba2 100%)`
- Primary color: `#8b5cf6` (purple)
- Accent color: `#6366f1` (indigo)

### Modify Text

All user-facing text is in the `TELEMETRY_INFO` object and screen JSX.
No hardcoded strings in CSS.

## Best Practices

### 1. Show on First Launch
```tsx
if (!user.hasCompletedTelemetryOnboarding) {
  return <TelemetryOptOutFlow onComplete={handleComplete} />;
}
```

### 2. Respect User Choices
```tsx
// Before sending telemetry
if (userPreferences.crashReports) {
  Sentry.captureException(error);
}
```

### 3. Allow Easy Updates
Add a "Privacy Settings" link in your app that reopens the flow.

### 4. Persist Preferences
```tsx
const handleComplete = async (settings) => {
  // Save to backend
  await fetch('/api/user/telemetry', {
    method: 'POST',
    body: JSON.stringify(settings),
  });
  
  // Cache locally
  localStorage.setItem('telemetryPrefs', JSON.stringify(settings));
};
```

## Design Philosophy

This component follows privacy-first principles:

1. **Opt-in by default**: All toggles start ON, but users can easily disable
2. **Skip = Opt-in**: Skipping doesn't disable anything (avoids dark patterns)
3. **Clear language**: No jargon, no legalese, just honest explanations
4. **Easy to change**: Users can revise choices without penalty
5. **Transparent**: Explains exactly what, why, and how data is used

## Files

- `TelemetryOptOutFlow.tsx` - Main component
- `TelemetryOptOutFlow.css` - All styling
- `TelemetryExample.tsx` - Integration example

## Browser Support

- Chrome/Edge 90+
- Firefox 88+
- Safari 14+
- Mobile browsers (responsive design)

## License

Use freely in your projects. Attribution appreciated but not required.
