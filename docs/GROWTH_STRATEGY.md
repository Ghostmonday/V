# VIBEZ - Growth & Activation Strategy
*Based on "Minimal Viable Onboarding" Analysis*

## 1. The VIBEZ Advantage
We align with the "Best in Class" (Clubhouse, BeReal, Telegram) by prioritizing **Speed to Value**.
-   **VIBEZ**: 0 clicks to content (Guest Mode).
-   **Competitors**: 3-5 clicks (Sign up flows).

## 2. Activation Strategy (Converting Guests to DAUs)
We will implement a **"Guest Activation Loop"** to guide users to their "Aha Moment" without blocking them.

### A. Progressive Disclosure (The Checklist)
Instead of a tutorial, Guests see a non-intrusive "Vibe Check" list in the Home feed.
1.  **Tune In**: Join a room as a listener. (Value: Content)
2.  **Pass the Vibe**: Share a room link. (Value: Social/Viral)
3.  **Claim Identity**: Create a handle. (Value: Ownership)

*Reward*: Completing the list unlocks a special "Early Adopter" badge or visual flair.

### B. Viral Mechanics (Privacy-First)
Since we don't upload contacts (Privacy), we rely on **Pull-Based Virality**.
-   **Share Links**: "vibez.app/room/xyz".
-   **Preview Cards**: Links unfurl with rich media (Room Title, Current Speakers) on iMessage/WhatsApp.
-   **In-App Invite**: "Ping a Friend" uses the native iOS Share Sheet, keeping data local.

### C. Permission Priming
We never ask for permissions on launch.
-   **Mic**: Asked only when tapping "Speak".
    -   *Copy*: "To add your voice to the vibe, we need microphone access."
-   **Notifications**: Asked only when following a user/room.
    -   *Copy*: "Get notified when @alex goes live?"

## 3. Retention Tactics
-   **Session Preservation**: The "Soft Prompt" (implemented) saves the session.
-   **Guest Badge**: Reminds them they are temporary, creating subtle urgency to upgrade.

## 4. Implementation Plan
1.  **`GuestActivationView`**: A checklist component in `HomeView`.
2.  **`ShareSheet`**: Native integration for room sharing.
3.  **`PermissionManager`**: Contextual wrapper for system prompts.

