# VIBEZ - UX Blueprint & Privacy-First Architecture

## 1. Core Philosophy: "Privacy as the Default"
The entire VIBEZ experience is built on the principle that user data is a liability, not an asset. We collect nothing by default. Every permission is explicitly requested with clear context, and the app functions fully without optional data.

### The "Zero-Knowledge" Promise
-   **No Analytics**: Unless opted-in.
-   **No Crash Reports**: Unless opted-in.
-   **No Contact Sync**: Unless explicitly triggered for a specific action.
-   **Local-First**: Preferences and keys are stored on-device.

## 2. Navigation Architecture
We abandon the traditional "Tab Bar + Navigation Controller" stack in favor of a fluid, gesture-driven spatial model.

### The "Floating Dock" System
Instead of a rigid bottom bar, we use a floating dock that disappears when not needed (e.g., inside a room), maximizing immersion.

-   **Home (The Lounge)**: Your personal space, active rooms, and friends.
-   **Explore (The Frequency)**: Discovering new vibes, topics, and creators.
-   **Profile (The Identity)**: Your digital persona and privacy control center.

### Navigation Rules
1.  **No Dead Ends**: Every screen has a clear "Back" or "Close" gesture.
2.  **Progressive Disclosure**: Show only what's needed. Advanced settings are tucked away but accessible.
3.  **Contextual Actions**: Buttons appear where the thumb naturally rests.

## 3. User Flows

### A. The "Cold Start" (Privacy Onboarding)
*Goal: Establish trust and configure privacy before the user ever sees the main interface.*

1.  **Welcome**: Brand introduction.
2.  **The Privacy Gate**: A dedicated screen asking for permissions (Crash Reporting, Discoverability). All toggles start **OFF**.
3.  **Completion**: Confirmation of the secure environment.
4.  **Result**: User lands on Home, feeling safe and in control.

### B. The "Main Loop" (Finding a Vibe)
*Goal: Frictionless entry into social spaces.*

1.  **Home**: User sees "Live Now" cards.
2.  **Tap**: Card expands (Hero animation).
3.  **Preview**: See who is speaking without joining (if public).
4.  **Join**: One tap to enter audio.
5.  **In-Room**: The UI fades away. Focus is on the "Vibe Orb" visualization.
6.  **Leave**: Swipe down or tap "Leave" to return to Home instantly.

### C. The "Control Loop" (Managing Privacy)
*Goal: Adjust settings without digging through menus.*

1.  **Profile**: Tap the avatar tab.
2.  **Privacy Hub**: Prominent "Privacy & Security" button.
3.  **Toggle**: Change a setting (e.g., disable discoverability).
4.  **Feedback**: Immediate visual confirmation ("Shield Active").

## 4. Wireframe Specifications

### Screen: Privacy Onboarding
-   **Layout**: Paged scroll view.
-   **Elements**: Large iconography, clear headers, toggle switches (Glassmorphism style).
-   **Interaction**: Swiping or "Next" button. Toggles have haptic feedback.

### Screen: Home (The Lounge)
-   **Header**: "VIBEZ" logo + Status Orb (User's current state).
-   **Body**: Horizontal scroll for "Live Now", Vertical list for "Recent".
-   **Components**: `RoomCard` (Glass), `ActivityRow`.

### Screen: Privacy Settings
-   **Header**: "Privacy Control Center" with Back button.
-   **Status Card**: Large green shield if secure.
-   **Toggles**: Clear labels, description text, standard iOS toggles (custom tinted).
-   **Danger Zone**: Red text for destructive actions (Delete Account).

## 5. Visual Language "Digital Noir"
-   **Background**: Deep void (`#05050A`) with subtle breathing gradients.
-   **Glass**: High blur, low opacity, thin white borders.
-   **Typography**: Custom geometric sans-serif.
-   **Motion**: Spring animations for all interactions. No linear transitions.

## 6. Implementation Status
-   ✅ **Privacy Onboarding**: Implemented (`PrivacyOnboardingView.swift`).
-   ✅ **State Management**: Implemented (`AppState.swift`).
-   ✅ **Main Navigation**: Implemented (`MainView.swift`).
-   ✅ **Privacy Settings**: Implemented (`PrivacySettingsView.swift`).
-   ✅ **Design System**: Implemented (`ColorPalette`, `Typography`, `Components`).

