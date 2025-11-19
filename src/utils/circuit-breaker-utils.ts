/**
 * Circuit Breaker Pattern
 * Prevents cascading failures by opening circuit when errors exceed threshold
 */

import { logError, logWarning, logInfo } from '../shared/logger-shared.js';

export interface CircuitBreakerOptions {
  failureThreshold: number; // Number of failures before opening circuit
  resetTimeout: number; // Time in ms before attempting to reset
  monitoringWindow: number; // Time window in ms for failure counting
}

export enum CircuitState {
  CLOSED = 'CLOSED', // Normal operation
  OPEN = 'OPEN', // Circuit is open, requests fail fast
  HALF_OPEN = 'HALF_OPEN', // Testing if service recovered
}

export class CircuitBreaker {
  private state: CircuitState = CircuitState.CLOSED;
  private failures: number = 0;
  private lastFailureTime: number = 0;
  private successCount: number = 0;
  private readonly options: CircuitBreakerOptions;

  constructor(options: Partial<CircuitBreakerOptions> = {}) {
    this.options = {
      failureThreshold: options.failureThreshold || 5,
      resetTimeout: options.resetTimeout || 60000, // 1 minute
      monitoringWindow: options.monitoringWindow || 60000, // 1 minute
    };
  }

  /**
   * Execute function with circuit breaker protection
   */
  async execute<T>(fn: () => Promise<T>, fallback?: () => Promise<T>): Promise<T> {
    // Check circuit state
    if (this.state === CircuitState.OPEN) {
      const timeSinceLastFailure = Date.now() - this.lastFailureTime;
      if (timeSinceLastFailure >= this.options.resetTimeout) {
        // Try to reset circuit
        this.state = CircuitState.HALF_OPEN;
        this.successCount = 0;
        logInfo('Circuit breaker entering HALF_OPEN state', {
          service: 'media-stream',
        });
      } else {
        // Circuit still open, fail fast
        logWarning('Circuit breaker OPEN - request rejected', {
          service: 'media-stream',
          timeUntilReset: this.options.resetTimeout - timeSinceLastFailure,
        });
        if (fallback) {
          return await fallback();
        }
        throw new Error('Circuit breaker is OPEN - service unavailable');
      }
    }

    try {
      const result = await fn();
      this.onSuccess();
      return result;
    } catch (error: any) {
      this.onFailure();
      if (fallback) {
        logWarning('Circuit breaker fallback triggered', {
          service: 'media-stream',
          error: error.message,
        });
        return await fallback();
      }
      throw error;
    }
  }

  /**
   * Handle successful execution
   */
  private onSuccess(): void {
    this.failures = 0;

    if (this.state === CircuitState.HALF_OPEN) {
      this.successCount++;
      // If we get enough successes in half-open, close the circuit
      if (this.successCount >= 2) {
        this.state = CircuitState.CLOSED;
        logInfo('Circuit breaker CLOSED - service recovered', {
          service: 'media-stream',
        });
      }
    }
  }

  /**
   * Handle failed execution
   */
  private onFailure(): void {
    this.failures++;
    this.lastFailureTime = Date.now();

    if (this.state === CircuitState.HALF_OPEN) {
      // Failed in half-open, open circuit again
      this.state = CircuitState.OPEN;
      logError('Circuit breaker OPENED - service still failing', {
        service: 'media-stream',
      });
    } else if (this.failures >= this.options.failureThreshold) {
      // Too many failures, open circuit
      this.state = CircuitState.OPEN;
      logError('Circuit breaker OPENED - failure threshold exceeded', {
        service: 'media-stream',
        failures: this.failures,
        threshold: this.options.failureThreshold,
      });
    }
  }

  /**
   * Get current circuit state
   */
  getState(): CircuitState {
    return this.state;
  }

  /**
   * Reset circuit breaker (for testing)
   */
  reset(): void {
    this.state = CircuitState.CLOSED;
    this.failures = 0;
    this.successCount = 0;
    this.lastFailureTime = 0;
  }
}

// Singleton circuit breaker for media stream operations
export const mediaStreamCircuitBreaker = new CircuitBreaker({
  failureThreshold: 5,
  resetTimeout: 30000, // 30 seconds
  monitoringWindow: 60000, // 1 minute
});
