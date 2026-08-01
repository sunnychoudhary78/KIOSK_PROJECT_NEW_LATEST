import { useCallback, useEffect, useState, type FormEvent } from 'react';
import { apiRequest } from '../../core/api/client';
import { useAuth } from '../../core/auth/auth-context';
import { Button, Input, PageHeader, Panel } from '../../core/ui/primitives';

type PlatformSetting = {
  id: string;
  settingKey: string;
  settingValue: Record<string, unknown>;
  description?: string | null;
  isActive: boolean;
  updatedAt: string;
};

type SmsForm = {
  provider: 'msg91';
  enabled: boolean;
  auth_key: string;
  sender_id: string;
  flow_id: string;
  otp_var_name: string;
  message_template: string;
};

type OtpPrintForm = {
  ttlSeconds: number;
  otpLength: number;
  maxPagesPerSession: number;
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

const DEFAULT_SMS: SmsForm = {
  provider: 'msg91',
  enabled: false,
  auth_key: '',
  sender_id: '',
  flow_id: '',
  otp_var_name: 'OTP',
  message_template:
    'Your OTP for Smart Kiosk is --. Valid for 30 minutes. Do not share this code.',
};

const DEFAULT_OTP_PRINT: OtpPrintForm = {
  ttlSeconds: 1800,
  otpLength: 6,
  maxPagesPerSession: 10,
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

type Tab = 'sms' | 'otp';

export function PlatformSettingsPage() {
  const { token } = useAuth();
  const [tab, setTab] = useState<Tab>('sms');
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [sms, setSms] = useState<SmsForm>(DEFAULT_SMS);
  const [otpPrint, setOtpPrint] = useState<OtpPrintForm>(DEFAULT_OTP_PRINT);
  const [citizenAuth, setCitizenAuth] = useState<CitizenAuthForm>(DEFAULT_CITIZEN_AUTH);

  const load = useCallback(async () => {
    setError(null);
    try {
      const result = await apiRequest<{ items: PlatformSetting[] }>('/platform-settings', {
        token,
      });
      for (const item of result.items) {
        if (item.settingKey === 'sms_config') {
          const v = item.settingValue;
          setSms({
            provider: 'msg91',
            enabled: v.enabled !== false,
            auth_key: String(v.auth_key ?? ''),
            sender_id: String(v.sender_id ?? ''),
            flow_id: String(v.flow_id ?? ''),
            otp_var_name: String(v.otp_var_name ?? 'OTP'),
            message_template: String(v.message_template ?? DEFAULT_SMS.message_template),
          });
        }
        if (item.settingKey === 'otp_print_config') {
          setOtpPrint({ ...DEFAULT_OTP_PRINT, ...(item.settingValue as OtpPrintForm) });
        }
        if (item.settingKey === 'citizen_auth_config') {
          setCitizenAuth({ ...DEFAULT_CITIZEN_AUTH, ...(item.settingValue as CitizenAuthForm) });
        }
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load settings');
    }
  }, [token]);

  useEffect(() => {
    void load();
  }, [load]);

  async function saveSetting(settingKey: string, settingValue: unknown) {
    setSaving(true);
    setError(null);
    setSuccess(null);
    try {
      await apiRequest(`/platform-settings/${settingKey}`, {
        method: 'PUT',
        token,
        body: { settingValue },
      });
      setSuccess('Settings saved');
      await load();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to save');
    } finally {
      setSaving(false);
    }
  }

  async function onSaveSms(event: FormEvent) {
    event.preventDefault();
    if (!sms.message_template.includes('--')) {
      setError('Message template must include -- as the OTP placeholder');
      return;
    }
    await saveSetting('sms_config', sms);
  }

  async function onSaveOtp(event: FormEvent) {
    event.preventDefault();
    await saveSetting('otp_print_config', {
      ...otpPrint,
      ttlSeconds: Number(otpPrint.ttlSeconds),
      otpLength: Number(otpPrint.otpLength),
      maxPagesPerSession: Number(otpPrint.maxPagesPerSession),
      maxDocumentsPerSession: Number(otpPrint.maxDocumentsPerSession),
      maxVerifyAttempts: Number(otpPrint.maxVerifyAttempts),
      maxFileSizeMb: Number(otpPrint.maxFileSizeMb),
    });
    await saveSetting('citizen_auth_config', {
      ...citizenAuth,
      ttlSeconds: Number(citizenAuth.ttlSeconds),
      otpLength: Number(citizenAuth.otpLength),
      maxVerifyAttempts: Number(citizenAuth.maxVerifyAttempts),
      requestCooldownSeconds: Number(citizenAuth.requestCooldownSeconds),
    });
  }

  return (
    <div>
      <PageHeader
        title="Platform settings"
        subtitle="SMS provider and OTP print / login configuration"
      />
      <div className="toolbar" style={{ marginBottom: 16 }}>
        <Button
          type="button"
          variant={tab === 'sms' ? 'primary' : 'secondary'}
          onClick={() => setTab('sms')}
        >
          SMS Config
        </Button>
        <Button
          type="button"
          variant={tab === 'otp' ? 'primary' : 'secondary'}
          onClick={() => setTab('otp')}
        >
          OTP / Print
        </Button>
      </div>
      {error ? <p className="error">{error}</p> : null}
      {success ? <p className="success">{success}</p> : null}

      {tab === 'sms' ? (
        <Panel title="MSG91 Flow SMS">
          <form className="form-grid" onSubmit={onSaveSms}>
            <label>
              <span>Enabled</span>
              <input
                type="checkbox"
                checked={sms.enabled}
                onChange={(e) => setSms((s) => ({ ...s, enabled: e.target.checked }))}
              />
            </label>
            <label>
              Auth key
              <Input
                value={sms.auth_key}
                onChange={(e) => setSms((s) => ({ ...s, auth_key: e.target.value }))}
                maxLength={200}
                placeholder="MSG91 auth key"
              />
            </label>
            <label>
              Sender ID
              <Input
                value={sms.sender_id}
                onChange={(e) => setSms((s) => ({ ...s, sender_id: e.target.value }))}
                maxLength={30}
              />
            </label>
            <label>
              Flow ID
              <Input
                value={sms.flow_id}
                onChange={(e) => setSms((s) => ({ ...s, flow_id: e.target.value }))}
                maxLength={50}
              />
            </label>
            <label>
              OTP variable name
              <Input
                value={sms.otp_var_name}
                onChange={(e) => setSms((s) => ({ ...s, otp_var_name: e.target.value }))}
                maxLength={40}
              />
            </label>
            <label>
              Message template (must include --)
              <textarea
                className="input"
                rows={3}
                value={sms.message_template}
                onChange={(e) => setSms((s) => ({ ...s, message_template: e.target.value }))}
                maxLength={500}
              />
            </label>
            <Button type="submit" disabled={saving}>
              {saving ? 'Saving…' : 'Save SMS config'}
            </Button>
          </form>
        </Panel>
      ) : (
        <Panel title="OTP print & citizen login">
          <form className="form-grid" onSubmit={onSaveOtp}>
            <h3>Print OTP</h3>
            <label>
              TTL (seconds)
              <Input
                type="number"
                value={otpPrint.ttlSeconds}
                onChange={(e) =>
                  setOtpPrint((s) => ({ ...s, ttlSeconds: Number(e.target.value) }))
                }
              />
            </label>
            <label>
              OTP length
              <Input
                type="number"
                value={otpPrint.otpLength}
                onChange={(e) =>
                  setOtpPrint((s) => ({ ...s, otpLength: Number(e.target.value) }))
                }
              />
            </label>
            <label>
              Max pages per session
              <Input
                type="number"
                value={otpPrint.maxPagesPerSession}
                onChange={(e) =>
                  setOtpPrint((s) => ({ ...s, maxPagesPerSession: Number(e.target.value) }))
                }
              />
            </label>
            <label>
              Max documents per session
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

            <h3>Citizen login OTP</h3>
            <label>
              Login OTP TTL (seconds)
              <Input
                type="number"
                value={citizenAuth.ttlSeconds}
                onChange={(e) =>
                  setCitizenAuth((s) => ({ ...s, ttlSeconds: Number(e.target.value) }))
                }
              />
            </label>
            <label>
              Login OTP length
              <Input
                type="number"
                value={citizenAuth.otpLength}
                onChange={(e) =>
                  setCitizenAuth((s) => ({ ...s, otpLength: Number(e.target.value) }))
                }
              />
            </label>
            <label>
              Login max verify attempts
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
            <Button type="submit" disabled={saving}>
              {saving ? 'Saving…' : 'Save OTP settings'}
            </Button>
          </form>
        </Panel>
      )}
    </div>
  );
}
