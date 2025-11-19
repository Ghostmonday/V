# VIBEZ Node - Self-Hosting Guide

## Philosophy: "Your Cloud, Your Rules"
Running a VIBEZ Node gives you complete control over your data. We've designed this process to be as simple as installing an app, not managing a server farm.

## 1. Quick Start (The "One-Click" Path)

### Requirements
-   A machine running Docker (Mac, Windows, Linux, or Raspberry Pi).
-   2GB RAM recommended.

### Installation
1.  Create a folder named `vibez-node`.
2.  Download the `docker-compose.yml` file into it.
3.  Run:
    ```bash
    docker-compose up -d
    ```
4.  Navigate to `http://localhost:8080` to finish setup.

## 2. The Setup Experience
We don't believe in black terminal screens. The VIBEZ Node setup is a graphical, polished wizard.

### Step 1: The Welcome
-   **Visual**: A calm, dark glass card centered on a deep blue background.
-   **Action**: "Initialize Node".

### Step 2: Identity
-   **Input**: Name your instance (e.g., "The Chen Family Cloud").
-   **Privacy**: Toggle "Public Directory Listing" (Default: OFF).

### Step 3: Security
-   **Admin Account**: Create the root user.
-   **Encryption**: Auto-generates keys. You just download the `recovery-key.txt`.

## 3. The Admin Dashboard
Once running, your dashboard is the command center.

### Status at a Glance
-   **Health Orb**: Glowing Green (Healthy), Amber (Issues), Red (Down).
-   **Metrics**: Active Rooms, Memory Usage, Storage (Visualized as clean bars, not raw numbers).

### Controls
-   **Updates**: "Update Available" appears as a non-intrusive notification. One click to upgrade.
-   **Backups**: Auto-scheduled. "Download Now" button available.
-   **Logs**: Hidden by default. Accessible via "Advanced Mode" toggle.

## 4. Connecting Your App
1.  Open VIBEZ on your phone.
2.  Go to **Profile > Settings > Server**.
3.  Tap **"Switch to Self-Hosted"**.
4.  Scan the QR code displayed on your Node's dashboard.
5.  Done. You are now communicating through your own hardware.

## 5. Advanced Configuration
For those who want to dig deeper, the `vibez.config.json` allows customization of:
-   WebRTC ports
-   Redis clustering
-   S3-compatible storage backends

---
*Privacy is not a feature; it's the architecture.*

