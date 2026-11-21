/** Pending command without kiosk ack expires after this window. */
export const SURVEILLANCE_COMMAND_PENDING_TTL_MS = 2 * 60 * 1000;

/** Longer window for zip build + R2 upload of diagnostics bundles. */
export const SURVEILLANCE_COMMAND_COLLECT_DIAGNOSTICS_TTL_MS = 10 * 60 * 1000;

/** How many expired rows to close per sweep tick. */
export const SURVEILLANCE_COMMAND_EXPIRE_BATCH_SIZE = 50;
