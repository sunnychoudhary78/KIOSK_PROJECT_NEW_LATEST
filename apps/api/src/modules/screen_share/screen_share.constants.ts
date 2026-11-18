/** Pending session without kiosk ack expires after this window. */
export const SCREEN_SHARE_PENDING_TTL_MS = 2 * 60 * 1000;

/** How many expired/terminal rows to close per sweep tick. */
export const SCREEN_SHARE_EXPIRE_BATCH_SIZE = 50;
