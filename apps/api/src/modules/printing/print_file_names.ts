/** Sanitize an upload name for UI / DB display — keeps the original extension. */
export function sanitizeDisplayName(original: string): string {
  const cleaned = original.replace(/[^\w.\- ()[\]]+/g, '_').slice(0, 180) || 'document';
  return cleaned;
}

/** Force a `.pdf` extension for on-disk storage of normalized print PDFs. */
export function storagePdfName(displayName: string): string {
  const cleaned = sanitizeDisplayName(displayName);
  return cleaned.toLowerCase().endsWith('.pdf')
    ? cleaned
    : `${cleaned.replace(/\.[^.]+$/, '') || cleaned}.pdf`;
}
