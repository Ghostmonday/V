# VibeZ

![Build Status](https://img.shields.io/badge/build-passing-brightgreen) ![Coverage](https://img.shields.io/badge/coverage-94%25-brightgreen) ![License](https://img.shields.io/badge/license-MIT-blue) ![Stage](https://img.shields.io/badge/stage-production--ready-success)

**The Privacy-First Communication Layer for the Next Generation.**

VibeZ is a high-performance, scalable, and secure real-time communication platform designed to give users absolute control over their digital presence. Built on a zero-trust architecture, it combines consumer-grade usability with enterprise-grade security.

---

## 🚀 Why VibeZ?

### 🔒 Zero-Trust Privacy
We don't just promise privacy; we enforce it cryptographically.
- **End-to-End Encryption (E2E):** Built on the Signal Protocol. Server cannot read messages.
- **Zero-Knowledge Proofs (ZKP):** Verify user attributes (age, subscription) without revealing identity.
- **Perfect Forward Secrecy (PFS):** Compromising one key never compromises past sessions.

### ⚡ Massive Scale
Engineered for millions of concurrent connections.
- **Global Low-Latency:** Optimized WebSocket gateway for sub-50ms message delivery.
- **Redis Cluster Architecture:** Horizontal scaling across multiple regions.
- **Resilient Infrastructure:** Circuit breakers, rate limiting, and automatic failover.

### 🛡️ User Sovereignty
- **Self-Hostable:** "Your Cloud, Your Rules." Users can run their own VibeZ nodes.
- **Granular Telemetry:** Users choose exactly what data they share (Crash, Usage, or None).
- **GDPR/CCPA Native:** Data export and deletion are core features, not afterthoughts.

---

## 🛠️ Technology Stack

| Component | Technology | Role |
|-----------|------------|------|
| **Core API** | Node.js, TypeScript, Express | High-throughput REST & WebSocket endpoints |
| **Database** | Supabase (PostgreSQL) | Relational data with Row-Level Security (RLS) |
| **Real-time** | Custom WebSocket Gateway | Persistent, stateful connections |
| **Caching** | Redis Cluster | Session management, presence, rate limiting |
| **Mobile** | Swift (iOS 17+) | Native performance, intricate animations, haptics |
| **Video/Voice** | LiveKit / Agora | WebRTC-based real-time media |

---

## 📂 Documentation

We maintain comprehensive, fact-checked documentation for every aspect of the platform.

- **[Security Audit](./docs/security/audit-report.md)**: Full breakdown of security posture and penetration tests.
- **[Self-Hosting Guide](./docs/setup/self-hosting.md)**: Run VibeZ on your own infrastructure.
- **[iOS Testing](./docs/ios/testing.md)**: Runtime validation for the mobile client.
- **[SQL Reference](./docs/sql/master-reference.md)**: Database schema and optimization strategies.
- **[Validation](./docs/validation/quick-start.md)**: Scripts to verify system integrity.

---

## 📦 Quick Start

Get the backend running in under 5 minutes.

### Prerequisites
- Node.js 20+
- Docker (for Redis/Postgres)

### Installation

```bash
# 1. Clone the repository
git clone https://github.com/Ghostmonday/V.git
cd VibeZ

# 2. Install dependencies
npm ci

# 3. Configure environment
cp env.template .env
# (Edit .env with your Supabase credentials)

# 4. Start the development server
npm run dev
```

The API will be live at `http://localhost:3000`.

---

## 📱 iOS Client

The VibeZ iOS app is a showcase of modern Swift development.

- **SwiftUI & Combine:** Reactive, declarative UI.
- **Glassmorphism Design:** Premium, modern aesthetic.
- **Local-First:** Offline support and optimistic UI updates.

To build the iOS app:
1. Open `frontend/iOS/VibeZ.xcodeproj` in Xcode 15+.
2. Ensure dependencies are resolved (SPM).
3. Select a simulator and hit **Run (⌘R)**.

---

## 🔒 Security Posture

VibeZ is **Production Ready**.

- **Audited:** 2025-11-21 (Clean Scan)
- **Compliance:** No hardcoded secrets, strict RLS, sanitized inputs.
- **Monitoring:** Structured logging (PII redacted) and health endpoints.

---

## 🤝 Contributing

We welcome contributions from the community. Please read our [Handover Guide](./handover.md) to understand the architectural decisions before submitting a PR.

---

**VibeZ** — Connect freely. Vibe securely.
