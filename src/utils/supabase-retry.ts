import { PostgrestError } from '@supabase/supabase-js';
import { logWarning } from '../shared/logger-shared.js';

interface RetryOptions {
    retries?: number;
    minTimeout?: number;
    maxTimeout?: number;
    factor?: number;
}

const DEFAULT_OPTIONS: RetryOptions = {
    retries: 3,
    minTimeout: 1000,
    maxTimeout: 5000,
    factor: 2,
};

/**
 * Retry a Supabase query with exponential backoff
 * @param operation Function that returns a Supabase query promise
 * @param options Retry options
 */
export async function withRetry<T>(
    operation: () => Promise<{ data: T | null; error: PostgrestError | null }>,
    options: RetryOptions = {}
): Promise<{ data: T | null; error: PostgrestError | null }> {
    const opts = { ...DEFAULT_OPTIONS, ...options };
    let attempt = 0;

    while (attempt < (opts.retries || 3)) {
        try {
            const result = await operation();

            // If successful or if error is not a network/timeout error (e.g. validation error), return immediately
            if (!result.error) {
                return result;
            }

            // Check if error is retryable (network issues, timeouts, 5xx)
            // Supabase errors don't always have clear codes for network issues, but we can check message
            const isRetryable = isRetryableError(result.error);

            if (!isRetryable) {
                return result;
            }

            throw result.error; // Throw to trigger retry logic
        } catch (error: any) {
            attempt++;

            if (attempt >= (opts.retries || 3)) {
                // Return the last error result if we have one, otherwise rethrow
                if (error && 'code' in error) {
                    return { data: null, error: error as PostgrestError };
                }
                throw error;
            }

            // Calculate delay with jitter
            const delay = Math.min(
                (opts.minTimeout || 1000) * Math.pow(opts.factor || 2, attempt - 1),
                opts.maxTimeout || 5000
            );
            const jitter = Math.random() * 100;

            logWarning(`Supabase query failed, retrying (${attempt}/${opts.retries})...`, error);
            await new Promise((resolve) => setTimeout(resolve, delay + jitter));
        }
    }

    return { data: null, error: { message: 'Max retries exceeded', code: 'TIMEOUT', details: '', hint: '', name: 'PostgrestError' } };
}

function isRetryableError(error: PostgrestError): boolean {
    // Network errors, timeouts, 502/503/504 equivalent
    const message = error.message.toLowerCase();
    return (
        message.includes('fetch') ||
        message.includes('network') ||
        message.includes('timeout') ||
        message.includes('connection') ||
        message.includes('upstream')
    );
}
