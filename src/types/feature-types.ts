export interface Invite {
    id: string;
    code: string;
    created_by: string;
    created_at: string;
    expires_at?: string;
    max_uses?: number;
    uses: number;
}

export interface UserProgress {
    user_id: string;
    xp: number;
    level: number;
    badges: string[];
    current_streak: number;
    last_activity_date?: string;
    credits: number;
}

export interface ScheduledCall {
    id: string;
    room_id: string;
    scheduler_id: string;
    scheduled_time: string;
    title?: string;
    created_at: string;
}

export interface UserSubscription {
    user_id: string;
    tier: 'free' | 'pro' | 'enterprise';
    status: 'active' | 'canceled' | 'past_due';
    current_period_end?: string;
    created_at: string;
    updated_at: string;
}

export interface QuietHoursSettings {
    enabled: boolean;
    start?: string; // HH:mm:ss
    end?: string;   // HH:mm:ss
}

export interface UserProfileExtended {
    mood_indicator?: string;
    mood_updated_at?: string;
    quiet_hours?: QuietHoursSettings;
}
