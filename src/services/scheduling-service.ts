import { supabase } from '../config/database-config.js';
import { logError, logInfo } from '../shared/logger-shared.js';
import { ScheduledCall } from '../types/feature-types.js';

/**
 * Schedule a call
 */
export async function scheduleCall(
    userId: string,
    roomId: string,
    scheduledTime: string,
    title?: string
): Promise<ScheduledCall> {
    try {
        const { data, error } = await supabase
            .from('scheduled_calls')
            .insert({
                scheduler_id: userId,
                room_id: roomId,
                scheduled_time: scheduledTime,
                title,
            })
            .select()
            .single();

        if (error) throw error;

        logInfo(`Call scheduled by ${userId} for ${scheduledTime}`);
        return data as ScheduledCall;
    } catch (error: any) {
        logError('Failed to schedule call', error);
        throw error;
    }
}

/**
 * Get upcoming calls for a room
 */
export async function getRoomScheduledCalls(roomId: string): Promise<ScheduledCall[]> {
    try {
        const { data, error } = await supabase
            .from('scheduled_calls')
            .select('*')
            .eq('room_id', roomId)
            .gte('scheduled_time', new Date().toISOString())
            .order('scheduled_time', { ascending: true });

        if (error) throw error;

        return data as ScheduledCall[];
    } catch (error: any) {
        logError('Failed to get scheduled calls', error);
        return [];
    }
}
