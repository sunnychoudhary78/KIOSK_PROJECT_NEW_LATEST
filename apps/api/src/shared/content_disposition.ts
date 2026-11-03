/** Make a basename safe for HTTP Content-Disposition `filename="..."` (ASCII only). */
export function asciiFilename(name: string, fallback = 'document.pdf'): string {
  const trimmed = name.trim();
  const withDashes = trimmed
    .replace(/[\u2010-\u2015\u2212]/g, '-') // hyphen / dash variants including em/en dash
    .replace(/[\u2018\u2019\u201A\u201B]/g, "'")
    .replace(/[\u201C\u201D\u201E\u201F]/g, '')
    .replace(/["\\\r\n\t]/g, '')
    .replace(/[\\/:*?<>|]/g, '-')
    .replace(/[^\x20-\x7E]/g, '')
    .replace(/\s+/g, ' ')
    .trim();

  const cleaned = withDashes.replace(/^\.+/, '').replace(/\.+$/, '').trim();
  if (!cleaned) return fallback;
  return cleaned.slice(0, 180);
}

/**
 * Build an inline Content-Disposition value Node can set without ERR_INVALID_CHAR.
 * Uses ASCII `filename=` plus optional RFC 5987 `filename*` for the original name.
 */
export function contentDispositionInline(rawName: string, ensurePdfExt = false): string {
  let ascii = asciiFilename(rawName);
  if (ensurePdfExt && !/\.pdf$/i.test(ascii)) {
    ascii = `${ascii}.pdf`;
  }

  const parts = [`inline; filename="${ascii}"`];
  const original = rawName.trim().replace(/[\r\n"]/g, '');
  if (original && /[^\x20-\x7E]/.test(original)) {
    const encoded = encodeURIComponent(original).replace(/['()]/g, escape);
    parts.push(`filename*=UTF-8''${encoded}`);
  }
  return parts.join('; ');
}
