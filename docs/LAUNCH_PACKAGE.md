# VIBEZ - Launch-Ready MVP Package

## 1. Executive Summary
VIBEZ is a privacy-first, voice-centric social platform designed to be the "Signal of Social Audio". This MVP package represents a production-grade build that prioritizes speed, privacy, and premium UX.

**Core Value Proposition:**
-   **Zero Friction**: Guest Mode allows instant access (<1s).
-   **Privacy First**: No tracking by default. Self-hosting supported.
-   **Persistent Presence**: Rooms are places, not calls.

---

## 2. Onboarding & Entry Flow (Finalized)
*Philosophy: "The best onboarding is no onboarding."*

### Flow Diagram
1.  **App Launch** -> **Home View (Guest Mode)**
    -   *Time*: Instant.
    -   *State*: Ephemeral UUID generated locally.
2.  **Activation Loop (Gamified Checklist)**
    -   Displayed prominently on Home.
    -   Tasks: "Tune In", "Pass the Vibe", "Claim Identity".
3.  **Upgrade Trigger (Contextual)**
    -   User taps "Claim Identity" or hits 4-hour session limit.
    -   **Lazy Signup Sheet**: One-tap OAuth (Apple/Google) or Handle choice.

### Key Metrics
-   **Time to First Listen**: < 5 seconds.
-   **Signup Conversion Goal**: 15% of Guests within 7 days.

---

## 3. Core Feature Set

### A. Persistent Channels (`RoomView.swift`)
-   **Dual Modality**: Voice Stage (Top) + Persistent Text Chat (Bottom).
-   **Visuals**: "Vibe Orb" visualization for active speakers.
-   **States**: Active (Voice), Idle (Text Only).

### B. Privacy Controls (`PrivacySettingsView.swift`)
-   **Disappearing Messages**: Toggle for 24h auto-delete.
-   **Data Sovereignty**: Export/Delete data controls.
-   **Permissions**: Granular toggles for Crash/Analytics (Default: OFF).

### C. Discovery (`ExploreView.swift`)
-   **Featured Carousel**: Premium showcase for top-tier rooms.
-   **Categories**: Music, Tech, Gaming, Art.

### D. Self-Hosting (`SelfHostSettingsView.swift`)
-   **One-Click Connect**: Scan QR code to switch to private node.
-   **Docker Support**: `docker-compose.yml` provided for easy server setup.

---

## 4. Featured Rooms System (Monetization)

### Pricing Tiers
| Tier | Duration | Placement | Price |
| :--- | :--- | :--- | :--- |
| **Boost** | 24 Hours | Trending List | $4.99 |
| **Spotlight** | 3 Days | Featured Carousel | $19.99 |
| **Headline** | 1 Week | Hero Slot | $99.99 |

### Automation Logic
1.  **Payment**: Stripe/IAP webhook triggers `FeatureService`.
2.  **Allocation**: Checks `featured_slots` table for availability.
3.  **Queueing**: If slot full, schedules for next available `end_time`.
4.  **Expiration**: Cron job updates status to `expired` when `end_time < NOW()`.

### Database Schema
```sql
CREATE TABLE featured_slots (
    id UUID PRIMARY KEY,
    room_id UUID REFERENCES rooms(id),
    tier INT NOT NULL,
    start_time TIMESTAMP,
    end_time TIMESTAMP,
    status TEXT -- 'active', 'scheduled'
);
```

---

## 5. UI/UX Polish Summary
*Theme: "Digital Noir"*

-   **Color Palette**: Deep Void (`#05050A`) + Electric Blue (`#2E5CFF`).
-   **Typography**: Custom rounded sans-serif (`VibezTypography`).
-   **Components**:
    -   `GlassCard`: Unified container for all content.
    -   `VibezBackground`: Consistent animated ambient background.
    -   `ControlIcon`: Standardized circular buttons.
-   **Micro-Interactions**:
    -   Haptic feedback on all toggles.
    -   Spring animations for modal transitions.
    -   "Breathing" animation for the Vibe Orb.

---

## 6. Launch Readiness Checklist

### QA
-   [ ] Guest Mode generates UUID correctly.
-   [ ] Session timer triggers "Soft Prompt" at 4 hours.
-   [ ] "Claim Identity" successfully upgrades Guest to User.
-   [ ] Room audio connects/disconnects reliably.
-   [ ] Self-host toggle switches API endpoint.

### Compliance
-   [ ] App Store Privacy Label: "Data Not Collected" (mostly).
-   [ ] GDPR/CCPA: Export/Delete flows functional.
-   [ ] EULA: Terms of Service accessible in Settings.

### Infrastructure
-   [ ] Production DB (Postgres) scaled.
-   [ ] Redis Cluster active for presence.
-   [ ] Media Servers (LiveKit/Agora) provisioned.

---

## 7. Roadmap (Post-Launch)
1.  **Direct Messages**: E2EE 1-on-1 chats.
2.  **Android Client**: Feature parity.
3.  **Creator Tools**: Ticketed events and subscription rooms.

*VIBEZ is ready for takeoff.*

