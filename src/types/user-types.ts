/**
 * User type definitions
 * Shared across authentication and user management services
 */

export interface User {
    id: string;
    username: string;
    email?: string;
    created_at: string;
    updated_at?: string;
    last_login?: string;
    is_anonymous?: boolean;
    tier?: string;
    handle?: string;
}

export interface UserCredentials {
    username: string;
    password?: string;
    email?: string;
}

export interface UserProfile {
    id: string;
    user_id: string;
    display_name?: string;
    avatar_url?: string;
    bio?: string;
    created_at: string;
    updated_at?: string;
}

export interface AuthResponse {
    user: User;
    token: string;
    refreshToken?: string;
    expiresIn?: number;
}
