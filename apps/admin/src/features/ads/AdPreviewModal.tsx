import { useEffect, useMemo, useState } from 'react';
import { ChevronLeft, ChevronRight, Play } from 'lucide-react';
import { apiRequestBlob } from '../../core/api/client';
import { useAuth } from '../../core/auth/auth-context';
import { Button, Modal, StatusBadge } from '../../core/ui/primitives';
import { adsMediaPath, isImageMime, isVideoMime } from './mediaUrl';
import type { Creative } from './types';

type PreviewItem = {
  key: string;
  label: string;
  mediaUrl: string;
  path: string | null;
  absolute: boolean;
  mimeType: string | null;
};

function toPreviewItem(
  key: string,
  label: string,
  mediaUrl: string | null | undefined,
  mimeType: string | null | undefined,
): PreviewItem | null {
  if (!mediaUrl) return null;
  const absolute = /^https?:\/\//i.test(mediaUrl);
  return {
    key,
    label,
    mediaUrl,
    path: absolute ? null : adsMediaPath(mediaUrl),
    absolute,
    mimeType: mimeType ?? null,
  };
}

function collectPreviewItems(creative: Creative): PreviewItem[] {
  const assets = [...(creative.assets ?? [])].sort((a, b) => a.sortOrder - b.sortOrder);
  if (assets.length > 0) {
    return assets
      .map((asset, index) =>
        toPreviewItem(asset.id, `Slide ${index + 1}`, asset.mediaUrl, asset.mimeType),
      )
      .filter((item): item is PreviewItem => item != null);
  }

  const item = toPreviewItem(creative.id, creative.title, creative.mediaUrl, creative.mimeType);
  return item ? [item] : [];
}

function slotLabel(slot?: string | null) {
  if (!slot) return null;
  if (slot === 'idle_video') return 'Idle screen';
  if (slot === 'home_banner') return 'Horizontal banner';
  if (slot === 'home_banner_vertical') return 'Vertical banner';
  return slot.replace(/_/g, ' ');
}

