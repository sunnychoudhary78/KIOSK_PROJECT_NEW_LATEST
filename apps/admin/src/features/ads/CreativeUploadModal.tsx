import { useState, type FormEvent } from 'react';
import { apiUploadFormData } from '../../core/api/client';
import { useAuth } from '../../core/auth/auth-context';
import { Button, Input, Modal } from '../../core/ui/primitives';
import type { Creative } from './types';

export type UploadPurpose = 'idle' | 'banner_horizontal' | 'banner_vertical';

/** Matches API multer limit in apps/api/src/modules/ads/index.ts */
export const ADS_MAX_UPLOAD_BYTES = 80 * 1024 * 1024;
const ADS_MAX_UPLOAD_MB = 80;

const HORIZONTAL_TARGET = { width: 1920, height: 240, label: '1920×240 (8:1)' };
const VERTICAL_TARGET = { width: 240, height: 1080, label: '240×1080 (~2:9)' };

function aspectRatio(width: number, height: number): number {
  return width / Math.max(height, 1);
}

function formatMb(bytes: number): string {
  return (bytes / (1024 * 1024)).toFixed(1);
}

function findOversizedFile(files: File[]): File | null {
  return files.find((file) => file.size > ADS_MAX_UPLOAD_BYTES) ?? null;
}

function oversizedMessage(file: File): string {
  return `${file.name} is ${formatMb(file.size)} MB. Maximum upload size is ${ADS_MAX_UPLOAD_MB} MB.`;
}

function loadImageSize(file: File): Promise<{ width: number; height: number }> {
  return new Promise((resolve, reject) => {
    const url = URL.createObjectURL(file);
    const img = new Image();
    img.onload = () => {
      URL.revokeObjectURL(url);
      resolve({ width: img.naturalWidth, height: img.naturalHeight });
    };
    img.onerror = () => {
      URL.revokeObjectURL(url);
      reject(new Error('Could not read image dimensions'));
    };
    img.src = url;
  });
}

async function softAspectWarning(
  purpose: UploadPurpose,
  file: File,
): Promise<string | null> {
  if (purpose === 'idle' || !file.type.startsWith('image/')) {
    return null;
  }
  try {
    const { width, height } = await loadImageSize(file);
    const actual = aspectRatio(width, height);
    if (purpose === 'banner_horizontal') {
      const target = aspectRatio(HORIZONTAL_TARGET.width, HORIZONTAL_TARGET.height);
      if (actual < target * 0.55 || actual > target * 1.8) {
        return `Image is ${width}×${height}. Recommended horizontal banner is ${HORIZONTAL_TARGET.label}. You can still upload.`;
      }
    } else {
      const target = aspectRatio(VERTICAL_TARGET.width, VERTICAL_TARGET.height);
      if (actual < target * 0.55 || actual > target * 1.8) {
        return `Image is ${width}×${height}. Recommended vertical banner is ${VERTICAL_TARGET.label}. You can still upload.`;
      }
    }
  } catch {
    return null;
  }
  return null;
}

