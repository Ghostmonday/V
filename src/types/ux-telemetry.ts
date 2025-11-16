/**
 * UX Telemetry Type Definitions
 * 
 * Standalone telemetry system for product observability, user behavior analysis,
 * and LLM-driven autonomous UX optimization. Completely separate from system/infra telemetry.
 * 
 * @module ux-telemetry
 */

/**
 * UX Event Categories
 * Used for filtering and querying telemetry by functional area
 */
export enum UXEventCategory {
  UI_STATE = 'ui_state',
  CLICKSTREAM = 'clickstream',
  VALIDATION = 'validation',
  SYSTEM = 'system',
  PERFORMANCE = 'performance',
  VOICE_AV = 'voice_av',
  MESSAGING = 'messaging',
  ENGAGEMENT = 'engagement',
  EMOTIONAL = 'emotional',
  PRESENCE = 'presence',
  THREADING = 'threading',
  TYPING = 'typing',
  FEATURE_USE = 'feature_use',
  AI_FEEDBACK = 'ai_feedback',
  COGNITIVE_STATE = 'cognitive_state',
  JOURNEY_ANALYTICS = 'journey_analytics',
  BEHAVIOR_MODELING = 'behavior_modeling',
}

/**
 * Core UX Event Types
 * Standard events for tracking user interactions and system states
 */
export enum UXEventType {
  // UI State Events
  UI_STATE_TRANSITION = 'ui_state_transition',
  UI_CLICK = 'ui_click',
  UI_VALIDATION_ERROR = 'ui_validation_error',
  
  // System Events
  API_FAILURE = 'api_failure',
  CLIENT_CRASH = 'client_crash',
  
  // Performance Events
  LATENCY_BUCKET = 'latency_bucket',
  
  // Voice/AV Events
  VOICE_CAPTURE_FAILED = 'voice_capture_failed',
  
  // Messaging Events
  MESSAGE_SEND_ATTEMPTED = 'message_send_attempted',
  MESSAGE_SEND_FAILED = 'message_send_failed',
  
  // Engagement Events
  ROOM_ENTRY = 'room_entry',
  ROOM_EXIT = 'room_exit',
  
  // Emotional Events
  MESSAGE_SENTIMENT = 'message_sentiment',
  
  // Presence Events
  PRESENCE_PING = 'presence_ping',
  
  // Threading Events
  THREAD_CREATED = 'thread_created',
  
  // Typing Events
  TYPING_START = 'typing_start',
  TYPING_STOP = 'typing_stop',
  
  // Feature Use Events
  SCREEN_SHARE_START = 'screen_share_start',
  
  // Speculative/AI-Driven Events
  MESSAGE_ROLLBACK = 'message_rollback',
  MESSAGE_EMOTION_DIFF = 'message_emotion_diff',
  CONVERSATION_ARC_SHAPE = 'conversation_arc_shape',
  PRESENCE_SYNC_LAG = 'presence_sync_lag',
  USER_FLOW_ABANDONMENT = 'user_flow_abandonment',
  AI_DISAGREEMENT_SIGNAL = 'ai_disagreement_signal',
  CONTEXT_OVERLOAD = 'context_overload',
  
  // AI Feedback & Trust Signals
  AI_SUGGESTION_ACCEPTED = 'ai_suggestion_accepted',
  AI_SUGGESTION_REJECTED = 'ai_suggestion_rejected',
  AI_AUTO_FIX_APPLIED = 'ai_auto_fix_applied',
  AI_EDIT_UNDONE = 'ai_edit_undone',
  AI_HELP_REQUESTED = 'ai_help_requested',
  AGENT_HANDOFF_FAILED = 'agent_handoff_failed',
  
  // Emotional & Cognitive State Signals
  MESSAGE_SENTIMENT_BEFORE = 'message_sentiment_before',
  MESSAGE_SENTIMENT_AFTER = 'message_sentiment_after',
  SESSION_EMOTION_CURVE = 'session_emotion_curve',
  MESSAGE_EMOTION_CONTRADICTION = 'message_emotion_contradiction',
  VALIDATION_REACT_IRRITATION_SCORE = 'validation_react_irritation_score',
  
  // Sequence & Journey Analytics
  EVENT_SEQUENCE_PATH = 'event_sequence_path',
  FUNNEL_CHECKPOINT_HIT = 'funnel_checkpoint_hit',
  DROPOFF_POINT_DETECTED = 'dropoff_point_detected',
  REPEATED_STATE_LOOP_DETECTED = 'repeated_state_loop_detected',
  
  // Performance-to-UX Linking
  LOAD_TIME_PERCEIVED_VS_ACTUAL = 'load_time_perceived_vs_actual',
  INTERACTION_LATENCY_MS = 'interaction_latency_ms',
  STUTTERED_INPUT = 'stuttered_input',
  LONG_STATE_WITHOUT_PROGRESS = 'long_state_without_progress',
  
  // User Archetype / Behavior Modeling
  USER_ACTION_BURST = 'user_action_burst',
  SESSION_IDLE_THEN_RETRY = 'session_idle_then_retry',
  FIRST_SESSION_STALL_POINT = 'first_session_stall_point',
  RETRY_AFTER_ERROR_INTERVAL = 'retry_after_error_interval',
  FEATURE_TOGGLE_HOVER_NO_USE = 'feature_toggle_hover_no_use',
}

