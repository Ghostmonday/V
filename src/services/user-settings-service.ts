import { supabase } from '../config/database-config.js';
import { logError, logInfo } from '../shared/logger-shared.js';
import { QuietHoursSettings } from '../types/feature-types.js';

/**
 * Update Quiet Hours
 */
export async function updateQuietHours(userId: string, settings: QuietHoursSettings) {
    try {
        const { error } = await supabase
            .from('users')
            .update({
                quiet_hours_enabled: settings.enabled,
                quiet_hours_start: settings.start,
                quiet_hours_end: settings.end,
            })
            .eq('id', userId);

        if (error) throw error;

        logInfo(`Quiet hours updated for user ${userId}`);
        return { success: true };
    } catch (error: any) {
        logError('Failed to update quiet hours', error);
        throw error;
    }
}

/**
 * Update Mood
 */
export async function updateMood(userId: string, mood: string) {
    try {
        const { error } = await supabase
            .from('users')
            .update({
                mood_indicator: mood,
                mood_updated_at: new Date().toISOString(),
            })
            .eq('id', userId);

        if (error) throw error;

        logInfo(`Mood updated for user ${userId}: ${mood}`);
        return { success: true };
    } catch (error: any) {
        logError('Failed to update mood', error);
        throw error;
    }
}