export function AdPreviewModal({
  open,
  creative,
  slot,
  onClose,
}: {
  open: boolean;
  creative: Creative | null;
  slot?: string | null;
  onClose: () => void;
}) {
  const { token } = useAuth();
  const items = useMemo(() => (creative ? collectPreviewItems(creative) : []), [creative]);
  const [index, setIndex] = useState(0);
  const [objectUrl, setObjectUrl] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const current = items[index] ?? null;
  const isVideo = current
    ? isVideoMime(current.mimeType, current.mediaUrl) || creative?.type === 'video'
    : false;
  const isImage = current
    ? isImageMime(current.mimeType, current.mediaUrl) ||
      creative?.type === 'image' ||
      creative?.type === 'banner' ||
      creative?.type === 'banner_vertical' ||
      creative?.type === 'carousel'
    : false;

  useEffect(() => {
    if (!open) {
      setIndex(0);
      setError(null);
      setObjectUrl((prev) => {
        if (prev) URL.revokeObjectURL(prev);
        return null;
      });
    }
  }, [open]);

  useEffect(() => {
    setIndex(0);
  }, [creative?.id]);

  useEffect(() => {
    if (!open || !current) return;

    let cancelled = false;
    let createdUrl: string | null = null;
    const item = current;

    async function load() {
      setLoading(true);
      setError(null);
      setObjectUrl((prev) => {
        if (prev) URL.revokeObjectURL(prev);
        return null;
      });
      try {
        const blob = item.absolute
          ? await fetch(item.mediaUrl).then(async (response) => {
              if (!response.ok) {
                throw new Error(`Failed to load media (${response.status})`);
              }
              return response.blob();
            })
          : await apiRequestBlob(item.path ?? item.mediaUrl, { token });
        if (cancelled) return;
        createdUrl = URL.createObjectURL(blob);
        setObjectUrl(createdUrl);
      } catch (err) {
        if (!cancelled) {
          setError(err instanceof Error ? err.message : 'Failed to load media');
        }
      } finally {
        if (!cancelled) setLoading(false);
      }
    }

    void load();

    return () => {
      cancelled = true;
      if (createdUrl) URL.revokeObjectURL(createdUrl);
    };
  }, [open, current?.key, current?.mediaUrl, current?.path, current?.absolute, token]);

  // Auto-advance carousel slides when previewing photo carousels.
  useEffect(() => {
    if (!open || !creative || creative.type !== 'carousel' || items.length < 2 || isVideo) {
      return;
    }
    const timer = window.setInterval(() => {
      setIndex((value) => (value + 1) % items.length);
    }, 3500);
    return () => window.clearInterval(timer);
  }, [open, creative?.id, creative?.type, items.length, isVideo]);

  const frameClass =
    slot === 'home_banner'
      ? 'aspect-[8/1] max-h-40 w-full'
      : slot === 'home_banner_vertical'
        ? 'aspect-[2/9] mx-auto h-[28rem] max-h-[55vh] w-auto'
        : 'aspect-video w-full';

  return (
    <Modal
      open={open && creative != null}
      title={creative ? `Ad preview · ${creative.title}` : 'Ad preview'}
      description={
        creative
          ? [
              slotLabel(slot),
              creative.type.replace(/_/g, ' '),
              creative.durationSec ? `${creative.durationSec}s` : null,
            ]
              .filter(Boolean)
              .join(' · ')
          : undefined
      }
      className="max-w-3xl"
      onClose={onClose}
      footer={
        <Button type="button" variant="ghost" onClick={onClose}>
          Close
        </Button>
      }
    >
      {!creative ? null : (
        <div className="space-y-4">
          <div className="flex flex-wrap items-center gap-2">
            <StatusBadge status={creative.type} />
            {slot ? <StatusBadge status={slot} /> : null}
            {items.length > 1 ? (
              <span className="text-xs text-muted-foreground">
                {index + 1} / {items.length}
              </span>
            ) : null}
          </div>

          <div className="overflow-hidden rounded-xl border border-border bg-slate-950">
            <div className={`relative grid place-items-center bg-slate-950 ${frameClass}`}>
              {loading ? (
                <p className="text-sm text-slate-300">Loading media…</p>
              ) : error ? (
                <p className="px-4 text-center text-sm text-red-300">{error}</p>
              ) : objectUrl && isVideo ? (
                <video
                  key={objectUrl}
                  src={objectUrl}
                  controls
                  autoPlay
                  playsInline
                  className="h-full max-h-[55vh] w-full object-contain"
                />
              ) : objectUrl && isImage ? (
                <img
                  key={objectUrl}
                  src={objectUrl}
                  alt={creative.title}
                  className="h-full max-h-[55vh] w-full object-contain"
                />
              ) : objectUrl ? (
                <video
                  key={objectUrl}
                  src={objectUrl}
                  controls
                  autoPlay
                  playsInline
                  className="h-full max-h-[55vh] w-full object-contain"
                />
              ) : (
                <div className="flex flex-col items-center gap-2 text-slate-400">
                  <Play className="h-8 w-8 opacity-50" />
                  <p className="text-sm">No media available</p>
                </div>
              )}
            </div>
          </div>

          {items.length > 1 ? (
            <div className="flex items-center justify-between gap-2">
              <Button
                type="button"
                variant="secondary"
                className="h-8 px-3"
                onClick={() => setIndex((value) => (value - 1 + items.length) % items.length)}
              >
                <ChevronLeft className="h-4 w-4" />
                Prev
              </Button>
              <p className="truncate text-sm text-muted-foreground">{current?.label}</p>
              <Button
                type="button"
                variant="secondary"
                className="h-8 px-3"
                onClick={() => setIndex((value) => (value + 1) % items.length)}
              >
                Next
                <ChevronRight className="h-4 w-4" />
              </Button>
            </div>
          ) : null}
        </div>
      )}
    </Modal>
  );
}
