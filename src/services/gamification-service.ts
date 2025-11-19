import { supabase } from '../config/database-config.js';
import { logError, logInfo } from '../shared/logger-shared.js';
import { UserProgress } from '../types/feature-types.js';

/**
 * Get user progress
 */
export async function getUserProgress(userId: string): Promise<UserProgress | null> {
    try {
        const { data, error } = await supabase
            .from('user_progress')
            .select('*')
            .eq('user_id', userId)
            .single();

        if (error && error.code !== 'PGRST116') { // Ignore not found
            throw error;
        }

        return data as UserProgress;
    } catch (error: any) {
        logError('Failed to get user progress', error);
        return null;
    }
}

/**
 * Award XP to user
 */
export async function awardXP(userId: string, amount: number) {
    try {
        // Get current progress or create
        let progress = await getUserProgress(userId);

        if (!progress) {
            const { data, error } = await supabase
                .from('user_progress')
                .insert({ user_id: userId, xp: amount, level: 1, badges: [] })
                .select()
                .single();

            if (error) throw error;
            progress = data as UserProgress;
        } else {
            // Update XP and Level
            const newXP = progress.xp + amount;
            const newLevel = Math.floor(newXP / 1000) + 1; // Simple level formula

            const { error } = await supabase
                .from('user_progress')
                .update({ xp: newXP, level: newLevel, last_activity_date: new Date().toISOString() })
                .eq('user_id', userId);

            if (error) throw error;
        }

        logInfo(`Awarded ${amount} XP to user ${userId}`);
    } catch (error: any) {
        logError('Failed to award XP', error);
        // Don't throw, gamification shouldn't block core features
    }
}

/**
 * Award Badge
 */
export async function awardBadge(userId: string, badgeId: string) {
    try {
        const progress = await getUserProgress(userId);
        if (!progress) return; // Should have progress if getting badges

        if (!progress.badges.includes(badgeId)) {
            const newBadges = [...progress.badges, badgeId];

            const { error } = await supabase
                .from('user_progress')
                .update({ badges: newBadges })
                .eq('user_id', userId);

            if (error) throw error;
            logInfo(`Awarded badge ${badgeId} to user ${userId}`);
        }
    } catch (error: any) {
        logError('Failed to award badge', error);
    }
}
