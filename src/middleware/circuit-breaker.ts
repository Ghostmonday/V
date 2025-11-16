/**
 * Circuit Breaker Pattern Implementation
 * Prevents cascading failures by stopping requests to failing services
 */

import { logError, logInfo, logWarning } from '../shared/logger.js';

export enum CircuitState {
  CLOSED = 'CLOSED', // Normal operation
  OPEN = 'OPEN', // Service is failing, reject requests
  HALF_OPEN = 'HALF_OPEN', // Testing if service recovered
}

export interface CircuitBreakerOptions {
  failureThreshold: number; // Number of failures before opening
  timeout: number; // Time in ms before attempting half-open
  resetTimeout: number; // Time in ms before resetting failure count
  monitoringPeriod: number; // Time window for failure counting
}

const defaultOptions: CircuitBreakerOptions = {
  failureThreshold: 5,
  timeout: 60000, // 1 minute
  resetTimeout: 300000, // 5 minutes
  monitoringPeriod: 60000, // 1 minute
};

export class CircuitBreaker {
  private state: CircuitState = CircuitState.CLOSED;
  private failureCount: number = 0;
  private successCount: number = 0;
  private nextAttempt: number = Date.now();
  private lastFailureTime: number = 0;
  private failureTimes: number[] = [];
  private options: CircuitBreakerOptions;

  constructor(
    private name: string,
    options: Partial<CircuitBreakerOptions> = {}
  ) {
    this.options = { ...defaultOptions, ...options };
  }

  /**
   * Execute a function with circuit breaker protection
   * 
   * Implements three-state circuit breaker pattern:
   * - CLOSED: Normal operation, requests pass through
   * - OPEN: Service failing, requests rejected immediately
   * - HALF_OPEN: Testing recovery, allow limited requests
   */
  async call<T>(serviceFn: () => Promise<T>): Promise<T> {
    // Check if circuit is OPEN (service is failing)
    if (this.state === CircuitState.OPEN) {
      // Check if timeout period has elapsed (ready to test recovery)
      if (Date.now() < this.nextAttempt) {
        // Still in timeout period - reject immediately (fast fail)
        throw new Error(`Circuit breaker ${this.name} is OPEN. Service unavailable.`);
      }
      // Timeout elapsed - transition to HALF_OPEN to test if service recovered
      this.state = CircuitState.HALF_OPEN;
      this.successCount = 0; // Reset success counter for half-open testing
      logInfo(`Circuit breaker ${this.name} transitioning to HALF_OPEN`);
    }

    // Clean old failure times outside monitoring window
    // Only count failures within monitoringPeriod (e.g., last 60 seconds)
    // This allows circuit to recover if failures stop
    const now = Date.now();
    this.failureTimes = this.failureTimes.filter(
      (time) => now - time < this.options.monitoringPeriod // Race: failures can occur during filter = miscount
    );

    try {
      // Execute the service function (e.g., database query, API call)
      const result = await serviceFn();
      // Success - update circuit breaker state
      this.onSuccess();
      return result;
    } catch (error: any) {
      // Failure - record and potentially open circuit
      this.onFailure();
      throw error; // Re-throw original error to caller
    }
  }

  /**
   * Handle successful service call
   * Resets failure tracking and manages state transitions
   */
  private onSuccess(): void {
    // Reset failure tracking (service is working now)
    this.failureCount = 0;
    this.failureTimes = []; // Clear failure history

    if (this.state === CircuitState.HALF_OPEN) {
      // We're testing recovery - increment success counter
      this.successCount++; // Race: concurrent requests can increment simultaneously = double-count
      // Require 2 consecutive successes before closing circuit
      // This prevents flapping (rapid open/close cycles) from intermittent issues
      if (this.successCount >= 2) {
        this.state = CircuitState.CLOSED; // Service recovered - resume normal operation
        logInfo(`Circuit breaker ${this.name} recovered and is now CLOSED`);
      }
    } else {
      // Already CLOSED - ensure it stays closed (redundant but safe)
      this.state = CircuitState.CLOSED;
    }
  }

  /**
   * Handle failed service call
   * Records failure and opens circuit if threshold exceeded
   */
  private onFailure(): void {
    const now = Date.now();
    
    // Record this failure timestamp
    this.failureTimes.push(now);
    this.lastFailureTime = now;
    
    // Update failure count (only failures within monitoring window count)
    this.failureCount = this.failureTimes.length;

    if (this.state === CircuitState.HALF_OPEN) {
      // Failed while testing recovery - service still broken
      // Immediately reopen circuit (don't wait for more failures)
      this.state = CircuitState.OPEN;
      this.nextAttempt = now + this.options.timeout; // Wait before testing again
      logWarning(`Circuit breaker ${this.name} failed in HALF_OPEN, reopening`);
      return; // Early return - don't check threshold
    }

    // Check if failure threshold exceeded (e.g., 5 failures in monitoring window)
    if (this.failureCount >= this.options.failureThreshold) {
      // Too many failures - open circuit to stop cascading failures
      this.state = CircuitState.OPEN;
      this.nextAttempt = now + this.options.timeout; // Set timeout before retry
      logError(`Circuit breaker ${this.name} opened after ${this.failureCount} failures`);
    }
    // If threshold not exceeded, stay CLOSED (allow requests to continue)
  }

  /**
   * Get current circuit breaker state
   */
  getState(): CircuitState {
    return this.state;
  }

  /**
   * Get statistics
   */
  getStats() {
    return {
      name: this.name,
      state: this.state,
      failureCount: this.failureCount,
      successCount: this.successCount,
      nextAttempt: this.nextAttempt,
      lastFailureTime: this.lastFailureTime,
    };
  }

  /**
   * Manually reset circuit breaker
   */
  reset(): void {
    this.state = CircuitState.CLOSED;
    this.failureCount = 0;
    this.successCount = 0;
    this.failureTimes = [];
    this.nextAttempt = Date.now();
    logInfo(`Circuit breaker ${this.name} manually reset`);
  }
}

// Create circuit breakers for different services
export const supabaseCircuitBreaker = new CircuitBreaker('supabase', {
  failureThreshold: 5,
  timeout: 30000, // 30 seconds
});

export const redisCircuitBreaker = new CircuitBreaker('redis', {
  failureThreshold: 3,
  timeout: 10000, // 10 seconds
});

export const s3CircuitBreaker = new CircuitBreaker('s3', {
  failureThreshold: 5,
  timeout: 60000, // 1 minute
});

