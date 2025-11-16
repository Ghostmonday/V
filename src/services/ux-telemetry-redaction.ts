/**
 * UX Telemetry PII Redaction Service
 * 
 * Server-side PII detector and redaction pipeline.
 * Acts as a safety net in addition to client-side scrubbing.
 * 
 * Scans all metadata fields recursively for sensitive information:
 * - Email addresses
 * - Phone numbers
 * - Credit card numbers
 * - Social Security Numbers
 * - IP addresses
 * - Raw message content (if accidentally included)
 * 
 * @module ux-telemetry-redaction
 */

import { logError, logInfo } from '../shared/logger.js';
import type { UXTelemetryEvent } from '../types/ux-telemetry.js';

/**
 * PII detection patterns
 */
const PII_PATTERNS = {
  // Email addresses
  email: {
    pattern: /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/g,
    name: 'email',
  },
  
  // Phone numbers (various formats)
  phone: {
    pattern: /(\+?\d{1,3}[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}/g,
    name: 'phone',
  },
  
  // Credit card numbers (with or without separators)
  creditCard: {
    pattern: /\b\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}\b/g,
    name: 'credit_card',
  },
  
  // Social Security Numbers
  ssn: {
    pattern: /\b\d{3}-\d{2}-\d{4}\b/g,
    name: 'ssn',
  },
  
  // IPv4 addresses
  ipv4: {
    pattern: /\b(?:\d{1,3}\.){3}\d{1,3}\b/g,
    name: 'ipv4',
  },
  
  // IPv6 addresses (simplified pattern)
  ipv6: {
    pattern: /\b(?:[0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}\b/g,
    name: 'ipv6',
  },
};

/**
 * Field names that should be completely removed (likely to contain PII)
 */
const SENSITIVE_FIELD_NAMES = [
  'message',
  'content',
  'body',
  'text',
  'comment',
  'description',
  'password',
  'token',
  'secret',
  'key',
  'apiKey',
  'api_key',
  'accessToken',
  'access_token',
];

/**
 * Redaction statistics
 */
export interface RedactionStats {
  /** Total fields scanned */
  fieldsScanned: number;
  
  /** Fields redacted */
  fieldsRedacted: number;
  
  /** PII types detected */
  piiTypesDetected: string[];
  
  /** Total PII instances found */
  totalPiiInstances: number;
  
  /** Whether event was modified */
  wasModified: boolean;
}

/**
 * Check if field name suggests sensitive content
 */
function isSensitiveFieldName(key: string): boolean {
  const lowerKey = key.toLowerCase();
  return SENSITIVE_FIELD_NAMES.some(sensitive => lowerKey.includes(sensitive));
}

/**
 * Detect and count PII in a string
 */
function detectPII(value: string): { types: Set<string>; count: number } {
  const detectedTypes = new Set<string>();
  let count = 0;
  
  for (const { pattern, name } of Object.values(PII_PATTERNS)) {
    const matches = value.match(pattern);
    if (matches) {
      detectedTypes.add(name);
      count += matches.length;
    }
  }
  
  return { types: detectedTypes, count };
}

/**
 * Redact PII from a string value
 */
function redactString(value: string): string {
  let redacted = value;
  
  for (const { pattern } of Object.values(PII_PATTERNS)) {
    redacted = redacted.replace(pattern, '[REDACTED]');
  }
  
  return redacted;
}

/**
 * Recursively redact PII from a value
 * Returns: [redacted value, stats]
 */
function redactValue(
  value: unknown,
  key: string = '',
  stats: RedactionStats
): unknown {
  stats.fieldsScanned++;
  
  // Handle null/undefined
  if (value === null || value === undefined) {
    return value;
  }
  
  // Check if field name suggests sensitive content
  if (key && isSensitiveFieldName(key)) {
    stats.fieldsRedacted++;
    stats.wasModified = true;
    return '[REDACTED]';
  }
  
  // Handle strings
  if (typeof value === 'string') {
    const { types, count } = detectPII(value);
    
    if (count > 0) {
      stats.fieldsRedacted++;
      stats.totalPiiInstances += count;
      stats.wasModified = true;
      
      types.forEach(type => {
        if (!stats.piiTypesDetected.includes(type)) {
          stats.piiTypesDetected.push(type);
        }
      });
      
      return redactString(value);
    }
    
    return value;
  }
  
  // Handle arrays
  if (Array.isArray(value)) {
    return value.map((item, index) => 
      redactValue(item, `${key}[${index}]`, stats)
    );
  }
  
  // Handle objects
  if (typeof value === 'object') {
    const redacted: Record<string, unknown> = {};
    
    for (const [objKey, objValue] of Object.entries(value)) {
      const fullKey = key ? `${key}.${objKey}` : objKey;
      redacted[objKey] = redactValue(objValue, fullKey, stats);
    }
    
    return redacted;
  }
  
  // Return other types as-is (numbers, booleans, etc.)
  return value;
}

/**
 * Redact PII from a UX telemetry event
 * 
 * This is a server-side safety net. The client SDK should already scrub PII,
 * but this provides defense in depth.
 */
export function redactUXTelemetryEvent(
  event: UXTelemetryEvent
): { event: UXTelemetryEvent; stats: RedactionStats } {
  const stats: RedactionStats = {
    fieldsScanned: 0,
    fieldsRedacted: 0,
    piiTypesDetected: [],
    totalPiiInstances: 0,
    wasModified: false,
  };
  
  try {
    // Create a copy to avoid mutating original
    const redactedEvent: UXTelemetryEvent = { ...event };
    
    // Redact metadata (most likely to contain PII)
    redactedEvent.metadata = redactValue(
      event.metadata,
      'metadata',
      stats
    ) as Record<string, unknown>;
    
    // Redact device context (may contain IP addresses)
    if (event.deviceContext) {
      redactedEvent.deviceContext = redactValue(
        event.deviceContext,
        'deviceContext',
        stats
      ) as any;
    }
    
    // Redact component ID if it looks suspicious
    if (event.componentId && typeof event.componentId === 'string') {
      const { count } = detectPII(event.componentId);
      if (count > 0) {
        stats.fieldsRedacted++;
        stats.totalPiiInstances += count;
        stats.wasModified = true;
        redactedEvent.componentId = '[REDACTED]';
      }
    }
    
    // Redact state values if they contain PII
    if (event.stateBefore && typeof event.stateBefore === 'string') {
      const { count } = detectPII(event.stateBefore);
      if (count > 0) {
        stats.fieldsRedacted++;
        stats.totalPiiInstances += count;
        stats.wasModified = true;
        redactedEvent.stateBefore = '[REDACTED]';
      }
    }
    
    if (event.stateAfter && typeof event.stateAfter === 'string') {
      const { count } = detectPII(event.stateAfter);
      if (count > 0) {
        stats.fieldsRedacted++;
        stats.totalPiiInstances += count;
        stats.wasModified = true;
        redactedEvent.stateAfter = '[REDACTED]';
      }
    }
    
    // Log redaction if PII was found
    if (stats.wasModified) {
      logInfo(
        `[UX Telemetry] PII redacted: ${stats.fieldsRedacted} fields, ` +
        `${stats.totalPiiInstances} instances, types: ${stats.piiTypesDetected.join(', ')}`
      );
    }
    
    return { event: redactedEvent, stats };
  } catch (error) {
    logError('Error redacting UX telemetry event', error);
    // On error, return original event (better to have data than lose it)
    return { event, stats };
  }
}

/**
 * Redact PII from a batch of events
 */
export function redactUXTelemetryBatch(
  events: UXTelemetryEvent[]
): {
  events: UXTelemetryEvent[];
  stats: RedactionStats;
} {
  const aggregatedStats: RedactionStats = {
    fieldsScanned: 0,
    fieldsRedacted: 0,
    piiTypesDetected: [],
    totalPiiInstances: 0,
    wasModified: false,
  };
  
  const redactedEvents = events.map(event => {
    const { event: redactedEvent, stats } = redactUXTelemetryEvent(event);
    
    // Aggregate stats
    aggregatedStats.fieldsScanned += stats.fieldsScanned;
    aggregatedStats.fieldsRedacted += stats.fieldsRedacted;
    aggregatedStats.totalPiiInstances += stats.totalPiiInstances;
    aggregatedStats.wasModified = aggregatedStats.wasModified || stats.wasModified;
    
    stats.piiTypesDetected.forEach(type => {
      if (!aggregatedStats.piiTypesDetected.includes(type)) {
        aggregatedStats.piiTypesDetected.push(type);
      }
    });
    
    return redactedEvent;
  });
  
  return {
    events: redactedEvents,
    stats: aggregatedStats,
  };
}

/**
 * Validate that an event contains no PII (for testing)
 */
export function validateNoPII(event: UXTelemetryEvent): {
  valid: boolean;
  violations: string[];
} {
  const violations: string[] = [];
  
  // Check metadata
  const metadataStr = JSON.stringify(event.metadata);
  for (const { pattern, name } of Object.values(PII_PATTERNS)) {
    if (pattern.test(metadataStr)) {
      violations.push(`${name} found in metadata`);
    }
  }
  
  // Check device context
  if (event.deviceContext) {
    const deviceStr = JSON.stringify(event.deviceContext);
    for (const { pattern, name } of Object.values(PII_PATTERNS)) {
      if (pattern.test(deviceStr)) {
        violations.push(`${name} found in deviceContext`);
      }
    }
  }
  
  // Check component ID
  if (event.componentId) {
    for (const { pattern, name } of Object.values(PII_PATTERNS)) {
      if (pattern.test(event.componentId)) {
        violations.push(`${name} found in componentId`);
      }
    }
  }
  
  // Check state values
  if (event.stateBefore) {
    for (const { pattern, name } of Object.values(PII_PATTERNS)) {
      if (pattern.test(event.stateBefore)) {
        violations.push(`${name} found in stateBefore`);
      }
    }
  }
  
  if (event.stateAfter) {
    for (const { pattern, name } of Object.values(PII_PATTERNS)) {
      if (pattern.test(event.stateAfter)) {
        violations.push(`${name} found in stateAfter`);
      }
    }
  }
  
  return {
    valid: violations.length === 0,
    violations,
  };
}

