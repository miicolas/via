export type MeetupServiceErrorReason =
  | 'not_found'
  | 'unauthorized'
  | 'forbidden'
  | 'expired'
  | 'revoked'
  | 'full'
  | 'invalid_time'
  | 'conflict'
  | 'privacy'
  | 'corrupt';

export class MeetupServiceError extends Error {
  constructor(readonly reason: MeetupServiceErrorReason) {
    super(`Meetup operation failed: ${reason}`);
    this.name = 'MeetupServiceError';
  }
}
