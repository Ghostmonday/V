# VIBEZ - MVP Entry Flow & Frictionless Architecture

## 1. Core Philosophy: "Open Door Policy"
For the MVP, we remove all barriers to entry. The app is fully functional immediately upon download. Identity is fluid, starting as ephemeral and becoming permanent only when the user chooses.

## 2. Structural Requirements Implementation

### 1. Session Timer & Soft Prompt
-   **Mechanism**: `GuestService` tracks `sessionStartTime`.
-   **Trigger**: After 4 hours (configurable), `showSavePrompt` is set to true.
-   **UI**: A non-blocking, glassmorphism banner appears at the bottom of the `HomeView`.
-   **Action**: "Save" opens the `LazySignupView`. "X" dismisses it for the session.

### 2. Core Feature Set (Guest Access)
Guests have unrestricted access to:
-   **Dashboard**: Viewing active rooms (`HomeView`).
-   **Search**: Finding content (`ExploreView`).
-   **Listening**: Joining rooms as a listener.
-   **Basic Edits**: Changing local app settings (theme, privacy).

### 3. Privacy Toggles Upfront
-   **Default**: All tracking (Crash, Analytics, Discovery) is **OFF**.
-   **Access**: `PrivacySettingsView` is accessible from the Profile tab.
-   **Control**: Simple toggle switches with clear explanations.

### 4. Universal Exit Paths
-   **Navigation**: Floating Dock allows instant switching between Home, Explore, and Profile.
-   **Modals**: All sheets (`LazySignupView`) have a "Maybe Later" or "Close" action.
-   **No Traps**: No forced tutorials or unskippable flows.

### 5. Lightweight Guest Storage
-   **Storage**: `UserDefaults` stores the ephemeral `guestID` and `guestHandle`.
-   **Sync**: When upgrading, the local Guest ID is replaced by the authenticated User ID, but local preferences are preserved.

### 6. Guest Mode Identity
-   **Indicator**: A subtle "GUEST MODE" badge appears in the `HomeView` header next to the logo.
-   **Profile**: The Profile tab clearly shows "Guest User" status.

### 7. One-Click Upgrade Path
-   **UI**: `LazySignupView` now includes "Continue with Apple" and "Continue with Google" buttons.
-   **Flow**:
    1.  User taps "Initialize Identity" (Profile) or "Save" (Prompt).
    2.  Sheet appears.
    3.  User taps "Apple".
    4.  System auth handles the rest.
    5.  Guest state transitions to User state instantly.

## 3. Wireframe Logic

### Home View (Guest)
-   **Header**: [VIBEZ] [GUEST MODE Badge] ... [Status Orb]
-   **Body**: Scrollable content.
-   **Footer**: (Conditional) Soft Save Prompt Banner.

### Lazy Signup Sheet
-   **Header**: "Claim Your Vibe"
-   **Primary Actions**: [Apple Button] [Google Button]
-   **Secondary**: "OR" divider + Handle Input.
-   **Tertiary**: "Maybe Later" (Dismiss).

## 4. Technical Components
-   **`GuestService.swift`**: Manages session timer and identity state.
-   **`HomeView.swift`**: Renders the Guest Badge and Soft Prompt.
-   **`LazySignupView.swift`**: Handles the upgrade logic.
-   **`PrivacySettingsView.swift`**: Manages opt-in permissions.

This architecture ensures the MVP feels premium and respectful while maximizing user acquisition through zero friction.

