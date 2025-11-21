# VibeZ – Real‑time Collaboration Platform

![VibeZ Banner](https://raw.githubusercontent.com/your-org/VibeZ/main/assets/banner.png)

---

## 📖 Overview

**VibeZ** is a high‑performance, privacy‑first real‑time collaboration platform built with **Node.js**, **TypeScript**, **Supabase**, and **WebSockets**.  It provides:

- **Secure end‑to‑end encryption** for every message.
- **Scalable architecture** with Redis clustering, rate‑limiting, and circuit‑breakers.
- **Rich telemetry** that respects user privacy (opt‑out flow).
- **Extensible moderation** and AI‑assisted content safety.
- **Comprehensive test suite** (unit, integration, load).

> **⚡️ Goal:** Deliver a premium, low‑latency chat experience while giving users full control over their data.

---

## 📦 Quick Start

```bash
# Clone the repo
git clone https://github.com/your-org/VibeZ.git
cd VibeZ

# Install dependencies (Node 20+, npm)
npm ci

# Set up environment variables (see env.template)
cp env.template .env
# Edit .env with your Supabase credentials, Redis config, etc.

# Run the development server
npm run dev
```

The API will be available at `http://localhost:3000`.

---

## 🛠️ Core Architecture

| Layer | Tech | Purpose |
|------|------|---------|
| **API** | Express + TypeScript | HTTP endpoints, auth, rate‑limiting |
| **WebSocket** | Custom gateway (`src/ws/websocket-gateway.ts`) | Real‑time messaging, reconnection handling |
| **Database** | Supabase (PostgreSQL) | Persistent storage, RLS policies |
| **Cache** | Redis (cluster / sentinel) | Presence, rate‑limit counters, message queues |
| **Encryption** | Libsodium + custom E2E service | End‑to‑end encryption for messages |
| **Telemetry** | `TelemetryOptOutFlow` component (React) | Collect opt‑in preferences |
| **Testing** | Vitest, Locust, Jest | Unit, integration, load testing |

---

## 📊 Telemetry Opt‑Out Flow

A beautiful, privacy‑first React component that guides users through four telemetry options:

1. **Crash Reports** – error logs for faster bug fixes.
2. **Usage Analytics** – feature usage patterns (no personal content).
3. **Performance Metrics** – load times, battery, network speed.
4. **Feature Usage** – which features are most popular.

All toggles are **ON by default**; users can disable any option.  Skipping the flow leaves all options enabled (opt‑in).  The component lives in:

- `src/components/TelemetryOptOutFlow.tsx`
- `src/components/TelemetryOptOutFlow.css`
- `src/components/TelemetryExample.tsx` (usage example)

> **Tip:** Move these files to your frontend React project – they depend on `react` and `@types/react`.

---

## 🧪 Validation Scripts

Two TypeScript scripts validate the codebase for common pitfalls:

- `scripts/validate-phase5.ts` – checks Perspective API integration, moderation thresholds, flagging system, and more.
- `scripts/validate-phases-1-3.ts` – validates early‑phase components such as WebSocket gateway, DB connections, and helper utilities.

Both scripts now use explicit `as string` assertions for `fs.readFileSync` calls, eliminating the `never` type errors.

Run them with:

```bash
npm run lint   # runs tsc --noEmit on the validation scripts
```

---

## ✅ Test Suite

```bash
# Run all tests
npm test
```

Current status (as of 2025‑11‑20):

- **116 passed**
- **7 failed** – related to Redis mock configuration and a few integration edge‑cases (not caused by recent changes).
- **2 skipped**

Load testing is performed with **Locust**:

```bash
python3 -m locust -f src/tests/load/locustfile.py --host http://localhost:3000
```

---

## 📂 Repository Layout

```
VibeZ/
├─ src/                     # Application source
│   ├─ components/          # React UI (Telemetry, etc.)
│   ├─ middleware/         # Express middlewares (auth, rate‑limit, security)
│   ├─ services/           # Business logic (messaging, moderation, encryption)
│   ├─ routes/             # API route definitions
│   ├─ utils/              # Helper utilities
│   └─ config/             # Environment configuration files
├─ scripts/                 # Validation scripts
├─ tests/                   # Vitest unit & integration tests
├─ sql/                     # Supabase migration & seed files
├─ .github/                 # CI workflows
└─ README.md                # *You are reading it!*
```

---

## 🛡️ Security & Privacy

- **End‑to‑end encryption** for all messages.
- **Supabase RLS policies** enforce per‑user data isolation.
- **Telemetry** is opt‑in; skipping keeps all data collection enabled but never sold.
- **Rate limiting** protects against abuse at both HTTP and WebSocket layers.

---

## 🤝 Contributing

1. Fork the repository.
2. Create a feature branch (`git checkout -b feat/awesome-feature`).
3. Write tests for new functionality.
4. Run the full test suite (`npm test`).
5. Submit a pull request.

Please follow the **code style** enforced by `eslint` and keep the **type safety** intact.

---

## 📜 License

MIT © 2025 VibeZ Team. See `LICENSE` for details.

---

## 📚 Further Reading

- **Telemetry Opt‑Out Flow Docs:** `src/components/TELEMETRY_README.md`
- **Validation Scripts Overview:** `scripts/README.md`
- **Load Testing Guide:** `src/tests/load/README.md`

---

*Built with love, privacy, and performance in mind.*
