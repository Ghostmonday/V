# VIBEZ - Persistent Presence & Featured System

## 1. Persistent Channels (The "Always-On" Philosophy)
Unlike traditional ephemeral voice chats, VIBEZ rooms are **Places**, not just calls. They exist permanently until deleted by the owner.

### Architecture
-   **State**: Rooms have a `status` field: `.active` (voice live), `.idle` (text only), or `.archived`.
-   **Visuals**:
    -   **Empty Room**: Displays a "Quiet" state with a subtle, slow-pulsing ambient glow. The text chat remains visible and scrollable.
    -   **Active Room**: The "Vibe Orb" activates, pulsing with audio energy.
-   **UX**: Users can "enter" an empty room to read chat or wait for others, just like sitting in a lounge.

## 2. Text + Voice Integration
Every room is a dual-modality space.
-   **Unified View**: The room interface is a split view (or overlay on mobile).
    -   **Top/Background**: Voice visualization (The Stage).
    -   **Bottom/Overlay**: Text thread (The Chat).
-   **Async Continuity**: Chat history persists. A user can read what happened while they were away, even if the voice call ended hours ago.

## 3. Stage-Style Rooms (Venues)
Premium rooms designed for one-to-many or few-to-many interactions.
-   **Layout**:
    -   **Stage**: Speakers appear larger, with distinct glowing borders.
    -   **Audience**: Listeners appear as smaller, muted orbs in a "crowd" visualization.
-   **Controls**: "Raise Hand" to request stage access. Host controls to mute/move users.
-   **Vibe**: Cinematic lighting effects. When a speaker talks, the "spotlight" (glow) intensifies.

## 4. Utility & Activities
Tools to enhance presence without fake activity.
-   **The Board**: A shared, real-time canvas for pinning images, links, or notes.
-   **Music Sync**: Integration with Spotify/Apple Music to show what the room is listening to (synchronized playback requires separate licensing, so we start with "Now Playing" status).
-   **Polls**: Quick, ephemeral voting for room decisions.

## 5. Authentic Community Design
-   **Trust Signals**:
    -   "Verified Host" badges.
    -   "Room Age" (e.g., "Est. 2024").
    -   "Regulars" list (users who frequent the room).
-   **No Fakes**: We never show "0" as anything other than "0". An empty room is an opportunity, not a failure.

---

## 6. Featured Rooms Landing Page (The "Front Door")
A visually stunning, curated list of high-quality rooms.

### UI Design
-   **Hero Section**: "Spotlight" carousel. Large, cinematic cards with motion backgrounds.
-   **Categories**: "Trending", "Chill", "Talks", "Music".
-   **Card Metadata**:
    -   **Title**: Bold typography.
    -   **Host**: Avatar + Handle.
    -   **Vibe**: 3-word tag (e.g., "Lo-Fi • Study • Focus").
    -   **Live Indicator**: "🔴 Live" or "💬 Chatting".
    -   **Badge**: "Featured" (Gold/Platinum glow).

### Frictionless Entry
-   **Tap-to-Listen**: Tapping a card instantly joins the audio as a guest. No signup, no popups.

---

## 7. Pricing Tier Suggestions (Sustainable Monetization)

| Tier | Name | Duration | Placement | Price (Est.) |
| :--- | :--- | :--- | :--- | :--- |
| **Tier 1** | **Boost** | 24 Hours | "Trending" List (Top 10) | $4.99 |
| **Tier 2** | **Spotlight** | 3 Days | "Featured" Section (Top 5) | $19.99 |
| **Tier 3** | **Headline** | 1 Week | Homepage Hero Carousel (Slot 1-3) | $99.99 |
| **Tier 4** | **Takeover** | 24 Hours | Category Header (Exclusive) | $149.99 |

*Note: Prices are dynamic based on demand.*

---

## 8. Encoding the Featured System (Schema)

### Database Schema (SQL)

```sql
CREATE TABLE featured_slots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id UUID REFERENCES rooms(id),
    user_id UUID REFERENCES users(id), -- The payer
    tier_level INT NOT NULL, -- 1=Boost, 2=Spotlight, 3=Headline, 4=Takeover
    start_time TIMESTAMP WITH TIME ZONE NOT NULL,
    end_time TIMESTAMP WITH TIME ZONE NOT NULL,
    status TEXT DEFAULT 'active', -- 'active', 'scheduled', 'expired'
    payment_ref TEXT, -- Stripe/Apple Pay ID
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index for fast querying of active features
CREATE INDEX idx_featured_active ON featured_slots (tier_level DESC, start_time ASC) 
WHERE status = 'active' AND end_time > NOW();
```

### Logic
-   **Queueing**: If a slot (e.g., Hero Slot 1) is occupied, the new purchase is `scheduled` for the next available `end_time`.
-   **Priority**: `ORDER BY tier_level DESC, start_time ASC`.

---

## 9. Automated Featuring (The "No-Admin" Flow)

1.  **Purchase**: User selects a tier in the app -> Apple Pay / Stripe processes payment.
2.  **Webhook**: Payment provider sends success webhook to backend.
3.  **Allocation (Server-Side)**:
    -   Check availability for the requested tier.
    -   If available immediately: Set `start_time = NOW()`, `end_time = NOW() + duration`. Status = `active`.
    -   If full: Find the earliest `end_time` of current slots. Set `start_time = that_time`. Status = `scheduled`.
4.  **Record**: Insert row into `featured_slots`.
5.  **Client Update**: The "Featured" API endpoint queries `WHERE status = 'active' AND end_time > NOW()`. The UI updates instantly.
6.  **Expiration**: A background cron job (or just the query logic) filters out rows where `end_time < NOW()`. No manual removal needed.

---

## 10. Creative Direction & Implementation

### Visual Style
-   **Cinematic**: Use video backgrounds or slow-pan images for Hero cards.
-   **Minimal**: Text overlays are clean, white, and legible.
-   **Premium**: Gold/Platinum gradients for badges.

### Implementation Plan
1.  **Backend**: Create `featured_slots` table and API endpoints (`GET /featured`, `POST /feature-room`).
2.  **Frontend**:
    -   Update `Room` model to support `isFeatured` and `tier`.
    -   Build `FeaturedCarousel` component.
    -   Build `PurchaseFeatureView` (IAP integration).
3.  **Automation**: Write the allocation logic in a Supabase Edge Function or Node.js service.

