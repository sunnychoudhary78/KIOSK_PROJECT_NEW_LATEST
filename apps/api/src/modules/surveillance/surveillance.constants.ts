/** Reject stub / truncated segments below this size (bytes). */
export const MIN_SURVEILLANCE_SEGMENT_BYTES = 1024;

/** Pending uploads older than this with an error are treated as failed in admin UI. */
export const PENDING_UPLOAD_STALE_MS = 6 * 60 * 60 * 1000;
