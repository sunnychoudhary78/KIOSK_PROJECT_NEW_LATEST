import { useEffect, useMemo, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { apiRequest } from '../../core/api/client';
import { useAuth } from '../../core/auth/auth-context';
import {
  Button,
  Input,
  PageHeader,
  Panel,
  Select,
  Stepper,
} from '../../core/ui/primitives';
import { CreativeUploadModal } from './CreativeUploadModal';
import type { Advertiser, Creative, Device, Site } from './types';

const STEPS = ['Basics', 'Creatives', 'Targeting', 'Review'];

type TargetMode = 'all' | 'sites' | 'devices';

function toIsoOrNull(localValue: string): string | null {
  if (!localValue) {
    return null;
  }
  const date = new Date(localValue);
  return Number.isNaN(date.getTime()) ? null : date.toISOString();
}

export function CampaignWizardPage() {
  const { token } = useAuth();
  const navigate = useNavigate();
  const [params] = useSearchParams();
  const [step, setStep] = useState(0);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const [advertisers, setAdvertisers] = useState<Advertiser[]>([]);
  const [creatives, setCreatives] = useState<Creative[]>([]);
  const [sites, setSites] = useState<Site[]>([]);
  const [devices, setDevices] = useState<Device[]>([]);

  const [advertiserId, setAdvertiserId] = useState(params.get('advertiserId') ?? '');
  const [name, setName] = useState('');
  const [startsAt, setStartsAt] = useState('');
  const [endsAt, setEndsAt] = useState('');
  const [priority, setPriority] = useState(0);
  const [idleCreativeId, setIdleCreativeId] = useState('');
  const [bannerCreativeId, setBannerCreativeId] = useState('');
  const [targetMode, setTargetMode] = useState<TargetMode>('all');
  const [selectedSiteIds, setSelectedSiteIds] = useState<string[]>([]);
  const [selectedDeviceIds, setSelectedDeviceIds] = useState<string[]>([]);
  const [startNow, setStartNow] = useState(false);
  const [uploadOpen, setUploadOpen] = useState(false);

  useEffect(() => {
    void Promise.all([
      apiRequest<{ items: Advertiser[] }>('/ads/advertisers', { token }),
      apiRequest<{ items: Creative[] }>('/ads/creatives', { token }),
      apiRequest<{ items: Site[] }>('/ads/sites', { token }),
      apiRequest<{ items: Device[] }>('/devices', { token }),
    ])
      .then(([adv, cre, sit, dev]) => {
        setAdvertisers(adv.items);
        setCreatives(cre.items);
        setSites(sit.items);
        setDevices(dev.items);
        if (!advertiserId && adv.items[0]) {
          setAdvertiserId(adv.items[0].id);
        }
      })
      .catch((err) => {
        setError(err instanceof Error ? err.message : 'Failed to load wizard data');
      });
  }, [token]);

  const advertiserCreatives = useMemo(
    () => creatives.filter((c) => c.advertiserId === advertiserId),
    [creatives, advertiserId],
  );

  const selectedAdvertiser = advertisers.find((a) => a.id === advertiserId);
  const idleCreative = advertiserCreatives.find((c) => c.id === idleCreativeId);
  const bannerCreative = advertiserCreatives.find((c) => c.id === bannerCreativeId);

  function validateStep(): boolean {
    setError(null);
    if (step === 0) {
      if (!advertiserId || !name.trim()) {
        setError('Advertiser and campaign name are required');
        return false;
      }
    }
    if (step === 1) {
      if (!idleCreativeId && !bannerCreativeId) {
        setError('Select at least one idle media or home banner creative');
        return false;
      }
    }
    if (step === 2) {
      if (targetMode === 'sites' && selectedSiteIds.length === 0) {
        setError('Select at least one site');
        return false;
      }
      if (targetMode === 'devices' && selectedDeviceIds.length === 0) {
        setError('Select at least one device');
        return false;
      }
    }
    return true;
  }

  function next() {
    if (!validateStep()) {
      return;
    }
    setStep((s) => Math.min(s + 1, STEPS.length - 1));
  }

  function back() {
    setError(null);
    setStep((s) => Math.max(s - 1, 0));
  }

  function toggleId(list: string[], id: string, setter: (v: string[]) => void) {
    setter(list.includes(id) ? list.filter((x) => x !== id) : [...list, id]);
  }

  async function submit() {
    if (!validateStep()) {
      return;
    }
    setBusy(true);
    setError(null);
    try {
      const campaign = await apiRequest<{ id: string }>('/ads/campaigns', {
        method: 'POST',
        token,
        body: {
          advertiserId,
          name: name.trim(),
          startsAt: toIsoOrNull(startsAt),
          endsAt: toIsoOrNull(endsAt),
          priority,
        },
      });

      const items = [];
      if (idleCreativeId) {
        items.push({ creativeId: idleCreativeId, slot: 'idle_video' });
      }
      if (bannerCreativeId) {
        items.push({ creativeId: bannerCreativeId, slot: 'home_banner' });
      }
      await apiRequest(`/ads/campaigns/${campaign.id}/creatives`, {
        method: 'PUT',
        token,
        body: { items },
      });
      await apiRequest(`/ads/campaigns/${campaign.id}/targets`, {
        method: 'PUT',
        token,
        body: {
          targetAll: targetMode === 'all',
          siteIds: targetMode === 'sites' ? selectedSiteIds : [],
          deviceIds: targetMode === 'devices' ? selectedDeviceIds : [],
        },
      });

      if (startNow) {
        await apiRequest(`/ads/campaigns/${campaign.id}/start`, { method: 'POST', token });
      }

      navigate(`/campaigns/${campaign.id}`);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to create campaign');
    } finally {
      setBusy(false);
    }
  }

  return (
    <div>
      <PageHeader
        title="New campaign"
        subtitle="Guided setup: basics → creatives → targeting → review"
      />

      <Panel>
        <Stepper steps={STEPS} current={step} />
        {error ? <p className="error">{error}</p> : null}

        {step === 0 ? (
          <div className="stack">
            <label>
              Advertiser
              <Select
                value={advertiserId}
                onChange={(e) => {
                  setAdvertiserId(e.target.value);
                  setIdleCreativeId('');
                  setBannerCreativeId('');
                }}
              >
                {advertisers.map((a) => (
                  <option key={a.id} value={a.id}>
                    {a.name}
                  </option>
                ))}
              </Select>
            </label>
            <label>
              Campaign name
              <Input value={name} onChange={(e) => setName(e.target.value)} required />
            </label>
            <label>
              Starts at (optional)
              <Input
                type="datetime-local"
                value={startsAt}
                onChange={(e) => setStartsAt(e.target.value)}
              />
            </label>
            <label>
              Ends at (optional)
              <Input
                type="datetime-local"
                value={endsAt}
                onChange={(e) => setEndsAt(e.target.value)}
              />
            </label>
            <label>
              Priority
              <Input
                type="number"
                min={0}
                max={1000}
                value={priority}
                onChange={(e) => setPriority(Number(e.target.value) || 0)}
              />
            </label>
          </div>
        ) : null}

        {step === 1 ? (
          <div className="stack">
            <div className="flex flex-wrap items-center justify-between gap-3">
              <p className="muted m-0">
                Choose existing media or upload new idle video/photos or a home banner. At least
                one is required.
              </p>
              <Button
                type="button"
                variant="secondary"
                disabled={!advertiserId}
                onClick={() => setUploadOpen(true)}
              >
                Upload media
              </Button>
            </div>
            <label>
              Idle media
              <Select
                value={idleCreativeId}
                onChange={(e) => setIdleCreativeId(e.target.value)}
              >
                <option value="">— none —</option>
                {advertiserCreatives
                  .filter(
                    (c) => c.type === 'video' || c.type === 'image' || c.type === 'carousel',
                  )
                  .map((c) => (
                    <option key={c.id} value={c.id}>
                      {c.title} ({c.type}
                      {c.type === 'carousel' && c.assets?.length
                        ? `, ${c.assets.length} photos`
                        : ''}
                      )
                    </option>
                  ))}
              </Select>
            </label>
            <label>
              Home banner
              <Select
                value={bannerCreativeId}
                onChange={(e) => setBannerCreativeId(e.target.value)}
              >
                <option value="">— none —</option>
                {advertiserCreatives
                  .filter((c) => c.type === 'banner')
                  .map((c) => (
                    <option key={c.id} value={c.id}>
                      {c.title} (banner)
                    </option>
                  ))}
              </Select>
            </label>
          </div>
        ) : null}

        {step === 2 ? (
          <div className="stack">
            <label>
              <input
                type="radio"
                checked={targetMode === 'all'}
                onChange={() => setTargetMode('all')}
              />{' '}
              All kiosks
            </label>
            <label>
              <input
                type="radio"
                checked={targetMode === 'sites'}
                onChange={() => setTargetMode('sites')}
              />{' '}
              By site
            </label>
            <label>
              <input
                type="radio"
                checked={targetMode === 'devices'}
                onChange={() => setTargetMode('devices')}
              />{' '}
              By device
            </label>

            {targetMode === 'sites' ? (
              <div className="check-list">
                {sites.map((s) => (
                  <label key={s.id}>
                    <input
                      type="checkbox"
                      checked={selectedSiteIds.includes(s.id)}
                      onChange={() => toggleId(selectedSiteIds, s.id, setSelectedSiteIds)}
                    />
                    {s.name} ({s.deviceCount} devices)
                  </label>
                ))}
              </div>
            ) : null}

            {targetMode === 'devices' ? (
              <div className="check-list">
                {devices.map((d) => (
                  <label key={d.id}>
                    <input
                      type="checkbox"
                      checked={selectedDeviceIds.includes(d.id)}
                      onChange={() => toggleId(selectedDeviceIds, d.id, setSelectedDeviceIds)}
                    />
                    {d.name} — {d.siteName}
                  </label>
                ))}
              </div>
            ) : null}
          </div>
        ) : null}

        {step === 3 ? (
          <div className="stack">
            <p>
              <strong>Advertiser:</strong> {selectedAdvertiser?.name ?? '—'}
            </p>
            <p>
              <strong>Name:</strong> {name}
            </p>
            <p>
              <strong>Schedule:</strong> {startsAt || 'immediately'} → {endsAt || 'no end'}
            </p>
            <p>
              <strong>Priority:</strong> {priority}
            </p>
            <p>
              <strong>Idle media:</strong>{' '}
              {idleCreative
                ? `${idleCreative.title} (${idleCreative.type})`
                : '—'}
            </p>
            <p>
              <strong>Home banner:</strong> {bannerCreative?.title ?? '—'}
            </p>
            <p>
              <strong>Targeting:</strong>{' '}
              {targetMode === 'all'
                ? 'All kiosks'
                : targetMode === 'sites'
                  ? `${selectedSiteIds.length} site(s)`
                  : `${selectedDeviceIds.length} device(s)`}
            </p>
            <label>
              <input
                type="checkbox"
                checked={startNow}
                onChange={(e) => setStartNow(e.target.checked)}
              />{' '}
              Start campaign immediately after create
            </label>
          </div>
        ) : null}

        <CreativeUploadModal
          open={uploadOpen}
          advertiserId={advertiserId}
          onClose={() => setUploadOpen(false)}
          onUploaded={(created) => {
            setCreatives((list) => [created, ...list.filter((c) => c.id !== created.id)]);
            if (created.type === 'banner') {
              setBannerCreativeId(created.id);
            } else {
              setIdleCreativeId(created.id);
            }
            setUploadOpen(false);
            setError(null);
          }}
        />

        <div className="wizard-nav">
          <Button type="button" variant="ghost" onClick={() => navigate('/campaigns')}>
            Cancel
          </Button>
          <div className="row-actions">
            {step > 0 ? (
              <Button type="button" variant="secondary" onClick={back}>
                Back
              </Button>
            ) : null}
            {step < STEPS.length - 1 ? (
              <Button type="button" onClick={next}>
                Next
              </Button>
            ) : (
              <Button type="button" disabled={busy} onClick={() => void submit()}>
                {busy ? 'Creating…' : startNow ? 'Create & start' : 'Create draft'}
              </Button>
            )}
          </div>
        </div>
      </Panel>
    </div>
  );
}
