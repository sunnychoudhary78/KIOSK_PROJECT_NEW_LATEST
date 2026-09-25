import { useCallback, useEffect, useState, type FormEvent } from 'react';
import { apiRequest } from '../../core/api/client';
import { useAuth } from '../../core/auth/auth-context';
import { Button, Input, PageHeader, Panel, StatusBadge } from '../../core/ui/primitives';

type PlatformSetting = {
  id: string;
  settingKey: string;
  settingValue: Record<string, unknown>;
  description?: string | null;
  isActive: boolean;
  updatedAt: string;
};

type OtpPrintForm = {
  ttlSeconds: number;
  otpLength: number;
  maxDocumentsPerSession: number;
  maxVerifyAttempts: number;
  maxFileSizeMb: number;
};

type CitizenAuthForm = {
  ttlSeconds: number;
  otpLength: number;
  maxVerifyAttempts: number;
  requestCooldownSeconds: number;
};

type SmsStatus = {
  provider: string;
  configured: boolean;
  senderId: string | null;
  flowIdConfigured: boolean;
};

const DEFAULT_OTP_PRINT: OtpPrintForm = {
  ttlSeconds: 1800,
  otpLength: 6,
  maxDocumentsPerSession: 5,
  maxVerifyAttempts: 5,
  maxFileSizeMb: 15,
};

const DEFAULT_CITIZEN_AUTH: CitizenAuthForm = {
  ttlSeconds: 300,
  otpLength: 6,
  maxVerifyAttempts: 5,
  requestCooldownSeconds: 60,
};

const MIN_PRINT_TTL_SECONDS = 60;
const MAX_PRINT_TTL_SECONDS = 86_400;
const MIN_LOGIN_TTL_SECONDS = 60;
const MAX_LOGIN_TTL_SECONDS = 3600;

const SMS_TEMPLATE_PREVIEW =
  'Your OTP for IMMORTAL is #### Valid for {expiry}. Do not share this code.';

function formatOtpExpiryLabel(ttlSeconds: number): string {
  const seconds = Math.max(0, Math.floor(Number(ttlSeconds) || 0));
  const totalMinutes = Math.max(1, Math.round(seconds / 60));
  const hours = Math.floor(totalMinutes / 60);
  const minutes = totalMinutes % 60;

  if (hours > 0 && minutes === 0) {
    return hours === 1 ? '1 hour' : `${hours} hours`;
  }
  if (hours > 0) {
    const hourPart = hours === 1 ? '1 hour' : `${hours} hours`;
    const minutePart = minutes === 1 ? '1 minute' : `${minutes} minutes`;
    return `${hourPart} ${minutePart}`;
  }
  return totalMinutes === 1 ? '1 minute' : `${totalMinutes} minutes`;
}

function ttlToParts(ttlSeconds: number): { hours: number; minutes: number } {
  const clamped = Math.min(
    MAX_PRINT_TTL_SECONDS,
    Math.max(MIN_PRINT_TTL_SECONDS, Math.floor(Number(ttlSeconds) || MIN_PRINT_TTL_SECONDS)),
  );
  const totalMinutes = Math.floor(clamped / 60);
  return {
    hours: Math.floor(totalMinutes / 60),
    minutes: totalMinutes % 60,
  };
}

function partsToTtlSeconds(hours: number, minutes: number): number {
  const h = Math.min(24, Math.max(0, Math.floor(Number(hours) || 0)));
  const m = Math.min(59, Math.max(0, Math.floor(Number(minutes) || 0)));
  let total = h * 3600 + m * 60;
  if (total < MIN_PRINT_TTL_SECONDS) total = MIN_PRINT_TTL_SECONDS;
  if (total > MAX_PRINT_TTL_SECONDS) total = MAX_PRINT_TTL_SECONDS;
  return total;
}

function clampLoginTtlSeconds(value: number): number {
  const n = Math.floor(Number(value) || 0);
  if (n < MIN_LOGIN_TTL_SECONDS) return MIN_LOGIN_TTL_SECONDS;
  if (n > MAX_LOGIN_TTL_SECONDS) return MAX_LOGIN_TTL_SECONDS;
  return n;
}

