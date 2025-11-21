# VibeZ User-Facing Strings Rewrite
**Mission:** Strip tech jargon. Make it sound like your best friend saying it: calm, clear, zero fluff.

---

## 🎯 Rewrite Principles

1. **One-breath English** - If you can't say it in one breath, it's too long
2. **Zero tech jargon** - No "authenticate", "initialize", "configure", etc.
3. **Friend-to-friend tone** - Upbeat but not cheesy
4. **Active voice** - "Start talking" not "Voice session initiated"
5. **Clear actions** - Tell them what to do, not what went wrong

---

## 📱 iOS App Strings

### Buttons & Actions

| **OLD (Jargony)** | **NEW (Plain English)** |
|-------------------|-------------------------|
| Initialize Identity | Pick your name |
| Initiate real-time voice session | Start talking now |
| Authentication required | Please sign in |
| Get Started | Jump in |
| Begin Setup | Let's go |
| Enter VIBEZ | Start vibing |
| Scan QR Code | Scan code |
| Connect to Node | Connect |
| Export My Data | Download my stuff |
| Delete Account & Data | Delete everything |
| Create Room | New room |
| Leave | Leave room |

### Headings & Labels

| **OLD (Jargony)** | **NEW (Plain English)** |
|-------------------|-------------------------|
| Privacy Control Center | Your privacy |
| Self-Hosted Node | Your own server |
| Connection Details | Server info |
| Data Permissions | What we can see |
| Data Management | Your data |
| Chat Security | Keep chats private |
| Privacy Shield Active | Privacy on |
| General Settings | Settings |
| Guest User | Just browsing |

### Messages & Descriptions

| **OLD (Jargony)** | **NEW (Plain English)** |
|-------------------|-------------------------|
| Run Your Own Cloud | Host it yourself |
| Connect to a personal VIBEZ Node for complete data sovereignty. No third-party servers involved. | Run your own VibeZ server. Your data stays with you. |
| Your data is local-first and encrypted. | Your stuff stays on your device, locked up tight. |
| A social experience designed around absolute privacy and control. | Chat freely. Your business stays your business. |
| We don't track you by default. Enable only what you're comfortable with. | We don't watch you. Turn on only what helps. |
| Your privacy preferences have been saved. | Saved your choices. |
| You can change them anytime in Settings. | Change this anytime in settings. |
| Secure your name and stats. | Keep your name and activity private. |
| Experience Connection Reimagined. | Real conversations. No drama. |
| I am 18 years or older | I'm 18+ |
| Could not connect to server. Please check the URL. | Can't reach that server. Check the link? |
| Loading rooms... | Finding your rooms... |
| Connecting to your spaces | Linking up... |
| No rooms available | Nothing here yet |
| Create a room to get started | Make your first room |

### Status Messages

| **OLD (Jargony)** | **NEW (Plain English)** |
|-------------------|-------------------------|
| This is a persistent text message that stays even when voice is idle. | This message sticks around. |
| Time Remaining: X seconds | X seconds left |

---

## 🔐 Backend Error Messages

### Authentication Errors

| **OLD (Jargony)** | **NEW (Plain English)** |
|-------------------|-------------------------|
| Authentication required | Sign in first |
| Invalid token | Session expired. Sign in again? |
| Missing Supabase credentials. Set SUPABASE_URL and SUPABASE_ANON_KEY | Server setup incomplete |
| Server configuration error | Something's wrong on our end |
| Admin access required | Admins only |
| Moderator access required | Moderators only |
| Owner access required | Room owners only |
| Permission required: {permission} | You can't do that here |
| Authorization check failed | Can't verify your permissions |
| Username and password are required | Need your username and password |
| Authentication failed | Couldn't sign you in |
| Registration failed | Couldn't create your account |
| Invalid credentials | Wrong username or password |
| Apple authentication token is required | Need your Apple sign-in |
| Failed to verify Apple authentication token | Can't verify your Apple sign-in |
| Invalid username format | That username won't work |
| Invalid username or password | Wrong username or password |
| Username already exists | That name's taken |
| Username can only contain letters, numbers, underscores, and hyphens | Use letters, numbers, _ or - |
| Password does not meet requirements | Make your password stronger |
| Failed to hash password | Can't secure your password right now |

### Password Requirements

| **OLD (Jargony)** | **NEW (Plain English)** |
|-------------------|-------------------------|
| Password must be at least 8 characters | Use 8+ characters |
| Password must be at most 500 characters | Way too long |
| Password must contain at least one uppercase letter | Add a capital letter |
| Password must contain at least one lowercase letter | Add a lowercase letter |
| Password must contain at least one number | Add a number |
| Password must contain at least one special character | Add a symbol like ! or $ |

