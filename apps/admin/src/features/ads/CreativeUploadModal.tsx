import { useState, type FormEvent } from 'react';
import { apiRequest } from '../../core/api/client';
import { useAuth } from '../../core/auth/auth-context';
import { Button, Input, Modal } from '../../core/ui/primitives';
import type { Creative } from './types';

export type UploadPurpose = 'idle' | 'banner';

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
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  function reset() {
    setTitle('');
    setPurpose('idle');
    setFiles([]);
    setError(null);
  }

  function handleClose() {
    if (busy) {
      return;
    }
    reset();
    onClose();
  }

  async function onSubmit(event: FormEvent) {
    event.preventDefault();
    if (!advertiserId || !title.trim() || files.length === 0) {
      setError('Title and at least one file are required');
      return;
    }
    setBusy(true);
    setError(null);
    const form = new FormData();
    form.append('advertiserId', advertiserId);
    form.append('title', title.trim());
    form.append('purpose', purpose);
    for (const file of files) {
      form.append('files', file);
    }
    try {
      const created = await apiRequest<Creative>('/ads/creatives', {
        method: 'POST',
        token,
        formData: form,
      });
      reset();
      onUploaded(created);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Upload failed');
    } finally {
      setBusy(false);
    }
  }

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
            {busy ? 'Uploading…' : 'Upload'}
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
              }}
            />{' '}
            Idle media (video or photos)
          </label>
          <label>
            <input
              type="radio"
              name="purpose"
              checked={purpose === 'banner'}
              onChange={() => {
                setPurpose('banner');
                setFiles([]);
              }}
            />{' '}
            Home banner (single image)
          </label>
        </fieldset>
        <label>
          Title
          <Input value={title} onChange={(e) => setTitle(e.target.value)} required />
        </label>
        <label>
          {purpose === 'idle' ? 'Files' : 'Image'}
          <Input
            type="file"
            accept={
              purpose === 'idle'
                ? 'video/mp4,video/webm,video/quicktime,video/x-matroska,video/x-msvideo,video/*,image/*'
                : 'image/*'
            }
            multiple={purpose === 'idle'}
            onChange={(e) => setFiles(Array.from(e.target.files ?? []))}
            required
          />
        </label>
        <p className="muted">
          {purpose === 'idle'
            ? 'One video, or one or more photos (1 photo = image, 2+ = carousel).'
            : 'Upload a single image for the home screen banner.'}
        </p>
        {files.length > 0 ? <p className="muted">{files.length} file(s) selected</p> : null}
        {error ? <p className="error">{error}</p> : null}
      </form>
    </Modal>
  );
}
