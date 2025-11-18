# VibeZ

> Real-time chat and communication platform with WebSocket support, emotional state tracking, and comprehensive security features

---

## Table of Contents

- [🚀 Quick Start](#-quick-start)
- [📖 Overview](#-overview)
- [✨ Key Features](#-key-features)
- [📁 Project Structure](#-project-structure)
- [🛠️ Installation & Setup](#️-installation--setup)
- [🏃 Running the Project](#-running-the-project)
- [🧪 Testing](#-testing)
- [🚀 Deployment](#-deployment)
- [🔧 Configuration](#-configuration)
- [🔒 Security](#-security)
- [📚 Documentation](#-documentation)
- [🐛 Troubleshooting](#-troubleshooting)
- [📈 Status & Progress](#-status--progress)
- [🤝 Contributing](#-contributing)
- [📄 License](#-license)
- [📋 Appendix: Complete Original README](#-appendix-complete-original-readme)

---

## 🚀 Quick Start

Get up and running quickly with these essential commands:

```bash
# Check if everything is set up
./scripts/test-quick-check.sh

# Run iOS tests (super easy!)
./scripts/run-ios-tests.sh

# Run backend tests
npm test
```

**New to testing?** See [`RUN_TESTS_NOW.md`](./RUN_TESTS_NOW.md) for the fastest way to get started!

### Quick Links

- **[handover.md](./handover.md)** - Complete codebase guide for new engineers (architecture, file reference, UI mockups)
- **[RUN_TESTS_NOW.md](./RUN_TESTS_NOW.md)** - Quick testing guide (copy & paste commands)
- **[TESTING_QUICK_START.md](./TESTING_QUICK_START.md)** - Detailed testing guide for iOS and backend
- **[SECURITY_AUDIT.md](./SECURITY_AUDIT.md)** - Security audit and penetration testing guide
- **[docs/SECURITY_FIXES.md](./docs/SECURITY_FIXES.md)** - Known security vulnerabilities and fixes

---

## 📖 Overview

VibeZ is a real-time chat and communication platform backend built with TypeScript/Node.js, Express, and WebSockets. The platform provides:

- **Real-time messaging** via WebSocket connections with protobuf-encoded messages
- **HTTP REST API** for room management, user data, moderation, subscriptions, and more
- **Authentication & Authorization** via Supabase JWT tokens with role-based access control
- **Voice & Video** integration via Agora and LiveKit for real-time communication
- **Moderation & Safety** with automated content filtering, rate limiting, and admin tools
- **Privacy & Security** with end-to-end encryption, GDPR compliance, and zero-knowledge proofs
- **Scalability** with Redis clustering, connection pooling, and horizontal scaling support
- **Performance** with Redis caching, query optimization, and stress testing infrastructure

---

## ✨ Key Features

- 🔐 **Secure Authentication** - Supabase JWT-based authentication with role-based access control
- 💬 **Real-time Messaging** - WebSocket-based messaging with protobuf encoding
- 🎥 **Voice & Video** - Integrated Agora and LiveKit support
- 🛡️ **Moderation Tools** - Automated content filtering and admin moderation capabilities
- 🔒 **Privacy First** - End-to-end encryption, GDPR compliance, zero-knowledge proofs, hardware-accelerated encryption
- ⚡ **High Performance** - Redis caching, connection pooling, query optimization, horizontal scaling
- 📊 **Monitoring** - Prometheus metrics, comprehensive telemetry, stress testing infrastructure
- 🧪 **Stress Test Ready** - Built-in load testing scripts for WebSocket and API performance

---

## 📁 Project Structure

```
VibeZ/
├── apps/                    # Application packages
│   └── api/                 # API application
├── frontend/                # Frontend applications
│   └── iOS/                 # iOS application
├── packages/                # Shared packages
│   ├── ai-mod/              # AI moderation package
│   ├── core/                # Core shared utilities
│   └── supabase/            # Supabase integration
├── server/                  # Server code
├── src/                     # Main source code
│   ├── config/              # Configuration files
│   ├── middleware/          # Express middleware
│   ├── routes/              # API route handlers
│   ├── services/            # Business logic services
│   ├── telemetry/           # Telemetry and monitoring
│   ├── tests/               # Test files
│   ├── types/               # TypeScript type definitions
│   ├── utils/               # Utility functions
│   ├── workers/             # Background workers
│   └── ws/                  # WebSocket handlers
├── sql/                     # Database migrations and SQL
├── scripts/                 # Utility scripts
├── docs/                    # Documentation
├── cypress/                 # E2E tests
└── infra/                   # Infrastructure as code
```

For detailed architecture and file reference, see [handover.md](./handover.md).

---

## 🛠️ Installation & Setup

### Prerequisites

- Node.js (v20+)
- npm or yarn
- PostgreSQL (via Supabase)
- Redis
- Docker (for validation/testing)

### Setup Steps

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd VibeZ
   ```

2. **Install dependencies**
   ```bash
   npm install
   ```

3. **Set up environment variables**
   ```bash
   cp env.template .env
   # Edit .env with your configuration
   ```

4. **Set up database**
   ```bash
   # Run SQL migrations
   # See sql/ directory for migration files
   ```

5. **Set up validation database (optional)**
   ```bash
   ./scripts/setup-validation-db.sh
   ```

---

## 🏃 Running the Project

### Development Mode

```bash
# Start all services
npm run dev

# Start specific workspace
turbo dev --filter=api
```

### Production Build

```bash
# Build all packages
npm run build

# Type check
npm run typecheck

# Lint
npm run lint
```

### Server Entry Points

- **Main Server**: `src/http-websocket-server.ts` - Express HTTP server and WebSocket gateway
- **Legacy Socket.IO**: `server/socketio-stub-server.ts` - Socket.IO stub server (may be deprecated)

---

## 🧪 Testing

### Quick Test Commands

```bash
# Quick setup check
./scripts/test-quick-check.sh

# Run iOS tests
./scripts/run-ios-tests.sh

# Run backend tests
npm test

# Run tests in watch mode
npm run test:watch

# Run with coverage
npm run test:coverage

# Run E2E tests
npm run test:e2e

# Run E2E auth flow tests
npm run test:e2e:auth

# Run full auth E2E tests
npm run test:e2e:auth:full
```

### Testing Documentation

- **[RUN_TESTS_NOW.md](./RUN_TESTS_NOW.md)** - Quick testing guide with copy-paste commands
- **[TESTING_QUICK_START.md](./TESTING_QUICK_START.md)** - Comprehensive testing guide
  - iOS testing (3 methods)
  - Backend testing
  - Troubleshooting tips

### Test Coverage

- **Backend**: 83 tests passing (target: 60% coverage)
- **iOS**: 10 login tests, 17 tests skipped for unimplemented features (target: 40% coverage)
- **E2E**: Cypress tests for auth flow

---

## 🚀 Deployment

### Docker

```bash
# Build Docker image
docker build -t vibez .

# Run with docker-compose
docker-compose up -d

# Validation docker setup
npm run validate:docker:full
```

### Infrastructure

Infrastructure as code is available in `infra/aws/`:
- Terraform configurations
- AWS deployment scripts
- User data scripts

---

## 🔧 Configuration

### Environment Variables

Copy `env.template` to `.env` and configure:

- Database connection (Supabase)
- Redis configuration
- JWT secrets
- API keys (Agora, LiveKit)
- Security settings

### Validation

```bash
# Validate phases 1-3
npm run validate:phases-1-3

# Run all validations
./scripts/run-all-validations.sh

# Docker validation
npm run validate:docker:full
```

---

## 🔒 Security

### Security Status

- ✅ **js-yaml vulnerability** - Fixed with `npm audit fix`
- ⚠️ **csurf cookie vulnerability** - Low severity, requires breaking change
- ⚠️ **esbuild/vitest vulnerabilities** - Dev dependencies only
- ✅ **git-secrets setup** - Script created for secret detection

### Security Documentation

- **[SECURITY_AUDIT.md](./SECURITY_AUDIT.md)** - Security audit process and penetration testing guide
- **[docs/SECURITY_FIXES.md](./docs/SECURITY_FIXES.md)** - Known vulnerabilities and fixes
- **[docs/RLS_SECURITY_SUMMARY.md](./docs/RLS_SECURITY_SUMMARY.md)** - Row-Level Security audit (50+ tables, 100+ policies)

### Security Features

- Row-Level Security (RLS) policies on all tables
- CSRF protection (Helmet middleware)
- Rate limiting
- Input validation and sanitization
- End-to-end encryption support
- GDPR compliance features

---

## 📚 Documentation

### Essential Reading

1. **[handover.md](./handover.md)** - Complete codebase guide
   - Architecture overview
   - File reference (all 167+ TypeScript files documented)
   - Web and iOS UI mockups
   - Perfect for onboarding new engineers

2. **[RUN_TESTS_NOW.md](./RUN_TESTS_NOW.md)** - Quick testing commands
   - Copy & paste commands to run tests
   - No Xcode knowledge required

3. **[TESTING_QUICK_START.md](./TESTING_QUICK_START.md)** - Comprehensive testing guide
   - iOS testing (3 methods)
   - Backend testing
   - Troubleshooting tips

### Security

- **[SECURITY_AUDIT.md](./SECURITY_AUDIT.md)** - Security audit process and penetration testing guide
- **[docs/SECURITY_FIXES.md](./docs/SECURITY_FIXES.md)** - Known vulnerabilities and fixes
  - csurf cookie vulnerability (low severity, requires breaking change)
  - esbuild/vitest vulnerabilities (dev dependencies only)
  - js-yaml fixed with `npm audit fix`

### Database & Infrastructure

- **[docs/RLS_SECURITY_SUMMARY.md](./docs/RLS_SECURITY_SUMMARY.md)** - Row-Level Security audit (50+ tables, 100+ policies)
- **[docs/SQL_OPTIMIZATION_QUICK_START.md](./docs/SQL_OPTIMIZATION_QUICK_START.md)** - SQL optimization quick start guide
- **[docs/SQL_AUDIT_AND_OPTIMIZATION.md](./docs/SQL_AUDIT_AND_OPTIMIZATION.md)** - Comprehensive SQL audit and optimization report
- **[REDIS_CLUSTERING_SUMMARY.md](./REDIS_CLUSTERING_SUMMARY.md)** - Redis clustering implementation

### Reference

- **[CODEBASE_QUICKREF.md](./CODEBASE_QUICKREF.md)** - Codebase statistics and quick reference
- **[docs/READING_GUIDE.md](./docs/READING_GUIDE.md)** - Guide to understanding VibeZ development state

### Archived Documentation

Historical documentation, completion summaries, and old test reports have been archived to `docs/archive/historical/` for reference.

---

## 🐛 Troubleshooting

### Common Issues

1. **iOS tests need app launch debugging**
   - See `docs/TEST_RESULTS_SUMMARY.md` for details

2. **Test failures**
   - Run `./scripts/test-quick-check.sh` to verify setup
   - Check [TESTING_QUICK_START.md](./TESTING_QUICK_START.md) for troubleshooting tips

3. **Database connection issues**
   - Verify Supabase configuration in `.env`
   - Check SQL migrations in `sql/` directory

4. **WebSocket connection issues**
   - Verify Redis is running
   - Check WebSocket gateway configuration

---

## 📈 Status & Progress

**Last Updated:** November 18, 2025

### Backend Status

- ✅ WebSocket reconnection enhancement fully implemented
- ✅ 24/24 backend reconnection tests passing
- ✅ Authentication service: 25 tests passing
- ✅ RLS policies & DB security validated
- ⚠️ Security vulnerabilities identified (see [docs/SECURITY_FIXES.md](./docs/SECURITY_FIXES.md))
- 🔄 Test coverage expansion in progress (83 tests passing total)

### iOS Status

- ✅ Accessibility identifiers added to LoginView
- ✅ UI tests updated (10 login tests, 17 tests skipped for unimplemented features)
- ✅ Automated test scripts created
- ⚠️ iOS tests need app launch debugging (see `docs/TEST_RESULTS_SUMMARY.md`)
- 🔄 Test coverage expansion in progress

### Database Status

- ✅ RLS hardened, policies triple-reviewed

### Security Status

- ✅ js-yaml vulnerability fixed (npm audit fix)
- ⚠️ csurf cookie vulnerability (low severity, requires breaking change)
- ⚠️ esbuild/vitest vulnerabilities (dev dependencies only)
- ✅ git-secrets setup script created

### Documentation Status

- ✅ Comprehensive testing guides created
- ✅ Automated test scripts (run-ios-tests.sh, test-quick-check.sh)
- ✅ Easy-to-follow documentation for new developers
- ✅ Codebase refactored for clarity (see [handover.md](./handover.md))
- ✅ All historical docs archived to `docs/archive/historical/`

### Next Steps

- Debug iOS test launch issue (see `docs/TEST_RESULTS_SUMMARY.md`)
- Expand backend test coverage (target: 60%)
- Expand iOS test coverage (target: 40%)
- Address csurf deprecation (migrate to modern CSRF protection)
- Perform cross-platform integration testing

---

## 🤝 Contributing

### Development Workflow

1. Create a feature branch
2. Make your changes
3. Run tests: `npm test`
4. Run linting: `npm run lint`
5. Run type checking: `npm run typecheck`
6. Submit a pull request

### Code Style

- TypeScript with strict type checking
- ESLint for code quality
- Prettier for formatting
- Husky for git hooks

### Testing Requirements

- Write tests for new features
- Maintain or improve test coverage
- Run all tests before submitting PR

---

## 📄 License

See [LICENSE](./LICENSE) for details.

---

## 📋 Appendix: Complete Original README

<details>
<summary>Click to expand original README content</summary>

```markdown
---
## License

See [LICENSE](./LICENSE) for details.
---

## Quick Links

- **[handover.md](./handover.md)** - Complete codebase guide for new engineers (architecture, file reference, UI mockups)
- **[RUN_TESTS_NOW.md](./RUN_TESTS_NOW.md)** - Quick testing guide (copy & paste commands)
- **[TESTING_QUICK_START.md](./TESTING_QUICK_START.md)** - Detailed testing guide for iOS and backend
- **[SECURITY_AUDIT.md](./SECURITY_AUDIT.md)** - Security audit and penetration testing guide
- **[docs/SECURITY_FIXES.md](./docs/SECURITY_FIXES.md)** - Known security vulnerabilities and fixes

---

## Current Status (Nov 18, 2025)

**Backend:**

- ✅ WebSocket reconnection enhancement fully implemented
- ✅ 24/24 backend reconnection tests passing
- ✅ Authentication service: 25 tests passing
- ✅ RLS policies & DB security validated
- ⚠️ Security vulnerabilities identified (see docs/SECURITY_FIXES.md)
- 🔄 Test coverage expansion in progress (83 tests passing total)

**iOS:**

- ✅ Accessibility identifiers added to LoginView
- ✅ UI tests updated (10 login tests, 17 tests skipped for unimplemented features)
- ✅ Automated test scripts created
- ⚠️ iOS tests need app launch debugging (see docs/TEST_RESULTS_SUMMARY.md)
- 🔄 Test coverage expansion in progress

**Database:**

- ✅ RLS hardened, policies triple-reviewed

**Security:**

- ✅ js-yaml vulnerability fixed (npm audit fix)
- ⚠️ csurf cookie vulnerability (low severity, requires breaking change)
- ⚠️ esbuild/vitest vulnerabilities (dev dependencies only)
- ✅ git-secrets setup script created

**Documentation:**

- ✅ Comprehensive testing guides created
- ✅ Automated test scripts (run-ios-tests.sh, test-quick-check.sh)
- ✅ Easy-to-follow documentation for new developers
- ✅ Codebase refactored for clarity (see [handover.md](./handover.md))
- ✅ All historical docs archived to `docs/archive/historical/`

**Next Steps:**

- Debug iOS test launch issue (see docs/TEST_RESULTS_SUMMARY.md)
- Expand backend test coverage (target: 60%)
- Expand iOS test coverage (target: 40%)
- Address csurf deprecation (migrate to modern CSRF protection)
- Perform cross-platform integration testing

**Quick Test Commands:**

```bash
# Check if everything is set up
./scripts/test-quick-check.sh

# Run iOS tests (super easy!)
./scripts/run-ios-tests.sh

# Run backend tests
npm test
```

**New to testing?** See `RUN_TESTS_NOW.md` for the fastest way to get started!

---

## Documentation

### Essential Reading

1. **[handover.md](./handover.md)** - Complete codebase guide
   - Architecture overview
   - File reference (all 167+ TypeScript files documented)
   - Web and iOS UI mockups
   - Perfect for onboarding new engineers

2. **[RUN_TESTS_NOW.md](./RUN_TESTS_NOW.md)** - Quick testing commands
   - Copy & paste commands to run tests
   - No Xcode knowledge required

3. **[TESTING_QUICK_START.md](./TESTING_QUICK_START.md)** - Comprehensive testing guide
   - iOS testing (3 methods)
   - Backend testing
   - Troubleshooting tips

### Security

- **[SECURITY_AUDIT.md](./SECURITY_AUDIT.md)** - Security audit process and penetration testing guide
- **[docs/SECURITY_FIXES.md](./docs/SECURITY_FIXES.md)** - Known vulnerabilities and fixes
  - csurf cookie vulnerability (low severity, requires breaking change)
  - esbuild/vitest vulnerabilities (dev dependencies only)
  - js-yaml fixed with `npm audit fix`

### Database & Infrastructure

- **[docs/RLS_SECURITY_SUMMARY.md](./docs/RLS_SECURITY_SUMMARY.md)** - Row-Level Security audit (50+ tables, 100+ policies)
- **[docs/SQL_OPTIMIZATION_QUICK_START.md](./docs/SQL_OPTIMIZATION_QUICK_START.md)** - SQL optimization quick start guide
- **[docs/SQL_AUDIT_AND_OPTIMIZATION.md](./docs/SQL_AUDIT_AND_OPTIMIZATION.md)** - Comprehensive SQL audit and optimization report
- **[REDIS_CLUSTERING_SUMMARY.md](./REDIS_CLUSTERING_SUMMARY.md)** - Redis clustering implementation

### Reference

- **[CODEBASE_QUICKREF.md](./CODEBASE_QUICKREF.md)** - Codebase statistics and quick reference
- **[docs/READING_GUIDE.md](./docs/READING_GUIDE.md)** - Guide to understanding VibeZ development state

### Archived Documentation

Historical documentation, completion summaries, and old test reports have been archived to `docs/archive/historical/` for reference.

---

**Last updated:** November 18, 2025
```

</details>

---

**Last updated:** November 18, 2025
