/**
 * Generated API types (finalized placeholders)
 * Use openapi-typescript / ts-proto in CI to generate real types from specs.
 */

export interface AuthAppleRequest { token: string; }
export interface AuthAppleResponse { jwt: string; livekitToken: string; }
export interface LoginRequest { username: string; password: string; }
export interface FileUploadResponse { url: string; }
export interface PresenceStatus { status: string; }
export interface Message { id?: string; content: string; senderId?: string; ts?: number; }
export interface Config { [key: string]: any; }
export interface TelemetryEvent { event: string; metadata?: any; }
export interface Recommendation { recommendation: any; }

