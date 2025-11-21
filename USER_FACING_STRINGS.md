# User-Facing Strings Audit
**Generated:** 2025-11-20
**Purpose:** Copy-editing reference for all user-visible text in the application

---

## 📋 How to Use This Document
- **File:Line** - Exact location of the string
- **Context** - What triggers this text (error, button, etc.)
- **String** - The actual text shown to users
- ✏️ **Edit directly in the source files**, then update this document

---

## 🔐 Authentication & Authorization

### `/src/middleware/auth/supabase-auth-middleware.ts`

| Line | Context | String |
|------|---------|--------|
| 24 | Error - Missing config | "Missing Supabase credentials. Set SUPABASE_URL and SUPABASE_ANON_KEY" |
| 30 | Error - Server config | "Server configuration error" |
| 53 | Error - Auth failed | "Invalid token" |
| 72 | Error - Auth failed | "Invalid token" |

### `/src/middleware/auth/admin-auth-middleware.ts`

| Line | Context | String |
|------|---------|--------|
| 155 | Error - No auth | "Authentication required" |
| 157 | Error - No permission | "Admin access required" |
| 163 | Error - Server error | "Authorization check failed" |
| 176 | Error - No auth | "Authentication required" |
| 180 | Error - No permission | "Moderator access required" |
| 186 | Error - Server error | "Authorization check failed" |
| 199 | Error - No auth | "Authentication required" |
| 203 | Error - No permission | "Owner access required" |
| 209 | Error - Server error | "Authorization check failed" |
| 226 | Error - No auth | "Authentication required" |
| 230 | Error - No permission | "Permission required: {permission}" |
| 236 | Error - Server error | "Authorization check failed" |

---

## 🛡️ Security & Moderation

### `/src/middleware/security/brute-force-protection-middleware.ts`

| Line | Context | String |
|------|---------|--------|
| 224 | Error - CAPTCHA required | "Please complete the CAPTCHA challenge" |
| 224 | Error - CAPTCHA invalid | "Invalid CAPTCHA" |
| 226 | Error - CAPTCHA failed | "CAPTCHA verification failed. Please try again." |

### `/src/middleware/security/moderation-middleware.ts`

| Line | Context | String |
|------|---------|--------|
| ~40 | Error - Validation | "Content must be a string" |
| ~45 | Error - Validation | "Content exceeds maximum length" |
| ~60 | Error - Policy violation | "Content violates community guidelines" |
| ~70 | Error - Spam | "Content appears to be spam" |

### `/src/middleware/security/file-upload-security-middleware.ts`

| Line | Context | String |
|------|---------|--------|
| ~30 | Error - File type | "Invalid file type" |
| ~40 | Error - File size | "File too large" |

---

## ❌ Error Handling

### `/src/middleware/error-middleware.ts`

| Line | Context | String |
|------|---------|--------|
| ~45 | Error - Validation | "Validation Error" |
| ~55 | Error - Database | "Duplicate entry" |
| ~57 | Error - Database | "Invalid reference" |
| ~95 | Error - Generic | "Internal Server Error" |

---

## 🎨 React Components (Telemetry Flow)

### `/src/components/TelemetryOptOutFlow.tsx`

#### Intro Screen
| Line | Context | String |
|------|---------|--------|
| 107 | Heading | "🛡️ We Respect Your Privacy" |
| 115 | Subheading | "Help Us Improve" |
| 116 | Description | "We'd like to collect usage data to make this app better. You're in control of what we collect." |
| 120 | Promise item | "Top-tier security & encryption" |
| 122 | Promise item | "Your data is never sold or shared" |
| 123 | Promise item | "Full transparency on what we collect" |
| 147 | Button - Primary | "Review Options" |
| 153 | Button - Secondary | "Skip for Now" |
| 154 | Skip disclaimer | "(Keeps all options enabled)" |

#### Crash Reports Screen
| Line | Context | String |
|------|---------|--------|
| ~170 | Title | "Crash Reports" |
| ~172 | Description | "Help us identify and fix bugs faster" |
| ~176 | Card heading | "What We Collect" |
| ~177 | Card content | "Error logs, stack traces, device info" |
| ~179 | Card heading | "Why It Helps" |
| ~180 | Card content | "Diagnose crashes and prevent future issues" |

#### Usage Analytics Screen
| Line | Context | String |
|------|---------|--------|
| ~170 | Title | "Usage Analytics" |
| ~172 | Description | "Understand which features you use most" |
| ~176 | Card heading | "What We Collect" |
| ~177 | Card content | "Feature usage patterns, navigation flows (no message content)" |
| ~179 | Card heading | "Why It Helps" |
| ~180 | Card content | "Prioritize improvements based on real usage" |

