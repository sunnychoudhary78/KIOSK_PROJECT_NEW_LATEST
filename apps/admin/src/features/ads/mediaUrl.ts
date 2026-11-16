import { config } from '../../core/config';

/** Normalize creative media paths for `${apiBaseUrl}${path}` fetches. */
export function adsMediaPath(mediaUrl: string | null | undefined): string | null {
  if (!mediaUrl) return null;
  if (/^https?:\/\//i.test(mediaUrl)) {
    try {
      const url = new URL(mediaUrl);
      const api = new URL(config.apiBaseUrl);
      // Same-origin API URLs → use pathname relative to /v1
      if (url.origin === api.origin) {
        let path = `${url.pathname}${url.search}`;
        if (path.startsWith('/v1/')) path = path.slice(3);
        return path;
      }
      return null; // external absolute URL — not an API path
    } catch {
      return null;
    }
  }
  if (mediaUrl.startsWith('/v1/')) {
    return mediaUrl.slice(3);
  }
  return mediaUrl.startsWith('/') ? mediaUrl : `/${mediaUrl}`;
}

/** Always prefer authenticated streaming endpoints for admin preview. */
export function creativePreviewPath(creativeId: string): string {
  return `/ads/media/${creativeId}`;
}

export function assetPreviewPath(assetId: string): string {
  return `/ads/media/asset/${assetId}`;
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