export function CreativeUploadModal({
  open,
  advertiserId,
  onClose,
  onUploaded,
}: {
  open: boolean;
  advertiserId: string;
  onClose: () => void;
  onUploaded: (creative: Creative) => void;
}) {
  const { token } = useAuth();
  const [title, setTitle] = useState('');
  const [purpose, setPurpose] = useState<UploadPurpose>('idle');
  const [files, setFiles] = useState<File[]>([]);
  const [fileInputKey, setFileInputKey] = useState(0);
  const [busy, setBusy] = useState(false);
  const [progressPercent, setProgressPercent] = useState<number | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [aspectWarn, setAspectWarn] = useState<string | null>(null);

  function reset() {
    setTitle('');
    setPurpose('idle');
    setFiles([]);
    setFileInputKey((k) => k + 1);
    setError(null);
    setAspectWarn(null);
    setProgressPercent(null);
  }

  function handleClose() {
    if (busy) {
      return;
    }
    reset();
    onClose();
  }

  async function onFilesSelected(next: File[]) {
    setAspectWarn(null);
    const oversized = findOversizedFile(next);
    if (oversized) {
      setFiles([]);
      setFileInputKey((k) => k + 1);
      setError(oversizedMessage(oversized));
      return;
    }
    setError(null);
    setFiles(next);
    if (next[0] && purpose !== 'idle') {
      const warn = await softAspectWarning(purpose, next[0]);
      setAspectWarn(warn);
    }
  }

  async function onSubmit(event: FormEvent) {
    event.preventDefault();
    if (!advertiserId || !title.trim() || files.length === 0) {
      setError('Title and at least one file are required');
      return;
    }
    const oversized = findOversizedFile(files);
    if (oversized) {
      setError(oversizedMessage(oversized));
      return;
    }
    setBusy(true);
    setError(null);
    setProgressPercent(0);
    const form = new FormData();
    form.append('advertiserId', advertiserId);
    form.append('title', title.trim());
    form.append('purpose', purpose === 'banner_horizontal' ? 'banner' : purpose);
    for (const file of files) {
      form.append('files', file);
    }
    try {
      const created = await apiUploadFormData<Creative>('/ads/creatives', {
        token,
        formData: form,
        onProgress: (progress) => {
          setProgressPercent(progress.percent);
        },
      });
      reset();
      onUploaded(created);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Upload failed');
      setProgressPercent(null);
    } finally {
      setBusy(false);
    }
  }

  const isBanner = purpose === 'banner_horizontal' || purpose === 'banner_vertical';
  const progressLabel =
    progressPercent == null ? 'Uploading…' : `Uploading… ${progressPercent}%`;

  return (
    <Modal
      open={open}
      title="Upload media"
      onClose={handleClose}
      footer={
        <>
          <Button type="button" variant="ghost" disabled={busy} onClick={handleClose}>
            Cancel
          </Button>
          <Button type="submit" form="creative-upload-form" disabled={busy || !advertiserId}>
            {busy ? progressLabel : 'Upload'}
          </Button>
        </>
      }
    >
      <form id="creative-upload-form" className="stack" onSubmit={(e) => void onSubmit(e)}>
        <fieldset className="stack border-0 p-0 m-0">
          <legend className="muted">Purpose</legend>
          <label>
            <input
              type="radio"
              name="purpose"
              checked={purpose === 'idle'}
              onChange={() => {
                setPurpose('idle');
                setFiles([]);
                setAspectWarn(null);
                setError(null);
              }}
            />{' '}
            Idle media (video or photos)
          </label>
          <label>
            <input
              type="radio"
              name="purpose"
              checked={purpose === 'banner_horizontal'}
              onChange={() => {
                setPurpose('banner_horizontal');
                setFiles([]);
                setAspectWarn(null);
                setError(null);
              }}
            />{' '}
            Horizontal banner (top / bottom)
          </label>
          <label>
            <input
              type="radio"
              name="purpose"
              checked={purpose === 'banner_vertical'}
              onChange={() => {
                setPurpose('banner_vertical');
                setFiles([]);
                setAspectWarn(null);
                setError(null);
              }}
            />{' '}
            Vertical banner (left / right)
          </label>
        </fieldset>
        <label>
          Title
          <Input value={title} onChange={(e) => setTitle(e.target.value)} required />
        </label>
        <label>
          {isBanner ? 'Image' : 'Files'}
          <Input
            key={fileInputKey}
            type="file"
            accept={
              purpose === 'idle'
                ? 'video/mp4,video/webm,video/quicktime,video/x-matroska,video/x-msvideo,video/*,image/*'
                : 'image/*'
            }
            multiple={purpose === 'idle'}
            onChange={(e) => void onFilesSelected(Array.from(e.target.files ?? []))}
            required
          />
        </label>
        <p className="muted">
          {purpose === 'idle'
            ? 'One video, or one or more photos (1 photo = image, 2+ = carousel).'
            : purpose === 'banner_horizontal'
              ? `Single image for top and bottom strips. Recommended ${HORIZONTAL_TARGET.label}.`
              : `Single image for left and right strips. Recommended ${VERTICAL_TARGET.label}.`}
        </p>
        <p className="muted">
          Videos must be {ADS_MAX_UPLOAD_MB} MB or smaller. Larger files are rejected. Compress or
          re-encode if needed.
        </p>
        {files.length > 0 ? <p className="muted">{files.length} file(s) selected</p> : null}
        {busy ? (
          <div className="stack gap-2" aria-live="polite">
            <p className="muted">{progressLabel}</p>
            <div
              className="h-2 w-full overflow-hidden rounded-full bg-muted"
              role="progressbar"
              aria-valuemin={0}
              aria-valuemax={100}
              aria-valuenow={progressPercent ?? undefined}
            >
              <div
                className="h-full rounded-full bg-primary transition-[width] duration-150"
                style={{
                  width:
                    progressPercent == null
                      ? '40%'
                      : `${Math.max(2, Math.min(100, progressPercent))}%`,
                  opacity: progressPercent == null ? 0.55 : 1,
                }}
              />
            </div>
          </div>
        ) : null}
        {aspectWarn ? <p className="muted">{aspectWarn}</p> : null}
        {error ? <p className="error">{error}</p> : null}
      </form>
    </Modal>
  );
}