export function PlatformSettingsPage() {
  const { token } = useAuth();
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [otpPrint, setOtpPrint] = useState<OtpPrintForm>(DEFAULT_OTP_PRINT);
  const [citizenAuth, setCitizenAuth] = useState<CitizenAuthForm>(DEFAULT_CITIZEN_AUTH);
  const [smsStatus, setSmsStatus] = useState<SmsStatus | null>(null);

  const printDuration = ttlToParts(otpPrint.ttlSeconds);
  const printExpiryLabel = formatOtpExpiryLabel(otpPrint.ttlSeconds);

  const load = useCallback(async () => {
    try {
      const result = await apiRequest<{
        items: PlatformSetting[];
        smsStatus?: SmsStatus;
      }>('/platform-settings', { token });

      setSmsStatus(
        result.smsStatus ?? {
          provider: 'noop',
          configured: false,
          senderId: null,
          flowIdConfigured: false,
        },
      );

      for (const item of result.items) {
        if (item.settingKey === 'otp_print_config') {
          setOtpPrint({ ...DEFAULT_OTP_PRINT, ...(item.settingValue as OtpPrintForm) });
        }
        if (item.settingKey === 'citizen_auth_config') {
          const loaded = { ...DEFAULT_CITIZEN_AUTH, ...(item.settingValue as CitizenAuthForm) };
          setCitizenAuth({
            ...loaded,
            ttlSeconds: clampLoginTtlSeconds(loaded.ttlSeconds),
          });
        }
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load settings');
    }
  }, [token]);

  useEffect(() => {
    void load();
  }, [load]);

  async function putSetting(settingKey: string, settingValue: unknown): Promise<void> {
    await apiRequest(`/platform-settings/${settingKey}`, {
      method: 'PUT',
      token,
      body: { settingValue },
    });
  }

  function setPrintDuration(hours: number, minutes: number) {
    setOtpPrint((s) => ({ ...s, ttlSeconds: partsToTtlSeconds(hours, minutes) }));
  }

  async function onSave(event: FormEvent) {
    event.preventDefault();
    setSaving(true);
    setError(null);
    setSuccess(null);

    const printTtlSeconds = partsToTtlSeconds(printDuration.hours, printDuration.minutes);
    const loginTtlRaw = Number(citizenAuth.ttlSeconds);
    const loginTtlValid =
      Number.isFinite(loginTtlRaw) &&
      loginTtlRaw >= MIN_LOGIN_TTL_SECONDS &&
      loginTtlRaw <= MAX_LOGIN_TTL_SECONDS;

    const errors: string[] = [];
    let printSaved = false;
    let loginSaved = false;

    try {
      await putSetting('otp_print_config', {
        ttlSeconds: printTtlSeconds,
        otpLength: Number(otpPrint.otpLength),
        maxDocumentsPerSession: Number(otpPrint.maxDocumentsPerSession),
        maxVerifyAttempts: Number(otpPrint.maxVerifyAttempts),
        maxFileSizeMb: Number(otpPrint.maxFileSizeMb),
      });
      printSaved = true;
    } catch (err) {
      errors.push(
        `Print OTP: ${err instanceof Error ? err.message : 'Failed to save'}`,
      );
    }

    if (!loginTtlValid) {
      errors.push(
        `Login OTP: TTL must be ${MIN_LOGIN_TTL_SECONDS}–${MAX_LOGIN_TTL_SECONDS} seconds (max 1 hour).`,
      );
    } else {
      try {
        await putSetting('citizen_auth_config', {
          ...citizenAuth,
          ttlSeconds: loginTtlRaw,
          otpLength: Number(citizenAuth.otpLength),
          maxVerifyAttempts: Number(citizenAuth.maxVerifyAttempts),
          requestCooldownSeconds: Number(citizenAuth.requestCooldownSeconds),
        });
        loginSaved = true;
      } catch (err) {
        errors.push(
          `Login OTP: ${err instanceof Error ? err.message : 'Failed to save'}`,
        );
      }
    }

    await load();

    if (errors.length === 0) {
      setSuccess('Settings saved');
    } else if (printSaved || loginSaved) {
      setSuccess(
        [printSaved ? 'Print settings saved' : null, loginSaved ? 'Login settings saved' : null]
          .filter(Boolean)
          .join('; '),
      );
      setError(errors.join(' '));
    } else {
      setError(errors.join(' '));
    }

    setSaving(false);
  }

  return (
    <div className="settings-page">
      <PageHeader
        title="Platform settings"
        subtitle="Print OTP expiry drives SMS ##var2##. MSG91 credentials come from the API environment."
      />

      {error ? <p className="error">{error}</p> : null}
      {success ? <p className="success">{success}</p> : null}

      <form className="settings-stack" onSubmit={onSave}>
        <Panel
          title="SMS & Print OTP expiry"
          actions={
            smsStatus ? (
              <StatusBadge status={smsStatus.configured ? 'ready' : 'not_configured'} />
            ) : null
          }
        >
          <div className="settings-status muted">
            {smsStatus?.configured ? (
              <>
                MSG91 ready via env
                {smsStatus.senderId ? ` · sender ${smsStatus.senderId}` : ''}
                {smsStatus.flowIdConfigured ? ' · flow ID set' : ''}
              </>
            ) : (
              <>
                MSG91 not configured. Set{' '}
                <code>SKP_SMS_PROVIDER=msg91</code>, <code>SKP_MSG91_AUTH_KEY</code>,{' '}
                <code>SKP_MSG91_SENDER_ID</code>, and <code>SKP_MSG91_FLOW_ID</code> on the API, then
                restart.
              </>
            )}
          </div>

          <div className="settings-row">
            <label>
              Expiry hours
              <Input
                type="number"
                min={0}
                max={24}
                value={printDuration.hours}
                onChange={(e) => setPrintDuration(Number(e.target.value), printDuration.minutes)}
              />
            </label>
            <label>
              Expiry minutes
              <Input
                type="number"
                min={0}
                max={59}
                value={printDuration.minutes}
                onChange={(e) => setPrintDuration(printDuration.hours, Number(e.target.value))}
              />
            </label>
          </div>

          <div className="settings-preview">
            <div>
              <code>##var1##</code> = OTP code (hardcoded)
            </div>
            <div>
              <code>##var2##</code> = <strong>{printExpiryLabel}</strong>
            </div>
            <div className="settings-preview-message">
              {SMS_TEMPLATE_PREVIEW.replace('{expiry}', printExpiryLabel)}
            </div>
            <p className="muted" style={{ margin: '0.5rem 0 0' }}>
              Range: 1 minute – 24 hours. Changing hours/minutes updates ##var2## immediately.
            </p>
          </div>
        </Panel>

        <Panel title="Print OTP rules">
          <div className="settings-row">
            <label>
              OTP length
              <Input
                type="number"
                min={4}
                max={8}
                value={otpPrint.otpLength}
                onChange={(e) =>
                  setOtpPrint((s) => ({ ...s, otpLength: Number(e.target.value) }))
                }
              />
            </label>
            <label>
              Max documents / session
              <Input
                type="number"
                value={otpPrint.maxDocumentsPerSession}
                onChange={(e) =>
                  setOtpPrint((s) => ({
                    ...s,
                    maxDocumentsPerSession: Number(e.target.value),
                  }))
                }
              />
            </label>
            <label>
              Max verify attempts
              <Input
                type="number"
                value={otpPrint.maxVerifyAttempts}
                onChange={(e) =>
                  setOtpPrint((s) => ({ ...s, maxVerifyAttempts: Number(e.target.value) }))
                }
              />
            </label>
            <label>
              Max file size (MB)
              <Input
                type="number"
                value={otpPrint.maxFileSizeMb}
                onChange={(e) =>
                  setOtpPrint((s) => ({ ...s, maxFileSizeMb: Number(e.target.value) }))
                }
              />
            </label>
          </div>
          <p className="muted" style={{ margin: '0.75rem 0 0' }}>
            Page caps and extra-page charges are set per kiosk on the Kiosks tab.
          </p>
        </Panel>

        <Panel title="Citizen login OTP">
          <div className="settings-row">
            <label>
              TTL (seconds, max 3600)
              <Input
                type="number"
                min={MIN_LOGIN_TTL_SECONDS}
                max={MAX_LOGIN_TTL_SECONDS}
                value={citizenAuth.ttlSeconds}
                onChange={(e) =>
                  setCitizenAuth((s) => ({ ...s, ttlSeconds: Number(e.target.value) }))
                }
              />
              <span className="muted" style={{ fontSize: 12 }}>
                SMS ##var2## for login: {formatOtpExpiryLabel(citizenAuth.ttlSeconds)}
              </span>
            </label>
            <label>
              OTP length
              <Input
                type="number"
                min={4}
                max={8}
                value={citizenAuth.otpLength}
                onChange={(e) =>
                  setCitizenAuth((s) => ({ ...s, otpLength: Number(e.target.value) }))
                }
              />
            </label>
            <label>
              Max verify attempts
              <Input
                type="number"
                value={citizenAuth.maxVerifyAttempts}
                onChange={(e) =>
                  setCitizenAuth((s) => ({
                    ...s,
                    maxVerifyAttempts: Number(e.target.value),
                  }))
                }
              />
            </label>
            <label>
              Request cooldown (seconds)
              <Input
                type="number"
                value={citizenAuth.requestCooldownSeconds}
                onChange={(e) =>
                  setCitizenAuth((s) => ({
                    ...s,
                    requestCooldownSeconds: Number(e.target.value),
                  }))
                }
              />
            </label>
          </div>
        </Panel>

        <div className="settings-actions">
          <Button type="submit" disabled={saving}>
            {saving ? 'Saving…' : 'Save settings'}
          </Button>
        </div>
      </form>
    </div>
  );
}
