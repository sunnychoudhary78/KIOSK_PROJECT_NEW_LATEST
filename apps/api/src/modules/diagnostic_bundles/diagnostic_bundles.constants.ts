/** Max zip size accepted for a diagnostics bundle (~50MB logs + slack). */
export const MAX_DIAGNOSTIC_BUNDLE_BYTES = 60 * 1024 * 1024;

/** How long a completed bundle remains downloadable. */
export const DIAGNOSTIC_BUNDLE_RETENTION_DAYS = 7;

/** Keep this many recent bundles per device; older ones are purged on create. */
export const DIAGNOSTIC_BUNDLE_KEEP_PER_DEVICE = 3;
