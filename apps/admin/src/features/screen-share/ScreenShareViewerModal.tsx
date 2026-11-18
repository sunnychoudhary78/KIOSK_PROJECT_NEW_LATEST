import { useEffect, useRef, useState } from 'react';
import {
  Room,
  RoomEvent,
  Track,
  type RemoteTrack,
  type RemoteTrackPublication,
  type RemoteParticipant,
} from 'livekit-client';
import { apiRequest } from '../../core/api/client';
import { Button, Modal } from '../../core/ui/primitives';

type ScreenShareSession = {
  id: string;
  deviceId: string;
  roomName: string;
  status: 'pending' | 'active' | 'ended' | 'expired' | 'failed';
  requestedAt: string;
  startedAt: string | null;
  endedAt: string | null;
  expiresAt: string;
  lastError: string | null;
};

type StartResponse = {
  session: ScreenShareSession;
  livekitUrl: string;
  token: string;
};

type Props = {
  open: boolean;
  deviceId: string;
  deviceName: string;
  token: string | null;
  onClose: () => void;
};

function statusLabel(status: ScreenShareSession['status'] | null, hasVideo: boolean): string {
  if (!status) return 'Starting…';
  if (status === 'pending') return 'Waiting for kiosk to join (poll ~10s)…';
  if (status === 'active' && !hasVideo) return 'Kiosk connected — waiting for screen…';
  if (status === 'active') return 'Live';
  if (status === 'ended') return 'Ended';
  if (status === 'expired') return 'Expired';
  if (status === 'failed') return 'Failed';
  return status;
}

export function ScreenShareViewerModal({
  open,
  deviceId,
  deviceName,
  token,
  onClose,
}: Props) {
  const videoRef = useRef<HTMLVideoElement | null>(null);
  const roomRef = useRef<Room | null>(null);
  const [session, setSession] = useState<ScreenShareSession | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [hasVideo, setHasVideo] = useState(false);
  const [ending, setEnding] = useState(false);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (!open || !token) return;

    let cancelled = false;
    const room = new Room({ adaptiveStream: true, dynacast: true });
    roomRef.current = room;

    const attachTrack = (track: RemoteTrack) => {
      if (track.kind !== Track.Kind.Video) return;
      const el = videoRef.current;
      if (!el) return;
      track.attach(el);
      setHasVideo(true);
    };

    const onTrackSubscribed = (
      track: RemoteTrack,
      _publication: RemoteTrackPublication,
      _participant: RemoteParticipant,
    ) => {
      attachTrack(track);
    };

    const onTrackUnsubscribed = (track: RemoteTrack) => {
      track.detach();
      setHasVideo(false);
    };

    room.on(RoomEvent.TrackSubscribed, onTrackSubscribed);
    room.on(RoomEvent.TrackUnsubscribed, onTrackUnsubscribed);

    async function start() {
      setBusy(true);
      setError(null);
      setHasVideo(false);
      setSession(null);
      try {
        const started = await apiRequest<StartResponse>(
          `/devices/${deviceId}/screen-share/start`,
          { method: 'POST', token },
        );
        if (cancelled) return;
        setSession(started.session);
        await room.connect(started.livekitUrl, started.token);
        if (cancelled) return;
        for (const participant of room.remoteParticipants.values()) {
          for (const publication of participant.trackPublications.values()) {
            if (publication.track) {
              attachTrack(publication.track as RemoteTrack);
            }
          }
        }
      } catch (err) {
        if (!cancelled) {
          setError(err instanceof Error ? err.message : 'Could not start screen share');
        }
      } finally {
        if (!cancelled) setBusy(false);
      }
    }

    void start();

    return () => {
      cancelled = true;
      room.off(RoomEvent.TrackSubscribed, onTrackSubscribed);
      room.off(RoomEvent.TrackUnsubscribed, onTrackUnsubscribed);
      void room.disconnect();
      roomRef.current = null;
    };
  }, [open, deviceId, token]);

  useEffect(() => {
    if (!open || !token || !session) return;
    if (session.status === 'ended' || session.status === 'expired' || session.status === 'failed') {
      return;
    }

    const timer = window.setInterval(() => {
      void (async () => {
        try {
          const result = await apiRequest<{ session: ScreenShareSession | null }>(
            `/devices/${deviceId}/screen-share`,
            { token },
          );
          if (result.session) {
            setSession(result.session);
          }
        } catch {
          // Keep showing last known status; transient poll failures are fine.
        }
      })();
    }, 4000);

    return () => window.clearInterval(timer);
  }, [open, token, deviceId, session?.id, session?.status]);

  async function endSession() {
    setEnding(true);
    setError(null);
    try {
      await apiRequest(`/devices/${deviceId}/screen-share/end`, {
        method: 'POST',
        token,
      });
      await roomRef.current?.disconnect();
      onClose();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not end screen share');
    } finally {
      setEnding(false);
    }
  }

  function handleClose() {
    void roomRef.current?.disconnect();
    // Best-effort end so the kiosk is not left publishing.
    if (session && (session.status === 'pending' || session.status === 'active')) {
      void apiRequest(`/devices/${deviceId}/screen-share/end`, {
        method: 'POST',
        token,
      }).catch(() => undefined);
    }
    onClose();
  }

  return (
    <Modal
      open={open}
      title={`Screen — ${deviceName}`}
      description="View-only live desktop. May show visitor documents or personal data. Session ends automatically after the TTL."
      onClose={handleClose}
      className="sm:max-w-4xl"
      footer={
        <>
          <Button type="button" variant="secondary" onClick={handleClose}>
            Close
          </Button>
          <Button
            type="button"
            onClick={() => void endSession()}
            disabled={ending || busy || !session}
          >
            {ending ? 'Ending…' : 'End session'}
          </Button>
        </>
      }
    >
      <div className="space-y-3">
        <p className="text-sm text-muted-foreground">
          {statusLabel(session?.status ?? null, hasVideo)}
          {session?.expiresAt
            ? ` · expires ${new Date(session.expiresAt).toLocaleTimeString()}`
            : null}
        </p>
        {error ? <p className="text-sm text-red-700">{error}</p> : null}
        {session?.lastError ? (
          <p className="text-sm text-amber-700">Kiosk error: {session.lastError}</p>
        ) : null}
        <div className="overflow-hidden rounded-md border bg-black">
          <video
            ref={videoRef}
            className="aspect-video w-full object-contain"
            autoPlay
            playsInline
            muted
          />
        </div>
      </div>
    </Modal>
  );
}
