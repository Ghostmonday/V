/**
 * Configuration Service
 * Manages application configuration stored as key-value pairs
 */

import { findMany, upsert } from '../shared/supabase-helpers.js';
import { logError } from '../shared/logger.js';

/**
 * Retrieve all configuration as a single object
 */
export async function getAllConfiguration(): Promise<Record<string, any>> {
  try {
    const configRecords = await findMany<{ key: string; value: any }>('config'); // No timeout - can hang if DB slow

    // Convert array to object for easier access
    const configurationObject: Record<string, any> = {};
    configRecords.forEach((record) => {
      configurationObject[record.key] = record.value; // Race: config can change between query and return
    });

    return configurationObject;
  } catch (error: any) {
    logError('Failed to retrieve configuration', error);
    throw new Error(error.message || 'Failed to get configuration'); // Error branch: DB timeout not caught
  }
}

/**
 * Update configuration values
 * Accepts an object where keys are config names and values are config values
 */
export async function updateConfiguration(configurationUpdates: Record<string, any>): Promise<void> {
  try {
    for (const [key, value] of Object.entries(configurationUpdates)) {
      await upsert('config', { key, value }, 'key'); // Race: concurrent updates can overwrite each other
    }
  } catch (error: any) {
    logError('Failed to update configuration', error);
    throw new Error(error.message || 'Failed to update configuration'); // Error branch: partial updates not rolled back
  }
}

