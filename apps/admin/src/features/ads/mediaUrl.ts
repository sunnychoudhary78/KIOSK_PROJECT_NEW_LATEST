/** Normalize creative media paths for `${apiBaseUrl}${path}` fetches. */
export function adsMediaPath(mediaUrl: string | null | undefined): string | null {
  if (!mediaUrl) return null;
  if (/^https?:\/\//i.test(mediaUrl)) {
    try {
      const url = new URL(mediaUrl);
      return `${url.pathname}${url.search}`;
    } catch {
      return mediaUrl;
    }
  }
  if (mediaUrl.startsWith('/v1/')) {
    return mediaUrl.slice(3);
  }
  return mediaUrl.startsWith('/') ? mediaUrl : `/${mediaUrl}`;
}

export function isVideoMime(mimeType: string | null | undefined, mediaUrl?: string | null): boolean {
  if (mimeType?.startsWith('video/')) return true;
  const path = (mediaUrl ?? '').toLowerCase();
  return /\.(mp4|webm|mov|m4v)(\?|$)/.test(path);
}

export function isImageMime(mimeType: string | null | undefined, mediaUrl?: string | null): boolean {
  if (mimeType?.startsWith('image/')) return true;
  const path = (mediaUrl ?? '').toLowerCase();
  return /\.(png|jpe?g|gif|webp|bmp|svg)(\?|$)/.test(path);
}