### Messaging Errors

| **OLD (Jargony)** | **NEW (Plain English)** |
|-------------------|-------------------------|
| Message queued for processing | Sending... |
| Invalid message_id | Can't find that message |
| Message not found | Can't find that message |
| Archived message not found | That message is gone |
| Failed to send message | Couldn't send that |
| You are temporarily muted in this room | You're muted for now |
| Room requires end-to-end encryption. Message payload must be encrypted. | This room needs encryption |
| Failed to prepare message content for storage | Can't save that message |
| Failed to get messages | Can't load messages |
| Invalid emoji | That emoji doesn't work |
| Failed to add reaction | Couldn't add that reaction |
| Invalid parent_message_id | Can't find the original message |
| Parent message not found | Original message is gone |
| Failed to create thread | Couldn't start a thread |
| Invalid thread_id | Can't find that thread |
| Thread not found | Thread disappeared |
| Failed to fetch thread | Can't load that thread |
| Invalid content | Can't post that |
| Not authorized to edit this message | You can't edit this |
| Message can only be edited within 24 hours | Too late to edit |
| Failed to edit message | Couldn't edit that |
| Invalid search query | Search isn't working |
| Failed to search messages | Can't search right now |
| Message queue is overloaded. Please try again later. | Too many messages. Try again in a sec? |

### Room Errors

| **OLD (Jargony)** | **NEW (Plain English)** |
|-------------------|-------------------------|
| Room not found | Can't find that room |
| Room name is required | Give your room a name |
| Name taken | That name's taken |
| Failed to create room | Couldn't make the room |
| Failed to join room | Can't join right now |
| Room is private and you are not a member | This room is private |
| Permission denied | You can't do that |
| Permission denied - only room owner or admin can set thresholds | Only the owner can change this |
| You must be a member of this room to flag messages | Join first |
| Room is full | Room's full |
| Enterprise subscription required for AI moderation | Need Enterprise for AI moderation |

### Moderation Errors

| **OLD (Jargony)** | **NEW (Plain English)** |
|-------------------|-------------------------|
| Content must be a string | Invalid text |
| Content exceeds maximum length | Too long |
| Content violates community guidelines | Can't post that |
| Content appears to be spam | Looks like spam |
| Invalid reason. Must be one of: toxicity, spam, harassment, inappropriate, other | Pick a reason: toxic, spam, harassment, inappropriate, or other |
| You cannot flag your own messages | You can't report your own messages |
| You have already flagged this message | You already reported this |
| Message flagged successfully. It will be reviewed by moderators. | Reported. We'll look at it. |
| Failed to flag message | Couldn't report that |
| Failed to get flagged messages | Can't load reports |
| Invalid action | Can't do that |
| Flag not found | Can't find that report |
| Failed to review flag | Couldn't review that report |
| Failed to get moderation stats | Can't load mod stats |

### Rate Limiting

| **OLD (Jargony)** | **NEW (Plain English)** |
|-------------------|-------------------------|
| Too many requests from this IP, please try again later. | Slow down. Try again in a bit. |
| Rate limit exceeded | You're going too fast |
| Too many requests, please slow down. | Slow down |
| Too many requests to this sensitive endpoint, please try again later. | Too many tries. Wait a sec. |
| Rate limit exceeded for your subscription tier. | Hit your plan's limit |
| You have exceeded the rate limit for your subscription tier. | You hit your plan's limit |
| User rate limit requires authentication | Sign in first |
| Too many requests from this user account. | Slow down on your account |
| Too many requests from this account, please try again later. | Too fast. Wait a bit. |
| API key rate limit exceeded. | Your API key hit the limit |
| API key rate limit exceeded, please try again later. | API limit hit. Try again soon. |
| Rate limit exceeded. Please slow down. | Slow down |
| Too many requests from this IP address. | Too many tries from your network |
| Too Many Requests | Going too fast |

### File & Upload Errors

| **OLD (Jargony)** | **NEW (Plain English)** |
|-------------------|-------------------------|
| Invalid file type | Can't upload that file type |
| File too large | File's too big |
| No file provided | Pick a file first |
| File upload failed | Upload didn't work |
| Failed to upload file | Couldn't upload |
| Failed to get file URL | Can't find that file |
| File deletion failed | Couldn't delete that |

### Validation Errors

| **OLD (Jargony)** | **NEW (Plain English)** |
|-------------------|-------------------------|
| Validation Error | Something's wrong |
| Invalid input format | That format doesn't work |
| Missing required fields: {fields} | Need: {fields} |
| {field} must be at least {minLength} characters | {field} needs {minLength}+ characters |
| {field} must be at most {maxLength} characters | {field} is too long |
| Invalid {field} format | {field} doesn't look right |
| Age verification required | Confirm you're 18+ |
| You must verify that you are 18+ to create or join rooms | You need to be 18+ |
| Failed to verify age status | Can't check your age right now |
| User not found | Can't find that user |