/**
 * Device Context Information
 * Captured automatically by client SDK
 */
export interface DeviceContext {
  /** Browser or client type */
  userAgent?: string;
  /** Screen dimensions */
  screenWidth?: number;
  screenHeight?: number;
  /** Viewport dimensions */
  viewportWidth?: number;
  viewportHeight?: number;
  /** Device pixel ratio */
  pixelRatio?: number;
  /** Operating system */
  platform?: string;
  /** Browser language */
  language?: string;
  /** Connection type (if available) */
  connectionType?: string;
  /** Timezone */
  timezone?: string;
}

/**
 * UX Telemetry Event Envelope
 * 
 * Structured format for all UX telemetry events.
 * Designed for:
 * - Product teams (designers, PMs)
 * - AI agents (LLM observers)
 * - Analytics pipelines
 * 
 * NOT for engineering/system debugging.
 */
export interface UXTelemetryEvent {
  /** Unique trace ID for correlating events across client/server */
  traceId: string;
  
  /** Session ID for grouping events by user session */
  sessionId: string;
  
  /** Event type from UXEventType enum */
  eventType: UXEventType;
  
  /** Event category for filtering and grouping */
  category: UXEventCategory;
  
  /** ISO timestamp when event occurred */
  timestamp: string;
  
  /** Component identifier (e.g., 'PrimaryButton', 'ChatInput') */
  componentId?: string;
  
  /** State before transition (for state change events) */
  stateBefore?: string;
  
  /** State after transition (for state change events) */
  stateAfter?: string;
  
  /** Event-specific metadata (PII-scrubbed) */
  metadata: Record<string, unknown>;
  
  /** Device/browser context */
  deviceContext?: DeviceContext;
  
  /** Whether this event was sampled (true = sampled, false = 100% captured) */
  samplingFlag: boolean;
  
  /** User ID (if authenticated) */
  userId?: string;
  
  /** Room/channel ID (if applicable) */
  roomId?: string;
}

/**
 * Batch of UX telemetry events
 * Used for efficient server ingestion
 */
export interface UXTelemetryBatch {
  events: UXTelemetryEvent[];
  batchId: string;
  timestamp: string;
}

/**
 * Sampling configuration
 */
export interface SamplingConfig {
  /** Sample rate for critical events (default: 1.0 = 100%) */
  criticalEventRate: number;
  
  /** Sample rate for high-frequency events (default: 0.1 = 10%) */
  highFrequencyEventRate: number;
  
  /** Sample rate for standard events (default: 0.5 = 50%) */
  standardEventRate: number;
  
  /** Events that are always sampled at 100% */
  criticalEvents: UXEventType[];
  
  /** Events that are high-frequency and should be sampled */
  highFrequencyEvents: UXEventType[];
}

/**
 * Default sampling configuration
 */
export const DEFAULT_SAMPLING_CONFIG: SamplingConfig = {
  criticalEventRate: 1.0,
  highFrequencyEventRate: 0.1,
  standardEventRate: 0.5,
  criticalEvents: [
    UXEventType.UI_VALIDATION_ERROR,
    UXEventType.API_FAILURE,
    UXEventType.CLIENT_CRASH,
    UXEventType.MESSAGE_SEND_FAILED,
    UXEventType.VOICE_CAPTURE_FAILED,
    UXEventType.AGENT_HANDOFF_FAILED,
    UXEventType.DROPOFF_POINT_DETECTED,
    UXEventType.FIRST_SESSION_STALL_POINT,
    UXEventType.VALIDATION_REACT_IRRITATION_SCORE,
  ],
  highFrequencyEvents: [
    UXEventType.UI_CLICK,
    UXEventType.TYPING_START,
    UXEventType.TYPING_STOP,
    UXEventType.PRESENCE_PING,
    UXEventType.USER_ACTION_BURST,
    UXEventType.EVENT_SEQUENCE_PATH,
    UXEventType.INTERACTION_LATENCY_MS,
    UXEventType.STUTTERED_INPUT,
  ],
};

/**
 * Consent configuration
 */
export interface ConsentConfig {
  /** Whether user has consented to telemetry */
  enabled: boolean;
  
  /** Consent timestamp */
  consentedAt?: string;
  
  /** Consent version */
  version?: string;
}

/**
 * Client SDK configuration
 */
export interface UXTelemetrySDKConfig {
  /** API endpoint for sending events */
  endpoint: string;
  
  /** Batch size before auto-flush */
  batchSize: number;
  
  /** Max time to wait before auto-flush (ms) */
  flushInterval: number;
  
  /** Max retry attempts for failed sends */
  maxRetries: number;
  
  /** Initial retry delay (ms) */
  retryDelay: number;
  
  /** Sampling configuration */
  sampling: SamplingConfig;
  
  /** Consent configuration */
  consent: ConsentConfig;
  
  /** Enable debug logging */
  debug: boolean;
}

/**
 * Default SDK configuration
 */
export const DEFAULT_SDK_CONFIG: Partial<UXTelemetrySDKConfig> = {
  endpoint: '/api/ux-telemetry',
  batchSize: 10,
  flushInterval: 5000, // 5 seconds
  maxRetries: 3,
  retryDelay: 1000, // 1 second
  sampling: DEFAULT_SAMPLING_CONFIG,
  consent: {
    enabled: true, // Opt-in by default, but respect user preference
  },
  debug: false,
};