#### Performance Metrics Screen
| Line | Context | String |
|------|---------|--------|
| ~170 | Title | "Performance Metrics" |
| ~172 | Description | "Optimize speed and reliability" |
| ~176 | Card heading | "What We Collect" |
| ~177 | Card content | "Load times, network speed, battery usage" |
| ~179 | Card heading | "Why It Helps" |
| ~180 | Card content | "Identify bottlenecks and improve performance" |

#### Feature Usage Screen
| Line | Context | String |
|------|---------|--------|
| ~170 | Title | "Feature Usage" |
| ~172 | Description | "See which features are most valuable" |
| ~176 | Card heading | "What We Collect" |
| ~177 | Card content | "Which features you interact with and how often" |
| ~179 | Card heading | "Why It Helps" |
| ~180 | Card content | "Guide development of new features" |

#### Summary Screen
| Line | Context | String |
|------|---------|--------|
| 214 | Heading | "Review Your Choices" |
| 215 | Description | "You can change these settings anytime in your privacy preferences" |
| 226 | Item label format | "{title}: {Enabled/Disabled}" |
| 237 | Reminder | "💡 You can change these settings anytime in your privacy preferences" |
| 241 | Button - Primary | "Confirm Choices" |
| 244 | Button - Secondary | "Back to Review" |

#### Navigation
| Line | Context | String |
|------|---------|--------|
| ~200 | Button | "Back" |
| ~205 | Button | "Next" |

---

## 📊 Rate Limiting

### `/src/middleware/rate-limiting/rate-limiter-middleware.ts`
*(Needs manual review - error messages may be in logic)*

**Note:** Check for user-facing rate limit messages in:
- WebSocket rate limiter
- Express rate limiter
- Message rate limiter

---

## 🎭 Validation Messages

### `/src/middleware/validation/password-strength-middleware.ts`
*(Needs review for password requirements messaging)*

### `/src/middleware/validation/age-verification-middleware.ts`
*(Needs review for age verification messages)*

### `/src/middleware/validation/input-validation-middleware.ts`
*(Needs review for generic validation errors)*

---

## 📝 API Routes

**TODO:** Scan the following route files for user-facing strings:
- `/src/routes/auth-routes.ts` - Login, signup, logout messages
- `/src/routes/user-routes.ts` - Profile update messages
- `/src/routes/chat-room-routes.ts` - Room creation, joining messages
- `/src/routes/message-routes.ts` - Message send/delete messages
- `/src/routes/subscription-routes.ts` - Subscription messages
- `/src/routes/moderation-routes.ts` - Moderation action messages
- `/src/routes/admin-routes.ts` - Admin action messages

---

## 🎯 Services

**TODO:** Scan the following service files for user-facing strings:
- `/src/services/auth-service.ts`
- `/src/services/user-service.ts`
- `/src/services/message-service.ts`
- `/src/services/room-service.ts`
- `/src/services/subscription-service.ts`
- `/src/services/moderation.service.ts`

---

## 🔄 WebSocket Messages

**TODO:** Scan WebSocket handlers for user-facing event messages:
- `/src/ws/handlers/` - All WebSocket event handlers

---

## 📋 Copy-Editing Checklist

### Tone & Voice
- [ ] Consistent tone (friendly, professional, etc.)
- [ ] Avoid jargon
- [ ] Clear, concise language
- [ ] Appropriate formality level

### Grammar & Style
- [ ] Consistent capitalization (Title Case vs sentence case)
- [ ] Consistent punctuation
- [ ] No typos or grammar errors
- [ ] Proper use of contractions

### UX Writing Best Practices
- [ ] Error messages are actionable (tell users what to do)
- [ ] Success messages are encouraging
- [ ] Labels are descriptive and clear
- [ ] Button text uses action verbs
- [ ] Help text provides context

### Accessibility
- [ ] Screen reader friendly
- [ ] No ambiguous references
- [ ] Clear error states

---

## 🚀 Next Steps

1. **Complete the scan** - Run automated extraction on remaining files
2. **Review & categorize** - Group by user journey/flow
3. **Copy edit** - Update strings for consistency
4. **Create constants** - Extract to i18n/constants file
5. **Test** - Verify changes don't break functionality

---

## 📌 Notes

- **Internationalization (i18n)**: Consider extracting all strings to a constants file for easier translation
- **A/B Testing**: Some strings may need variants for testing
- **Legal Review**: Error messages and terms may need legal approval
- **Brand Voice**: Ensure all strings align with brand guidelines