### Subscription Errors

| **OLD (Jargony)** | **NEW (Plain English)** |
|-------------------|-------------------------|
| Pro subscription required | Need Pro for this |
| Team subscription required | Need Team for this |
| Failed to check subscription | Can't check your plan |
| Failed to get entitlements | Can't load your features |
| plan and status are required | Need plan and status |
| user_id and receipt_data required | Missing receipt info |
| Failed to get subscription status | Can't check your subscription |
| receiptData required | Need your receipt |
| Invalid receipt | Receipt doesn't work |
| Failed to verify receipt | Can't verify receipt |
| Voice access requires Pro subscription. Please upgrade. | Voice needs Pro. Upgrade? |
| Voice minutes limit reached | Out of voice minutes |
| You've reached your monthly voice minutes limit. Upgrade to Pro for unlimited voice calls. | Out of voice time. Get Pro for unlimited? |

### Voice/Video Errors

| **OLD (Jargony)** | **NEW (Plain English)** |
|-------------------|-------------------------|
| Video service not configured | Video isn't set up |
| Failed to generate video token | Can't start video |
| isMuted must be a boolean | Mute setting is broken |
| Room or member not found | Can't find that person or room |
| Room or member not found, or room is voice-only | Not in video mode |
| isVideoEnabled must be a boolean | Video setting is broken |
| Failed to join voice channel | Can't join voice |
| Left voice room | Left voice |
| Failed to leave voice room | Couldn't leave voice |
| Voice room not found | Can't find that voice room |
| Failed to get voice room info | Can't load voice info |
| Failed to get voice stats | Can't load voice stats |
| Failed to log voice stats | Can't save voice stats |
| Invalid room_name | Room name doesn't work |
| Invalid roomName | Bad room name |
| Invalid participantIdentity | Can't identify you |
| Could not create voice room | Couldn't make voice room |

### Privacy & Data

| **OLD (Jargony)** | **NEW (Plain English)** |
|-------------------|-------------------------|
| Forbidden: You can only export your own data | Can't export someone else's data |
| Failed to export user data | Export failed |
| Forbidden: You can only view your own consent records | Can't see others' privacy choices |
| Failed to get consent records | Can't load privacy history |
| Forbidden: You can only withdraw your own consent | Can't change others' choices |
| Required consent cannot be withdrawn | Need this one active |
| Failed to withdraw consent | Couldn't update that |
| Forbidden: You can only export your own telemetry data | Can't export others' data |
| Invalid batched request body | Batch request is broken |
| Invalid request body | Request doesn't work |
| Invalid verifierId format | ID format is wrong |
| Hardware acceleration unavailable - using software encryption | Using slower encryption |
| Failed to get encryption status | Can't check encryption |
| Invalid userId format | User ID is wrong |
| Forbidden: Cannot view other users' commitments | Can't see others' commitments |
| Failed to fetch commitments | Can't load commitments |
| Failed to get ZKP commitments | Can't load proof data |
| Too many disclosure requests, please try again later | Too many requests. Slow down. |

### Search & Invites

| **OLD (Jargony)** | **NEW (Plain English)** |
|-------------------|-------------------------|
| query parameter is required | Need a search term |
| room_id parameter is required | Need a room ID |
| Search failed | Search isn't working |
| Message search failed | Can't search messages |
| Room search failed | Can't search rooms |
| Room ID is required | Need a room ID |
| Failed to create invite | Couldn't make invite |
| Invalid or expired invite | Invite doesn't work |
| Failed to use invite | Couldn't use invite |

### CAPTCHA & Security

| **OLD (Jargony)** | **NEW (Plain English)** |
|-------------------|-------------------------|
| Please complete the CAPTCHA challenge | Prove you're human |
| Invalid CAPTCHA | CAPTCHA didn't work |
| CAPTCHA verification failed. Please try again. | Try the CAPTCHA again |
| CAPTCHA required | Need CAPTCHA |
| Account temporarily locked | Account locked for now |

### Generic Errors

| **OLD (Jargony)** | **NEW (Plain English)** |
|-------------------|-------------------------|
| Internal Server Error | Something went wrong |
| Bad Request | Request doesn't work |
| Not Found | Can't find that |
| Duplicate entry | That already exists |
| Invalid reference | Link doesn't work |
| Failed to fetch stats | Can't load stats |
| Unknown error | Something weird happened |
| Circuit breaker is OPEN - service unavailable | Service down. Try again soon. |
| Database connection pool exhausted | Database overloaded |
| Transaction failed | Couldn't complete that |

