# VibeZ

**Real-time communication platform with AI-powered sentiment analysis**

VibeZ is an enterprise-grade real-time messaging platform focused on meaningful conversations and emotional connection. Built with TypeScript, Express, WebSockets, and Supabase, VibeZ combines instant messaging with real-time sentiment analysis to help users understand conversation dynamics, emotional intensity, and create lasting memories through collectible digital cards.

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Getting Started](#getting-started)
- [Development](#development)
- [Testing](#testing)
- [Deployment](#deployment)
- [Security & Compliance](#security--compliance)
- [API Documentation](#api-documentation)
- [Contributing](#contributing)
- [License](#license)

---

## Overview

VibeZ enables users to:

- **Real-time messaging** with WebSocket-based instant communication
- **AI-powered sentiment analysis** that analyzes conversation dynamics in real-time
- **Emotional intelligence** tracking sentiment, emotional intensity, and conversation patterns
- **Collectible card generation** from meaningful conversations (sentiment-based, non-tradeable)
- **Digital museum** to showcase and discover conversation cards
- **Voice & video** calls via LiveKit and Agora integration with Perfect Forward Secrecy
- **Privacy-first** design with GDPR/CCPA compliance

### Key Features

- **Real-time Sentiment Chat**: WebSocket-based messaging with live sentiment analysis and emotional tracking
- **AI-Powered Sentiment Analysis**: Real-time analysis of conversation sentiment, emotional intensity, and dynamics
- **VIBES Cards**: AI-generated collectible cards from meaningful conversations based on sentiment, rarity, and emotional intensity
- **Conversation Intelligence**: Understand conversation patterns, emotional peaks, and meaningful moments
- **Moderation**: AI-powered content moderation with Perspective API and DeepSeek integration
- **Voice/Video**: LiveKit and Agora integration for voice and video calls with Perfect Forward Secrecy
- **Privacy**: End-to-end encryption, PII encryption at rest, GDPR/CCPA compliance
- **Zero-Knowledge Proofs**: Selective disclosure for user profiles without revealing actual data
- **Hardware-Accelerated Encryption**: AES-256-GCM with AES-NI hardware acceleration
- **Perfect Forward Secrecy**: Ephemeral keys for media streams ensuring past calls remain secure
- **Scalability**: Designed for high concurrency with WebSocket clustering and Redis pub/sub

---

## Architecture

### System Components

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   iOS Client    │     │   Web Client     │     │  Admin Portal   │
│   (Swift)       │────▶│   (Next.js)      │────▶│   (Next.js)     │
└─────────────────┘     └─────────────────┘     └─────────────────┘
         │                       │                       │
         └──────────────────────┼──────────────────────┘
                                 │
                    ┌────────────▼────────────┐
                    │   Express API Server    │
                    │   (TypeScript/Node.js)  │
                    └────────────┬────────────┘
                                 │
         ┌───────────────────────┼───────────────────────┐
         │                       │                       │
┌────────▼────────┐   ┌─────────▼─────────┐   ┌─────────▼─────────┐
│   WebSocket     │   │   Supabase        │   │   Redis           │
│   Gateway       │   │   PostgreSQL      │   │   Pub/Sub & Cache │
└─────────────────┘   └───────────────────┘   └───────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌────────────▼────────────┐
                    │   External Services    │
                    │  - OpenAI/DALL-E       │
                    │  - Perspective API     │
                    │  - LiveKit/Agora       │
                    └────────────────────────┘
```

### Core Services

- **API Server**: Express.js server handling HTTP requests and WebSocket connections
- **WebSocket Gateway**: Real-time messaging and presence updates
- **Database**: Supabase PostgreSQL with Row Level Security (RLS) policies
- **Cache**: Redis for caching, pub/sub, and rate limiting
- **AI Services**: OpenAI for sentiment analysis and DALL-E for card generation
- **Moderation**: Perspective API and DeepSeek for content moderation

---

## Tech Stack

### Backend

- **Runtime**: Node.js 20+
- **Framework**: Express.js 5.x
- **Language**: TypeScript 5.9
- **Database**: PostgreSQL (via Supabase)
- **Cache/Pub-Sub**: Redis 7+
- **WebSockets**: ws (native WebSocket library)
- **Authentication**: JWT with refresh token rotation
- **Monitoring**: Prometheus metrics

### Frontend

- **iOS**: Swift, SwiftUI
- **Web**: Next.js 16, React 19, TypeScript
- **Real-time**: Socket.io client, LiveKit client

### Infrastructure

- **Database**: Supabase (PostgreSQL)
- **File Storage**: AWS S3 (optional)
- **Voice/Video**: LiveKit, Agora
- **AI**: OpenAI API, DALL-E API, Perspective API
- **Monitoring**: Prometheus, Grafana (planned)

### Development Tools

- **Build System**: Turbo (monorepo)
- **Package Manager**: npm
- **Testing**: Vitest
- **Linting**: ESLint
- **Formatting**: Prettier

---

## Project Structure

```
VibeZ/
├── server/                 # Express API server
│   ├── index.ts            # Server entry point
│   └── package.json
├── src/
│   ├── server/             # Server configuration
│   │   └── index.ts        # Main Express app
│   ├── routes/             # API route handlers
│   │   ├── user-authentication-routes.ts
│   │   ├── message-routes.ts
│   │   ├── vibes/          # VIBES feature routes
│   │   └── ...
│   ├── services/           # Business logic services
│   │   ├── message-service.ts
│   │   ├── moderation.service.ts
│   │   ├── vibes/          # VIBES feature services
│   │   └── ...
│   ├── middleware/          # Express middleware
│   │   ├── auth.ts
│   │   ├── rate-limiter.ts
│   │   └── ...
│   ├── ws/                 # WebSocket handlers
│   │   ├── gateway.ts
│   │   └── handlers/
│   ├── jobs/               # Background jobs
│   │   ├── partition-management-cron.ts
│   │   └── ...
│   ├── config/             # Configuration
│   │   ├── vibes.config.ts
│   │   └── ...
│   └── tests/              # Test files
├── frontend/
│   └── iOS/                # iOS Swift application
│       ├── Views/
│       ├── Services/
│       ├── Models/
│       └── ...
├── v-app/                   # Next.js web application
│   ├── app/
│   └── package.json
├── sql/                     # Database schema and migrations
│   ├── migrations/
│   └── ...
├── scripts/                 # Utility scripts
├── specs/                   # API specifications
│   └── api/
│       └── openapi.yaml
├── docker-compose.yml       # Local development setup
├── BUILD.plan              # Unified build plan (see below)
└── README.md               # This file
```

---

## Getting Started

### Prerequisites

- **Node.js**: 20.x or higher
- **npm**: 9.x or higher
- **PostgreSQL**: 14+ (or Supabase account)
- **Redis**: 7+ (for local development)
- **TypeScript**: 5.9+

### Environment Setup

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
   ```

   Edit `.env` and configure:
   - `NEXT_PUBLIC_SUPABASE_URL`: Your Supabase project URL
   - `SUPABASE_SERVICE_ROLE_KEY`: Your Supabase service role key
   - `JWT_SECRET`: Generate a secure random string
   - `REDIS_URL`: Redis connection URL (default: `redis://localhost:6379`)
   - `OPENAI_API_KEY`: OpenAI API key (for AI features)
   - `DALL_E_API_KEY`: DALL-E API key (for card generation)
   - `PERSPECTIVE_API_KEY`: Perspective API key (for moderation)
   - `LIVEKIT_URL`, `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET`: LiveKit credentials (optional)
   - `AGORA_APP_ID`, `AGORA_APP_CERTIFICATE`: Agora credentials (optional)

4. **Set up the database**

   ```bash
   # Run migrations in Supabase SQL editor or via CLI
   # See sql/migrations/ for migration files
   ```

5. **Start Redis** (if running locally)
   ```bash
   redis-server
   ```

### Running Locally

**Start all services** (using Turbo):

```bash
npm run dev
```

**Start individual services**:

```bash
# API server only
cd server
npm run dev

# Web app only
cd v-app
npm run dev
```

**Using Docker Compose**:

```bash
docker-compose up
```

The API server will be available at `http://localhost:3000`

---

## Development

### Monorepo Structure

VibeZ uses Turbo for monorepo management. Workspaces include:

- `server/`: Express API server
- `v-app/`: Next.js web application
- `packages/core/`: Shared core utilities
- `packages/supabase/`: Supabase client utilities

### Available Scripts

**Root level**:

- `npm run dev`: Start all services in development mode
- `npm run build`: Build all packages
- `npm run test`: Run all tests
- `npm run lint`: Lint all packages
- `npm run typecheck`: Type check all packages

**Server** (`server/`):

- `npm run dev`: Start server with hot reload
- `npm run build`: Compile TypeScript to JavaScript
- `npm start`: Start production server
- `npm run lint`: Lint server code

**Web App** (`v-app/`):

- `npm run dev`: Start Next.js dev server
- `npm run build`: Build for production
- `npm start`: Start production server

### Code Style

- **TypeScript**: Strict mode enabled
- **Linting**: ESLint with TypeScript rules
- **Formatting**: Prettier (run `npm run format`)

### Database Migrations

Migrations are located in `sql/migrations/`. To create a new migration:

1. Create a new file: `sql/migrations/YYYY-MM-DD-description.sql`
2. Add your SQL changes
3. Run the migration in Supabase SQL editor or via CLI

### WebSocket Development

WebSocket handlers are in `src/ws/handlers/`. The gateway is configured in `src/ws/gateway.ts`.

Test WebSocket connections:

```bash
# Using wscat
wscat -c ws://localhost:3000
```

---

## Testing

### Running Tests

```bash
# Run all tests
npm test

# Run tests in watch mode
npm run test:watch

# Run tests with coverage
npm run test:coverage
```

### Test Structure

- **Unit Tests**: `src/services/__tests__/`, `src/middleware/__tests__/`
- **Integration Tests**: `src/tests/`
- **E2E Tests**: Planned (see BUILD.plan)
- **Phase Validation**: `scripts/validate-phases-1-3.ts` - Validates phases 1-3 completion

### Phase 1-3 Validation

Validate that phases 1, 2, and 3 are complete:

**Using Docker (Recommended - Self-contained environment)**:

```bash
# Full validation with Docker containers (PostgreSQL + Redis)
npm run validate:docker:full

# Or step by step:
npm run validate:docker:up      # Start containers
npm run validate:docker:setup   # Initialize database
npm run validate:docker:run     # Run validations
npm run validate:docker:down    # Stop containers
```

**Using Existing Database**:

```bash
# Quick start (all validations)
npm run validate:phases-1-3:all

# Or individual scripts
npm run validate:phases-1-3  # TypeScript validation
psql $DATABASE_URL -f sql/validate-phases-1-3.sql  # SQL validation
```

**What gets validated:**

- Phase 1: Security & Authentication (token rotation, password security, RBAC, brute-force protection, HTTPS/TLS)
- Phase 2: WebSocket & Messaging (rate limiting, connection health, delivery acks, scaling)
- Phase 3: Database & Performance (indexes, pagination, archival, caching)

See `VALIDATION_QUICK_START.md` and `VALIDATION_DOCKER.md` for detailed instructions.

### Writing Tests

Tests use Vitest. Example:

```typescript
import { describe, it, expect } from 'vitest';
import { myFunction } from '../my-service';

describe('myFunction', () => {
  it('should do something', () => {
    expect(myFunction()).toBe(expected);
  });
});
```

---

## Deployment

### Production Checklist

Before deploying to production:

- [ ] Set all required environment variables
- [ ] Run database migrations
- [ ] Configure Redis for production
- [ ] Set up monitoring (Prometheus/Grafana)
- [ ] Configure HTTPS/TLS certificates
- [ ] Set up error alerting (Slack/PagerDuty)
- [ ] Enable rate limiting
- [ ] Configure CORS for production domains
- [ ] Set up backup strategy for database
- [ ] Review security settings (see Security section)

### Environment Variables

See `env.template` for all available environment variables. Production-specific variables:

- `NODE_ENV=production`
- `JWT_SECRET`: Must be a secure random string (32+ bytes)
- `SUPABASE_SERVICE_ROLE_KEY`: Supabase service role key
- `REDIS_URL`: Production Redis URL
- `OPENAI_API_KEY`: OpenAI API key
- `DALL_E_API_KEY`: DALL-E API key
- `PERSPECTIVE_API_KEY`: Perspective API key

### Docker Deployment

Build and run with Docker:

```bash
docker build -t vibez-api .
docker run -p 3000:3000 --env-file .env vibez-api
```

### Infrastructure

Infrastructure as Code is in `infra/aws/` (Terraform). See `infra/aws/README.md` for deployment instructions.

---

## Security & Compliance

### Security Features

- **Authentication**: JWT with refresh token rotation
- **Authorization**: Role-based access control (RBAC)
- **Encryption**: PII encryption at rest, end-to-end encryption for messages
- **Hardware-Accelerated Encryption**: AES-256-GCM with automatic AES-NI detection (10-100x faster)
- **Perfect Forward Secrecy**: Ephemeral ECDH keys for media streams, deleted after call ends
- **Zero-Knowledge Proofs**: Selective disclosure for user attributes without revealing values
- **Rate Limiting**: Per-user and per-IP rate limiting
- **Brute-Force Protection**: Account lockout after failed attempts
- **Content Moderation**: AI-powered toxicity detection
- **Security Headers**: HSTS, CSP, X-Frame-Options
- **CSRF Protection**: CSRF tokens for state-changing requests

### Compliance

- **GDPR**: Data export and deletion endpoints (`/api/users/{id}/data`)
- **CCPA**: Similar data rights as GDPR
- **Data Retention**: Configurable retention policies
- **Audit Logging**: Comprehensive audit logs for security events

### Security Best Practices

1. **Never commit secrets**: Use environment variables or vault
2. **Rotate tokens regularly**: Refresh tokens rotate on use
3. **Monitor for anomalies**: Set up alerts for suspicious activity
4. **Keep dependencies updated**: Regularly update npm packages
5. **Review access logs**: Monitor authentication and authorization events

### Reporting Security Issues

Report security vulnerabilities to: [security@vibez.app] (see `/.well-known/security.txt`)

---

## API Documentation

### OpenAPI Specification

API documentation is available in OpenAPI 3.0 format:

- **File**: `specs/api/openapi.yaml`
- **View**: Host Swagger UI at `/api/docs` (planned)

### Key Endpoints

**Authentication**:

- `POST /auth/apple` - Apple Sign-In
- `POST /auth/google` - Google Sign-In
- `POST /auth/login` - Email/password login
- `POST /auth/refresh` - Refresh access token

**Messaging**:

- `POST /messaging/send` - Send message
- `GET /messaging/:roomId` - Get messages for room

**VIBES**:

- `GET /vibes/conversations` - List conversations
- `POST /vibes/conversations` - Create conversation
- `GET /vibes/cards` - Get user's cards
- `POST /vibes/cards/:id/claim` - Claim card
- `GET /vibes/museum` - Browse museum

**Admin**:

- `GET /admin/moderation/queue` - Get moderation queue
- `POST /admin/moderation/review/:id` - Review flagged message

**User Data** (GDPR/CCPA):

- `GET /api/users/:id/data` - Export user data
- `DELETE /api/users/:id/data` - Delete user data

**Privacy** (Zero-Knowledge Proofs & Encryption):

- `POST /api/privacy/selective-disclosure` - Generate ZKP proofs for selective disclosure
- `POST /api/privacy/verify-disclosure` - Verify selective disclosure proofs
- `GET /api/privacy/encryption-status` - Get hardware acceleration status
- `GET /api/privacy/zkp/commitments/:userId` - Get stored proof commitments

### WebSocket Events

**Client → Server**:

- `message:send` - Send message
- `presence:update` - Update presence status
- `typing:start` - Start typing indicator
- `typing:stop` - Stop typing indicator

**Server → Client**:

- `message:new` - New message received
- `message:delivered` - Message delivery confirmation
- `presence:update` - Presence status update
- `error` - Error notification

---

## Build Plan

For a comprehensive list of remaining work items, implementation tasks, and roadmap, see **[BUILD.plan](./BUILD.plan)**.

The build plan includes:

- Security & authentication hardening ✅
- WebSocket & messaging optimization ✅
- Database & performance improvements ✅
- AI & VIBES features integration (in progress)
- Moderation & safety enhancements
- Observability & operations
- Testing & quality assurance
- Privacy & compliance
- Performance & scalability
- Documentation & developer experience

---

## Documentation

### Main Documentation

- **[BUILD.plan](./BUILD.plan)** - Complete implementation roadmap
- **[CODEBASE_COMPLETE.md](./CODEBASE_COMPLETE.md)** - Comprehensive codebase documentation
- **[Execution Plan](./docs/execution/COMPLETE_EXECUTION_PLAN.md)** - Parallel execution strategy for Phases 4-10

### Privacy & Security

- **[Privacy Implementation Summary](./docs/PRIVACY_IMPLEMENTATION_SUMMARY.md)** - Zero-knowledge proofs, hardware acceleration, and PFS
- **[Privacy Validation Report](./docs/PRIVACY_VALIDATION_REPORT.md)** - Privacy features validation results
- **[Privacy Enhancements](./docs/PRIVACY_ENHANCEMENTS.md)** - Detailed privacy feature documentation

### Validation & Testing

- **[Validation Summary](./docs/validation/VALIDATION_SUMMARY.md)** - Validation suite overview
- **[Validation Checklist](./docs/validation/VALIDATION_CHECKLIST.md)** - Manual validation procedures
- **[Docker Setup](./docs/validation/DOCKER_SETUP.md)** - Docker validation environment
- **[Test Results](./docs/validation/TEST_RESULTS.md)** - Latest test results

### Other Documentation

- **[Security Audit](./SECURITY_AUDIT.md)** - Security assessment
- **[Codebase Quick Reference](./CODEBASE_QUICKREF.md)** - Quick reference guide

---

## Contributing

### Development Workflow

1. Create a feature branch from `main`
2. Make your changes
3. Write/update tests
4. Ensure all tests pass (`npm test`)
5. Ensure linting passes (`npm run lint`)
6. Submit a pull request

### Code Review

All code changes require review before merging. Reviewers will check:

- Code quality and style
- Test coverage
- Security implications
- Performance impact

---

## License

See [LICENSE](./LICENSE) for details.

---

## Support

- **Documentation**: See `BUILD.plan` for implementation details
- **Issues**: Report bugs via GitHub Issues
- **Security**: Report vulnerabilities to security@vibez.app

---

---

## Privacy & Security Enhancements

### Zero-Knowledge Proofs (ZKPs)

VibeZ implements zero-knowledge proofs for selective profile disclosure, allowing users to prove attributes (age, verification status, subscription tier) without revealing actual values.

**Features**:

- Commitment-based proofs stored in database
- Selective disclosure - prove only requested attributes
- Non-replay protection via timestamps and nonces
- API endpoints for proof generation and verification

**Usage**:

```typescript
// Generate proof
POST /api/privacy/selective-disclosure
{
  "attributeTypes": ["age", "verified"],
  "purpose": "Age verification"
}

// Verify proof
POST /api/privacy/verify-disclosure
{
  "disclosureProof": { ... },
  "expectedCommitments": { ... }
}
```

### Hardware-Accelerated Encryption

Automatic detection and use of AES-NI hardware acceleration for AES-256-GCM encryption, providing 10-100x performance improvement with graceful fallback to software encryption.

**Features**:

- Automatic AES-NI detection
- Hardware-accelerated AES-256-GCM encryption
- Transparent integration - no code changes needed
- Performance benchmarking

**Status Check**:

```bash
GET /api/privacy/encryption-status
```

### Perfect Forward Secrecy (PFS)

Media streams (voice/video calls) use Perfect Forward Secrecy with ephemeral ECDH keys, ensuring that even if long-term keys are compromised, past calls remain secure.

**Features**:

- Ephemeral key pairs per call session (ECDH)
- Shared secret derivation using HKDF
- Hardware-accelerated media encryption
- Automatic key cleanup after call ends

**Security Properties**:

- Each call gets unique ephemeral keys
- Keys deleted immediately after call ends
- Past calls remain secure even if long-term keys compromised
- Media streams encrypted with hardware-accelerated AES-256-GCM

For detailed documentation, see [Privacy Implementation Summary](./docs/PRIVACY_IMPLEMENTATION_SUMMARY.md).

---

**Last Updated**: 2025-01-XX
