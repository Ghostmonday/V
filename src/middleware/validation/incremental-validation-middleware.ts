import { z } from 'zod';
import { logError } from '../../shared/logger-shared.js';

export function validateServiceData<T>(data: any, schema: any, context: string): T {
    try {
        return schema.parse(data);
    } catch (error) {
        logError(`Validation failed in ${context}`, error instanceof Error ? error : new Error(String(error)));
        throw error;
    }
}

export function validateBeforeDB<T>(data: any, schema: any, context: string): T {
    return validateServiceData(data, schema, context);
}

export function validateAfterDB<T>(data: any, schema: any, context: string): T {
    return validateServiceData(data, schema, context);
}