### Misc

| **OLD (Jargony)** | **NEW (Plain English)** |
|-------------------|-------------------------|
| nickname is required | Pick a nickname |
| Nickname must be 32 characters or less | Nickname's too long (32 max) |
| message_id and emoji are required | Need message and emoji |
| action must be "add" or "remove" | Pick add or remove |
| Invalid emoji format | Emoji doesn't work |
| message_id is required | Need a message ID |
| message_ids array is required | Need message IDs |
| Failed to mark message as read | Couldn't mark as read |
| Failed to mark message as delivered | Couldn't mark as delivered |
| Failed to mark messages as read | Couldn't mark as read |
| Failed to get read receipts | Can't load read receipts |
| Failed to get room read status | Can't check read status |
| Failed to create thread | Couldn't start thread |
| Failed to get thread | Can't load thread |
| Invalid mode. Must be auto, low, or high | Pick auto, low, or high |
| Demo data seeded successfully | Demo loaded |
| Rate limit exceeded for this room | Room's too busy |
| Notify failed | Notification didn't send |

---

## 📊 Telemetry & Privacy Flow

### Privacy Onboarding (Already Great!)

| **OLD** | **NEW** |
|---------|---------|
| 🛡️ We Respect Your Privacy | Your privacy matters |
| Help Us Improve | Help make this better |
| We'd like to collect usage data to make this app better. You're in control of what we collect. | We want to make this better. Choose what you share. |
| Top-tier security & encryption | Locked down tight |
| Your data is never sold or shared | Never sold. Never shared. |
| Full transparency on what we collect | See exactly what we track |
| Review Options | See options |
| Skip for Now | Skip |
| (Keeps all options enabled) | (Everything stays on) |

### Telemetry Categories (Simplify)

| **OLD** | **NEW** |
|---------|---------|
| Crash Reports | Crash reports |
| Help us identify and fix bugs faster | Help us squash bugs |
| Usage Analytics | How you use it |
| Understand which features you use most | See what you love |
| Performance Metrics | Speed checks |
| Optimize speed and reliability | Keep it fast |
| Feature Usage | Feature tracking |
| See which features are most valuable | What features work |

---

## 🎨 Implementation Priority

### Phase 1: iOS App (User-Facing)
1. ✅ Buttons & CTAs
2. ✅ Error messages in views
3. ✅ Onboarding flow
4. ✅ Settings labels

### Phase 2: Backend Errors (API Responses)
1. ✅ Authentication errors
2. ✅ Messaging errors
3. ✅ Rate limiting
4. ✅ Validation messages

### Phase 3: Polish
1. ✅ Tooltips & hints
2. ✅ Success messages
3. ✅ Loading states

---

## ✅ Done!

All strings converted to plain, one-breath English. Zero jargon. Sounds like a friend.

---

## 📝 Files Updated

### iOS App (Frontend)
- ✅ `frontend/iOS/Views/OnboardingV2.swift` - Onboarding flow
- ✅ `frontend/iOS/Views/ProfileView.swift` - Profile & settings
- ✅ `frontend/iOS/Views/RoomListView.swift` - Room list
- ✅ `frontend/iOS/Views/Settings/PrivacySettingsView.swift` - Privacy settings
- ✅ `frontend/iOS/Views/Settings/SelfHostSettingsView.swift` - Self-hosting
- ✅ `frontend/iOS/Views/Onboarding/PrivacyOnboardingView.swift` - Privacy onboarding

### Backend (API & Services)
- ✅ `src/middleware/auth/supabase-auth-middleware.ts` - Auth errors
- ✅ `src/middleware/auth/admin-auth-middleware.ts` - Admin auth errors
- ✅ `src/routes/auth-api-routes.ts` - Login/register errors
- ✅ `src/middleware/rate-limiting/express-rate-limit-middleware.ts` - Rate limits
- ✅ `src/middleware/error-middleware.ts` - Generic errors
- ✅ `src/routes/room-api-routes.ts` - Room errors
- ✅ `src/services/message-service.ts` - Messaging errors
- ✅ `src/middleware/validation/password-strength-middleware.ts` - Password rules
- ✅ `src/middleware/security/moderation-middleware.ts` - Moderation errors
- ✅ `src/middleware/security/file-upload-security-middleware.ts` - File upload errors

---

## 🎯 Summary

**Total files updated:** 16  
**Total strings rewritten:** 100+  
**Tone:** Friendly, clear, zero jargon  
**Style:** One-breath English, friend-to-friend

All user-facing strings now sound natural and conversational. No tech jargon. Easy to understand.

