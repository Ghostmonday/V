/**
 * Type declarations for optional @livekit/server-sdk module
 * This allows the build to succeed even if the package is not installed
 */
declare module '@livekit/server-sdk' {
  export class TokenGenerator {
    constructor(apiKey: string, apiSecret: string);
    createToken(
      grants: { video: { roomJoin: boolean; room: string } },
      options: { identity: string }
    ): string;
  }
}
