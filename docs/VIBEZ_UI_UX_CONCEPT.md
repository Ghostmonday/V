# VIBEZ - UI/UX Design Concept

## Vision
VIBEZ is a social voice-first communication platform that feels luxurious, seamless, and cutting-edge. The design language is "Digital Noir" - a sleek, dark mode-first aesthetic with high-contrast elements, deep blues, subtle gradients, and elegant animations.

## Core Design Pillars
1.  **Atmospheric Depth**: Use of deep blues, blacks, and subtle gradients to create a sense of infinite space.
2.  **Luminous Accents**: Glowing orbs, neon strokes, and soft lighting effects to indicate status and activity.
3.  **Fluid Motion**: Smooth transitions, elegant micro-interactions, and physics-based animations.
4.  **Minimalist Typography**: Clean, sans-serif typography (e.g., custom geometric font) that is legible and modern.
5.  **Voice-Centric**: Visualizations of voice (waveforms, glowing auras) are central to the experience.

## Color Palette

### Primary Colors
-   **Vibez Black**: `#05050A` (Background)
-   **Deep Void**: `#0A0A12` (Surface / Cards)
-   **Electric Blue**: `#2E5CFF` (Primary Action / Active State)
-   **Neon Cyan**: `#00F0FF` (Highlights / Notifications)
-   **Plasma Purple**: `#7B2EFF` (Secondary Accents / Gradients)

### Functional Colors
-   **Success**: `#00FF94` (Glowing Green)
-   **Warning**: `#FFD600` (Amber Glow)
-   **Error**: `#FF2E2E` (Crimson Glow)
-   **Text Primary**: `#FFFFFF`
-   **Text Secondary**: `#8F9BB3`

## Typography
-   **Headings**: *Syne* or *Space Grotesk* (Futuristic, wide stance)
-   **Body**: *Inter* or *SF Pro* (Clean, highly legible)

## Key UI Components

### 1. The "Vibe" Orb (Status Indicator)
A central visual element. A glowing sphere that changes color and pulse rate based on user status or room activity.
-   **Idle**: Slow, rhythmic breathing (Blue).
-   **Speaking**: Rapid, reactive pulsing (Cyan/Purple).
-   **Listening**: Soft, expanding ripple (White).

### 2. Glassmorphism 2.0
Updated glass effect with darker tints, higher blur, and subtle noise texture to feel more "premium material" than standard iOS glass.
-   Background: `rgba(10, 10, 18, 0.7)`
-   Blur: `25px`
-   Border: `1px solid rgba(255, 255, 255, 0.1)`

### 3. Navigation
-   **Floating Tab Bar**: A pill-shaped floating bar at the bottom, detached from the edges.
-   **Gesture-Based**: Heavy reliance on swipes for navigation to reduce button clutter.

## Key Screens

### 1. Splash / Login
-   **Background**: A subtle, animated deep blue nebula or gradient mesh.
-   **Logo**: "VIBEZ" in bold, glowing typography.
-   **Action**: "Enter the Vibe" button (Neumorphic/Glowing).

### 2. Home / Dashboard (The "Lounge")
-   **Layout**: Grid of active "Rooms" represented by dynamic cards.
-   **Cards**: Dark glass cards showing active speakers (avatars with glowing rings).
-   **Hero**: "Start a Vibe" button - prominent, pulsing.

### 3. Active Room (The "Stage")
-   **Visuals**: No list views. Users are floating orbs or avatars in a 3D-like space.
-   **Speaker Focus**: The active speaker's avatar glows and scales slightly.
-   **Background**: Reacts to the audio energy of the room.

## Implementation Plan
1.  **Clean Slate**: Remove all legacy "Sinapse" and "Glass" assets and code.
2.  **Design System**: Implement `VibezColors`, `VibezTypography`, and `VibezComponents`.
3.  **Core Views**: Rebuild `MainTabView`, `HomeView`, and `RoomView` using the new design language.

