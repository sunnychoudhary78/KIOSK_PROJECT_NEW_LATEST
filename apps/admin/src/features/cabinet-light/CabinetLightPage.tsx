import { useCallback, useEffect, useState, type FormEvent } from 'react';
import { apiRequest } from '../../core/api/client';
import { useAuth } from '../../core/auth/auth-context';
import { Button, Input, PageHeader, Panel } from '../../core/ui/primitives';

type CabinetLightConfig = {
  enabled: boolean;
  mode: 'schedule' | 'on' | 'off';
  onTime: string;
  offTime: string;
};

const DEFAULTS: CabinetLightConfig = {
  enabled: false,
  mode: 'schedule',
  onTime: '18:00',
  offTime: '06:00',
};

export function CabinetLightPage() {
  const { token } = useAuth();
  const [form, setForm] = useState<CabinetLightConfig>(DEFAULTS);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  const load = useCallback(async () => {
    if (!token) return;
    try {
      const config = await apiRequest<CabinetLightConfig>('/cabinet-light', { token });
      setForm({ ...DEFAULTS, ...config });
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load cabinet light');
    }
  }, [token]);

  useEffect(() => {
    void load();
  }, [load]);

  async function save(next: CabinetLightConfig, message: string) {
    setSaving(true);
    setNotice(null);
    setError(null);
    try {
      await apiRequest('/platform-settings/cabinet_light_config', {
        method: 'PUT',
        token,
        body: { settingValue: next, description: 'Cabinet light on relay 2' },
      });
      setForm(next);
      setNotice(message);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not save cabinet light');
    } finally {
      setSaving(false);
    }
  }

  function onSchedule(event: FormEvent) {
    event.preventDefault();
    void save(
      { ...form, enabled: true, mode: 'schedule' },
      'Schedule saved. The kiosk will switch the light at these times.',
    );
  }

  const modeLabel =
    form.mode === 'on'
      ? 'Forced on'
      : form.mode === 'off'
        ? 'Forced off'
        : form.enabled
          ? `Following schedule ${form.onTime} – ${form.offTime}`
          : 'Schedule is off';

  return (
    <div>
      <PageHeader
        title="Cabinet light"
        subtitle="Relay 2 on the kiosk controller. The kiosk applies this over the serial port."
      />
      {error ? <p className="mb-4 text-sm text-red-600">{error}</p> : null}
      {notice ? <p className="mb-4 text-sm text-emerald-700">{notice}</p> : null}
      <div className="grid gap-6 lg:grid-cols-2">
        <Panel title="Daily on and off">
          <form className="space-y-4" onSubmit={onSchedule}>
            <label className="block text-sm">
              <span className="mb-1 block text-muted-foreground">Turn on at</span>
              <Input
                type="time"
                required
                value={form.onTime}
                onChange={(event) => setForm({ ...form, onTime: event.target.value })}
              />
            </label>
            <label className="block text-sm">
              <span className="mb-1 block text-muted-foreground">Turn off at</span>
              <Input
                type="time"
                required
                value={form.offTime}
                onChange={(event) => setForm({ ...form, offTime: event.target.value })}
              />
            </label>
            <p className="text-sm text-muted-foreground">
              If the off time is earlier than the on time, the light stays on through midnight.
            </p>
            <Button type="submit" disabled={saving}>
              Save schedule
            </Button>
          </form>
        </Panel>
        <Panel title="Instant switch">
          <p className="mb-4 text-sm">Now: {modeLabel}</p>
          <div className="flex flex-wrap gap-3">
            <Button
              type="button"
              disabled={saving}
              onClick={() =>
                void save(
                  { ...form, enabled: true, mode: 'on' },
                  'Light turned on. The kiosk will switch it within a few seconds.',
                )
              }
            >
              Turn on now
            </Button>
            <Button
              type="button"
              disabled={saving}
              onClick={() =>
                void save(
                  { ...form, enabled: true, mode: 'off' },
                  'Light turned off. The kiosk will switch it within a few seconds.',
                )
              }
            >
              Turn off now
            </Button>
            <Button
              type="button"
              disabled={saving || !form.enabled}
              onClick={() =>
                void save(
                  { ...form, enabled: true, mode: 'schedule' },
                  'Back on the daily schedule.',
                )
              }
            >
              Follow schedule
            </Button>
          </div>
        </Panel>
      </div>
    </div>
  );
}
