# VIBEZ - Lazy Signup & Zero-Friction Flow

## 1. Core Philosophy: "Value First, Identity Later"
The app launches immediately into the core experience. There is no "Login" screen, no "Welcome" carousel, and no permission prompts on first launch. The user is treated as a "Guest" with full read access and limited write access.

## 2. The Guest Identity (Ephemeral)
-   **Creation**: Automatically generated on first launch.
-   **Data**:
    -   `id`: UUID (Local only)
    -   `handle`: "VibeGuest_[Random]"
    -   `avatar`: Default abstract gradient.
    -   `role`: `.guest`
-   **Persistence**: Stored in `UserDefaults` / Keychain. Persists across app restarts but lost if app is deleted (unless upgraded).
-   **Privacy**: No data sent to server until they join a room or perform an action requiring it.

## 3. User Flow

### A. First Launch (Zero Friction)
1.  **Splash**: 0.5s animation of VIBEZ logo.
2.  **Home View**: User lands directly on the "Lounge".
    -   *Micro-Interaction*: A small, dismissible "toast" at the bottom: "Welcome to VIBEZ. You are in Guest Mode."
3.  **Permissions**: None requested. No Notification, Mic, or Contact prompts.

### B. The "Hook" (Value Discovery)
-   **Browsing**: Guest can view all rooms, see activity, and explore profiles.
-   **Joining a Room (Listener)**:
    -   Guest taps a room.
    -   Enters immediately as a listener.
    -   *Prompt*: "Allow Microphone?" only if they tap the "Speak" button.

### C. The Upgrade Moments (Contextual)
We only ask for signup when the user tries to do something that *requires* a permanent identity.

1.  **Scenario: Speaking in a Room**
    -   User taps "Mic".
    -   *Action*: Mic permission requested.
    -   *Logic*: Guests can speak (if room allows), but are prompted: "Create a handle to be recognized?" (Optional).

2.  **Scenario: Following a User**
    -   User taps "Follow".
    -   *Trigger*: `LazySignupSheet` appears.
    -   *Copy*: "Save your profile to follow creators."

3.  **Scenario: Creating a Room**
    -   User taps "Start Vibe".
    -   *Trigger*: `LazySignupSheet` appears.
    -   *Copy*: "You need an account to host a room."

### D. The Lazy Signup Sheet
A non-intrusive, half-height sheet.
-   **Headline**: "Claim Your Vibe"
-   **Input**: Just a Handle (Username).
-   **Action**: "Continue".
-   **Behind the Scenes**:
    -   The local Guest UUID is converted to a registered User UUID.
    -   Keys are generated.
    -   *Optional*: "Secure this account with Apple/Google" (Secondary step, can be skipped).

## 4. Data Transition
-   **Guest -> User**:
    -   Any "Saved" items (locally stored) are migrated to the new account.
    -   Privacy settings selected as a Guest are preserved.

## 5. Wireframes

### Screen: Home (Guest Mode)
-   **Avatar**: Generic outline icon.
-   **Profile Tab**: Shows "Guest" badge.

### Screen: Profile (Guest Mode)
-   **Header**: "Guest User"
-   **Stats**: Hidden or "0".
-   **CTA**: Large, elegant card: "Initialize Identity".
    -   *Subtext*: "Secure your name and stats. No email required."

### Screen: Lazy Signup (Sheet)
-   **Style**: Glassmorphism, bottom sheet.
-   **Fields**:
    1.  Display Name (Required)
    2.  Handle (Auto-generated, editable)
-   **Buttons**:
    -   "Create Identity" (Primary, Electric Blue)
    -   "Sign in with Apple" (Secondary, Black)
    -   "Maybe Later" (Tertiary, Text only)

## 6. Implementation Plan
1.  **`GuestService`**: Manages the ephemeral ID.
2.  **`AppState`**: Tracks `.isGuest` status.
3.  **`ProfileView`**: Updates to show Guest state.
4.  **`LazySignupView`**: The upgrade UI.

