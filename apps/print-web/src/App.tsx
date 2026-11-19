import { type ReactNode, useEffect, useMemo, useRef, useState } from 'react';
import { Navigate, Route, Routes, useParams } from 'react-router-dom';
import {
  ApiError,
  createAstrologyPrintOrder,
  createOrder,
  getAstrologyPrintCheckout,
  getSession,
  loadRazorpay,
  requestPhoneOtp,
  sendSupportNote,
  uploadDocuments,
  verifyAstrologyPrintPayment,
  verifyPayment,
  verifyPhoneOtp,
  type AstrologyPrintCheckout,
  type QuickPrintSession,
} from './api';
import { countUploadPages, isPdf } from './count_pages';

const PLAY_STORE_URL =
  'https://play.google.com/store/apps/details?id=com.imt.skp_mobile';

type Step = 'chooser' | 'identity' | 'upload' | 'pay' | 'done' | 'error';

type UploadFile = {
  file: File;
  copies: number;
  /** null while pending or when count failed */
  pageCount: number | null;
  pageStatus: 'pending' | 'ready' | 'error';
};

function formatMoney(paise: number): string {
  return `₹${(paise / 100).toFixed(0)}`;
}

function formatBytes(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${Math.round(bytes / 1024)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

function IconPhone() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <rect x="7" y="3" width="10" height="18" rx="2.2" stroke="currentColor" strokeWidth="1.8" />
      <path d="M11 18h2" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
    </svg>
  );
}

function IconLock() {
  return (
    <svg width="28" height="28" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <rect x="5" y="11" width="14" height="10" rx="2" stroke="currentColor" strokeWidth="1.8" />
      <path
        d="M8 11V8a4 4 0 0 1 8 0v3"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
      />
    </svg>
  );
}

function IconPhoneLarge() {
  return (
    <svg width="28" height="28" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <rect x="7" y="3" width="10" height="18" rx="2.2" stroke="currentColor" strokeWidth="1.8" />
      <path d="M11 18h2" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
    </svg>
  );
}

function digitsOnly(value: string, max = 10): string {
  return value.replace(/\D/g, '').slice(0, max);
}

function phoneHint(phoneDigits: string): string {
  const d = digitsOnly(phoneDigits, 10);
  if (d.length < 4) return '****';
  return `****${d.slice(-4)}`;
}

function IconApp() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <rect x="4" y="4" width="7" height="7" rx="1.6" stroke="currentColor" strokeWidth="1.8" />
      <rect x="13" y="4" width="7" height="7" rx="1.6" stroke="currentColor" strokeWidth="1.8" />
      <rect x="4" y="13" width="7" height="7" rx="1.6" stroke="currentColor" strokeWidth="1.8" />
      <rect x="13" y="13" width="7" height="7" rx="1.6" stroke="currentColor" strokeWidth="1.8" />
    </svg>
  );
}

function IconCheck() {
  return (
    <svg width="28" height="28" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path d="M20 7 10 17l-6-6" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

function IconAlert() {
  return (
    <svg width="28" height="28" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path d="M12 8v5M12 16.5h.01" stroke="currentColor" strokeWidth="2.1" strokeLinecap="round" />
      <path
        d="M10.2 4.7 2.7 18a2 2 0 0 0 1.75 3h15.1A2 2 0 0 0 21.3 18L13.8 4.7a2 2 0 0 0-3.6 0Z"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinejoin="round"
      />
    </svg>
  );
}

function IconQr() {
  return (
    <svg width="28" height="28" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path d="M4 4h6v6H4V4Zm10 0h6v6h-6V4ZM4 14h6v6H4v-6Z" stroke="currentColor" strokeWidth="1.8" />
      <path d="M14 14h3v3h-3v-3Zm5 0v6m-6-1h2" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
    </svg>
  );
}

function IconSpinner() {
  return (
    <svg width="26" height="26" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path d="M12 4a8 8 0 1 1-8 8" stroke="currentColor" strokeWidth="2.1" strokeLinecap="round" />
    </svg>
  );
}

function IconArrow() {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path d="M9 6l6 6-6 6" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

const PRIVACY_NO_SAVE_DOCS =
  'We do not save your documents. Files are used only for this print session, then removed from the kiosk.';

function PrivacyNote() {
  return <p className="banner privacy">{PRIVACY_NO_SAVE_DOCS}</p>;
}

function StepRail({ active }: { active: 'upload' | 'pay' }) {
  return (
    <div className="step-rail" aria-label="Progress">
      <span className={active === 'upload' ? 'active' : undefined}>Upload</span>
      <span className="dot" aria-hidden="true" />
      <span className={active === 'pay' ? 'active' : undefined}>Pay</span>
    </div>
  );
}

function AppShell({
  step,
  title,
  subtitle,
  status,
  statusTone,
  footer,
  hero,
  brandAsHero,
  children,
}: {
  step?: ReactNode;
  title: string;
  subtitle?: string;
  status?: ReactNode;
  statusTone?: 'ok' | 'danger' | 'spin';
  footer?: ReactNode;
  hero?: boolean;
  /** Put ATHENA in the body as the hero signal (home). */
  brandAsHero?: boolean;
  children?: ReactNode;
}) {
  const bodyClass = [
    'body',
    status ? 'body-status' : '',
    hero || brandAsHero ? 'body-hero' : '',
  ]
    .filter(Boolean)
    .join(' ');

  return (
    <div className="shell">
      <div className="atmosphere" aria-hidden="true" />
      <header className="topbar">
        <div className="brand-lockup">
          <p className="brand-eyebrow">Quick Print</p>
          {brandAsHero ? null : (
            <img src="/athena_logo.png" alt="ATHENA" className="brand-logo" />
          )}
        </div>
        {step ?? null}
      </header>
      <main className={bodyClass}>
        {status ? <div className={`status-icon ${statusTone ?? ''}`}>{status}</div> : null}
        {brandAsHero ? (
          <h1 className="display brand-hero">
            <img src="/athena_logo.png" alt="ATHENA" className="brand-logo-hero" />
          </h1>
        ) : hero ? (
          <h1 className="display">{title}</h1>
        ) : (
          <h1>{title}</h1>
        )}
        {subtitle ? <p className="lede">{subtitle}</p> : null}
        {children}
      </main>
      {footer ? <footer className="dock">{footer}</footer> : null}
    </div>
  );
}

function SessionPage() {
  const { token = '' } = useParams();
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [step, setStep] = useState<Step>('chooser');
  const [session, setSession] = useState<QuickPrintSession | null>(null);
  const [files, setFiles] = useState<UploadFile[]>([]);
  const [colorMode, setColorMode] = useState<'bw' | 'color'>('bw');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [phone, setPhone] = useState('');
  const [otp, setOtp] = useState('');
  const [otpSent, setOtpSent] = useState(false);
  /** Identity fork: pick cards first, then phone verify. */
  const [identityPath, setIdentityPath] = useState<'pick' | 'verify'>('pick');
  const [devOtp, setDevOtp] = useState<string | null>(null);
  const [supportOpen, setSupportOpen] = useState(false);
  const [supportMessage, setSupportMessage] = useState('');
  const [supportReference, setSupportReference] = useState('');
  const [supportSending, setSupportSending] = useState(false);
  const [supportReceived, setSupportReceived] = useState(false);
  const [supportError, setSupportError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    void (async () => {
      try {
        const next = await getSession(token);
        if (cancelled) return;
        setSession(next);
        if (next.status === 'ready' || next.status === 'consumed') {
          setStep('done');
        } else if (next.status === 'awaiting_payment') {
          setStep('pay');
        } else if (next.phoneVerified) {
          setStep('upload');
        }
      } catch (err) {
        if (cancelled) return;
        setError(err instanceof ApiError ? err.message : 'This print link is invalid or expired.');
        setStep('error');
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [token]);

  const freePages = useMemo(() => {
    if (!session || !session.phoneVerified || session.freeDisabledNow) return 0;
    const remaining =
      colorMode === 'color' ? session.quota?.remainingColor : session.quota?.remainingBw;
    const kioskCap =
      colorMode === 'color'
        ? session.printLimits.freeColorPagesPerSession
        : session.printLimits.freePagesPerSession;
    if (remaining == null) return kioskCap;
    return Math.min(remaining, kioskCap);
  }, [colorMode, session]);

  const extraCharge = useMemo(() => {
    if (!session) return 0;
    return colorMode === 'color'
      ? session.printLimits.extraColorPageChargeRupees
      : session.printLimits.extraPageChargeRupees;
  }, [colorMode, session]);

  function fileKey(file: File): string {
    return `${file.name}:${file.size}`;
  }

  function addFiles(list: FileList | null) {
    const incoming = Array.from(list ?? []).filter((file) => {
      const name = file.name.toLowerCase();
      const type = file.type.toLowerCase();
      return (
        type === 'application/pdf' ||
        type === 'image/jpeg' ||
        type === 'image/png' ||
        name.endsWith('.pdf') ||
        name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png')
      );
    });
    if (incoming.length === 0) {
      return;
    }
    setError(null);

    const additions: UploadFile[] = [];
    setFiles((prev) => {
      const existing = new Set(prev.map((item) => fileKey(item.file)));
      const nextAdditions: UploadFile[] = [];
      for (const file of incoming) {
        const key = fileKey(file);
        if (existing.has(key)) continue;
        existing.add(key);
        nextAdditions.push({
          file,
          copies: 1,
          pageCount: null,
          pageStatus: 'pending',
        });
      }
      additions.splice(0, additions.length, ...nextAdditions);
      if (nextAdditions.length === 0) return prev;
      return [...prev, ...nextAdditions];
    });

    for (const item of additions) {
      const key = fileKey(item.file);
      void (async () => {
        try {
          const pages = await countUploadPages(item.file);
          setFiles((current) =>
            current.map((row) =>
              fileKey(row.file) === key
                ? { ...row, pageCount: pages, pageStatus: 'ready' }
                : row,
            ),
          );
        } catch {
          setFiles((current) =>
            current.map((row) =>
              fileKey(row.file) === key
                ? { ...row, pageCount: null, pageStatus: 'error' }
                : row,
            ),
          );
        }
      })();
    }
  }

  function removeFile(index: number) {
    setError(null);
    setFiles((prev) => prev.filter((_, i) => i !== index));
    if (fileInputRef.current) {
      fileInputRef.current.value = '';
    }
  }

  function setFileCopies(index: number, copies: number) {
    const next = Math.min(10, Math.max(1, Math.floor(copies)));
    setFiles((prev) =>
      prev.map((item, i) => (i === index ? { ...item, copies: next } : item)),
    );
  }

  const billablePreview = useMemo(() => {
    if (files.length === 0) return null;
    if (files.some((f) => f.pageStatus === 'pending')) return 'counting' as const;
    if (files.some((f) => f.pageStatus !== 'ready' || f.pageCount == null)) {
      return null;
    }
    return files.reduce((sum, f) => sum + (f.pageCount ?? 0) * f.copies, 0);
  }, [files]);

  async function onRequestOtp() {
    const phoneDigits = digitsOnly(phone, 10);
    setBusy(true);
    setError(null);
    try {
      const result = await requestPhoneOtp(token, phoneDigits);
      setPhone(phoneDigits);
      setOtpSent(true);
      setDevOtp(result.devOtp ?? null);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Could not send OTP.');
    } finally {
      setBusy(false);
    }
  }

  async function onVerifyOtp() {
    const phoneDigits = digitsOnly(phone, 10);
    const code = digitsOnly(otp, 8);
    setBusy(true);
    setError(null);
    try {
      const next = await verifyPhoneOtp(token, phoneDigits, code);
      setSession(next);
      setStep('upload');
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Invalid OTP.');
    } finally {
      setBusy(false);
    }
  }

  function onChangeNumber() {
    setOtpSent(false);
    setOtp('');
    setDevOtp(null);
    setError(null);
    setIdentityPath('verify');
  }

  function onSkipPhone() {
    setError(null);
    setStep('upload');
  }

  function goToIdentity() {
    setIdentityPath('pick');
    setOtpSent(false);
    setOtp('');
    setDevOtp(null);
    setError(null);
    setStep('identity');
  }

  const phoneDigits = digitsOnly(phone, 10);
  const otpDigits = digitsOnly(otp, 8);

  async function onUpload() {
    if (!files.length) return;
    setBusy(true);
    setError(null);
    try {
      const next = await uploadDocuments(token, files, colorMode);
      setSession(next);
      setStep(next.paymentRequired ? 'pay' : 'done');
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Could not upload the documents.');
    } finally {
      setBusy(false);
    }
  }

  async function onPay() {
    setBusy(true);
    setError(null);
    try {
      const order = await createOrder(token);
      if (order.alreadyPaid) {
        const next = await getSession(token);
        setSession(next);
        setStep('done');
        return;
      }
      if (!order.razorpay_order_id) {
        throw new Error('Payment order was not created');
      }
      await loadRazorpay();
      await new Promise<void>((resolve, reject) => {
        const checkout = new window.Razorpay({
          key: order.razorpay_key_id,
          amount: order.payment.amountPaise,
          currency: order.payment.currency,
          name: 'ATHENA Print',
          description: 'Extra print pages',
          order_id: order.razorpay_order_id!,
          handler: (response) => {
            void verifyPayment(token, response)
              .then(async () => {
                const next = await getSession(token);
                setSession(next);
                setStep('done');
                resolve();
              })
              .catch(reject);
          },
          modal: {
            ondismiss: () => reject(new Error('Payment cancelled')),
          },
        });
        checkout.open();
      });
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Payment failed. You can try again.');
    } finally {
      setBusy(false);
    }
  }

  async function onSendSupport() {
    const text = supportMessage.trim();
    if (!text || supportSending) return;
    setSupportSending(true);
    setSupportError(null);
    try {
      const reference = supportReference.trim();
      await sendSupportNote(token, {
        message: text,
        ...(reference ? { paymentReference: reference } : {}),
      });
      setSupportReceived(true);
    } catch (err) {
      if (err instanceof ApiError && err.code === 'payment_already_settled') {
        try {
          const next = await getSession(token);
          setSession(next);
          setStep('done');
        } catch (loadError) {
          setSupportError(
            loadError instanceof ApiError ? loadError.message : 'This payment is already settled.',
          );
        }
        return;
      }
      setSupportError(err instanceof ApiError ? err.message : 'Could not send this note.');
    } finally {
      setSupportSending(false);
    }
  }

  if (step === 'error') {
    return (
      <AppShell
        title="Link unavailable"
        subtitle={error ?? 'This print link is invalid or expired.'}
        status={<IconAlert />}
        statusTone="danger"
      />
    );
  }

  if (!session) {
    return (
      <AppShell
        title="Opening session"
        subtitle="Connecting to this kiosk…"
        status={<IconSpinner />}
        statusTone="spin"
      />
    );
  }

  if (step === 'chooser') {
    return (
      <AppShell
        hero
        title="Print from this kiosk"
        subtitle="Continue here on your phone, or get the app if you print often."
      >
        <span className="kiosk-line">{session.deviceName || 'This kiosk'}</span>
        <div className="choices">
          <button className="choice choice-primary" type="button" onClick={goToIdentity}>
            <span className="choice-icon">
              <IconPhone />
            </span>
            <span className="choice-copy">
              <span className="choice-title">Print from this phone</span>
              <span className="choice-sub">Upload PDF or JPG/PNG in the browser and send them to the machine</span>
            </span>
            <span className="choice-arrow">
              <IconArrow />
            </span>
          </button>
          <a className="choice" href={PLAY_STORE_URL}>
            <span className="choice-icon">
              <IconApp />
            </span>
            <span className="choice-copy">
              <span className="choice-title">Get the app</span>
              <span className="choice-sub">Save documents and print later with an OTP</span>
            </span>
            <span className="choice-arrow">
              <IconArrow />
            </span>
          </a>
        </div>
      </AppShell>
    );
  }

  if (step === 'identity') {
    const freeOff = Boolean(session.freeDisabledNow);
    const picking = !otpSent && identityPath === 'pick';
    const verifying = !otpSent && identityPath === 'verify';

    const identityTitle = otpSent
      ? 'Enter verification code'
      : picking
        ? freeOff
          ? 'How do you want to continue?'
          : 'Use free pages?'
        : 'Verify mobile number';

    const identitySubtitle = freeOff
      ? otpSent
        ? `We sent a one-time code to +91 ${phoneHint(phoneDigits)}.`
        : 'Free pages are not available at this kiosk right now. You can still print — all pages are paid.'
      : otpSent
        ? `We sent a one-time code to +91 ${phoneHint(phoneDigits)}.`
        : picking
          ? 'Verify your mobile to unlock free pages, or continue and pay for every page.'
          : 'Enter your 10-digit mobile number to receive a one-time code.';

    return (
      <AppShell
        title={identityTitle}
        subtitle={identitySubtitle}
        status={otpSent ? <IconLock /> : <IconPhoneLarge />}
        statusTone="ok"
        footer={
          <>
            {error ? <p className="banner error">{error}</p> : null}
            {verifying ? (
              <button
                className="primary"
                type="button"
                disabled={busy || phoneDigits.length < 10}
                onClick={() => void onRequestOtp()}
              >
                {busy ? 'Sending OTP…' : 'Send OTP'}
              </button>
            ) : null}
            {otpSent ? (
              <>
                <button
                  className="primary"
                  type="button"
                  disabled={busy || otpDigits.length < 4}
                  onClick={() => void onVerifyOtp()}
                >
                  {busy ? 'Verifying…' : 'Verify & continue'}
                </button>
                <button className="secondary" type="button" disabled={busy} onClick={onSkipPhone}>
                  Continue without free pages
                </button>
              </>
            ) : null}
          </>
        }
      >
        <PrivacyNote />
        {picking ? (
          <div className="choices">
            {freeOff ? (
              <>
                <button
                  className="choice choice-primary"
                  type="button"
                  disabled={busy}
                  onClick={onSkipPhone}
                >
                  <span className="choice-icon">
                    <IconArrow />
                  </span>
                  <span className="choice-copy">
                    <span className="choice-title">Continue to print</span>
                    <span className="choice-sub">Skip mobile verification — pay for every page</span>
                  </span>
                  <span className="choice-arrow">
                    <IconArrow />
                  </span>
                </button>
                <button
                  className="choice"
                  type="button"
                  disabled={busy}
                  onClick={() => {
                    setError(null);
                    setIdentityPath('verify');
                  }}
                >
                  <span className="choice-icon">
                    <IconPhone />
                  </span>
                  <span className="choice-copy">
                    <span className="choice-title">Verify mobile anyway</span>
                    <span className="choice-sub">Optional — free pages are off at this kiosk right now</span>
                  </span>
                  <span className="choice-arrow">
                    <IconArrow />
                  </span>
                </button>
              </>
            ) : (
              <>
                <button
                  className="choice choice-primary"
                  type="button"
                  disabled={busy}
                  onClick={() => {
                    setError(null);
                    setIdentityPath('verify');
                  }}
                >
                  <span className="choice-icon">
                    <IconPhone />
                  </span>
                  <span className="choice-copy">
                    <span className="choice-title">Verify mobile for free pages</span>
                    <span className="choice-sub">Unlock free pages at this kiosk with a one-time code</span>
                  </span>
                  <span className="choice-arrow">
                    <IconArrow />
                  </span>
                </button>
                <button
                  className="choice"
                  type="button"
                  disabled={busy}
                  onClick={onSkipPhone}
                >
                  <span className="choice-icon">
                    <IconArrow />
                  </span>
                  <span className="choice-copy">
                    <span className="choice-title">Continue without free pages</span>
                    <span className="choice-sub">Skip verification — pay for every page</span>
                  </span>
                  <span className="choice-arrow">
                    <IconArrow />
                  </span>
                </button>
              </>
            )}
          </div>
        ) : (
          <div className="auth-panel">
            {!otpSent ? (
              <>
                <button
                  className="link-action identity-back"
                  type="button"
                  disabled={busy}
                  onClick={() => {
                    setError(null);
                    setIdentityPath('pick');
                  }}
                >
                  Back to options
                </button>
                <label className="field">
                  <span className="field-label">Mobile number</span>
                  <div className="phone-row">
                    <span className="phone-prefix" aria-hidden="true">
                      +91
                    </span>
                    <input
                      className="phone-input"
                      type="tel"
                      inputMode="numeric"
                      autoComplete="tel-national"
                      autoFocus
                      placeholder="98765 43210"
                      maxLength={10}
                      value={phoneDigits}
                      disabled={busy}
                      onChange={(e) => setPhone(digitsOnly(e.target.value, 10))}
                      aria-label="10-digit mobile number"
                    />
                  </div>
                </label>
              </>
            ) : (
              <>
                <div className="otp-meta">
                  <span className="otp-sent-to">+91 {phoneHint(phoneDigits)}</span>
                  <button
                    className="link-action"
                    type="button"
                    disabled={busy}
                    onClick={onChangeNumber}
                  >
                    Change number
                  </button>
                </div>
                <label className="field">
                  <span className="field-label">One-time password</span>
                  <input
                    className="otp-input"
                    type="text"
                    inputMode="numeric"
                    autoComplete="one-time-code"
                    autoFocus
                    placeholder="••••••"
                    maxLength={6}
                    value={otpDigits}
                    disabled={busy}
                    onChange={(e) => setOtp(digitsOnly(e.target.value, 6))}
                    aria-label="OTP code"
                  />
                </label>
                {devOtp ? (
                  <p className="dev-otp-note">
                    Dev code <strong>{devOtp}</strong>
                  </p>
                ) : null}
              </>
            )}
          </div>
        )}
      </AppShell>
    );
  }

  if (step === 'done') {
    return (
      <AppShell
        title="Look at the kiosk"
        subtitle="Your documents are ready. Finish preview and print on the machine."
        status={<IconCheck />}
        statusTone="ok"
      >
        {session.documentLabel ? <div className="doc-label">{session.documentLabel}</div> : null}
      </AppShell>
    );
  }

  if (step === 'pay') {
    const quote = session.quote;
    return (
      <AppShell
        step={<StepRail active="pay" />}
        title="Pay extra pages"
        subtitle="Free pages are already included. Pay only for the extra sheets."
        footer={
          <>
            {error ? <p className="banner error">{error}</p> : null}
            <button className="primary" type="button" disabled={busy} onClick={() => void onPay()}>
              {busy ? 'Opening payment…' : error ? 'Pay again' : 'Pay now'}
            </button>
          </>
        }
      >
        <div className="ticket">
          <div className="ticket-row">
            <span>Pages</span>
            <strong>{quote ? quote.pageCount : session.pageCount}</strong>
          </div>
          <div className="ticket-row">
            <span>Extra pages</span>
            <strong>{quote ? quote.extraPages : '—'}</strong>
          </div>
          <div className="ticket-row ticket-total">
            <span>Amount due</span>
            <strong>{quote ? formatMoney(quote.amountPaise) : 'Payment required'}</strong>
          </div>
        </div>
        {error ? (
          <div className="support-box">
            {supportReceived ? (
              <p className="banner">We received this. Staff will check this payment.</p>
            ) : (
              <>
                <button className="linkish" type="button" onClick={() => setSupportOpen(true)}>
                  Money deducted? Contact support
                </button>
                {supportOpen ? (
                  <>
                    <label className="field">
                      <span className="field-label">What happened</span>
                      <textarea
                        maxLength={500}
                        value={supportMessage}
                        onChange={(event) => setSupportMessage(event.target.value)}
                      />
                    </label>
                    <label className="field">
                      <span className="field-label">UPI or bank reference</span>
                      <input
                        maxLength={80}
                        value={supportReference}
                        onChange={(event) => setSupportReference(event.target.value)}
                        placeholder="Optional"
                      />
                    </label>
                    {supportError ? <p className="banner error">{supportError}</p> : null}
                    <button
                      className="primary"
                      type="button"
                      disabled={supportSending || supportMessage.trim().length === 0}
                      onClick={() => void onSendSupport()}
                    >
                      {supportSending ? 'Sending…' : 'Send'}
                    </button>
                  </>
                ) : null}
              </>
            )}
          </div>
        ) : null}
      </AppShell>
    );
  }

  return (
    <AppShell
      step={<StepRail active="upload" />}
      title="Upload files"
      subtitle={
        session.phoneVerified
          ? session.freeDisabledNow
            ? 'Free pages are off at this kiosk right now. All pages will be charged.'
            : `Verified ${session.verifiedPhoneHint ?? 'phone'}. Free quota applies within kiosk caps.`
          : 'Printing without phone verification — all pages are paid.'
      }
      footer={
        <>
          {error ? <p className="banner error">{error}</p> : null}
          {files.length > 0 ? (
            <p className="upload-total" aria-live="polite">
              {billablePreview === 'counting'
                ? 'Counting pages…'
                : typeof billablePreview === 'number'
                  ? `Total: ${billablePreview} billable page${billablePreview === 1 ? '' : 's'}`
                  : 'Page totals will be confirmed after upload'}
            </p>
          ) : null}
          <button className="primary" type="button" disabled={busy || files.length === 0} onClick={() => void onUpload()}>
            {busy ? 'Uploading…' : files.length ? `Send ${files.length} file${files.length === 1 ? '' : 's'} to kiosk` : 'Send to kiosk'}
          </button>
        </>
      }
    >
      <PrivacyNote />
      <div className="meter" aria-label="Print limits">
        <div className="meter-cell">
          <span className="meter-label">Free</span>
          <span className="meter-value">
            {freePages} {colorMode === 'color' ? 'color' : 'B/W'}
          </span>
        </div>
        <div className="meter-cell">
          <span className="meter-label">Extra</span>
          <span className="meter-value">₹{extraCharge}/pg</span>
        </div>
        <div className="meter-cell">
          <span className="meter-label">Max</span>
          <span className="meter-value">{session.printLimits.maxPagesPerSession} pg</span>
        </div>
      </div>
      <div className="segment" role="group" aria-label="Print color">
        <button type="button" className={colorMode === 'bw' ? 'active' : ''} onClick={() => setColorMode('bw')}>
          Black & white
        </button>
        <button type="button" className={colorMode === 'color' ? 'active' : ''} onClick={() => setColorMode('color')}>
          Color
        </button>
      </div>
      <label className="dropzone">
        <input
          ref={fileInputRef}
          type="file"
          accept="application/pdf,.pdf,image/jpeg,.jpg,.jpeg,image/png,.png"
          multiple
          onChange={(event) => addFiles(event.target.files)}
        />
        <strong>Tap to add PDF or JPG/PNG</strong>
        <small>You can attach more than one file</small>
      </label>
      {files.length > 0 ? (
        <ul className="files">
          {files.map((item, index) => {
            const pdf = isPdf(item.file);
            const sizeLabel = formatBytes(item.file.size);
            const metaLabel =
              item.pageStatus === 'pending'
                ? `Counting… · ${sizeLabel}`
                : item.pageStatus === 'ready' && item.pageCount != null
                  ? `${item.pageCount} page${item.pageCount === 1 ? '' : 's'} · ${sizeLabel}`
                  : `Pages unknown · ${sizeLabel}`;
            const billable =
              item.pageStatus === 'ready' && item.pageCount != null
                ? item.pageCount * item.copies
                : null;
            return (
              <li className="file-card" key={`${item.file.name}-${item.file.size}-${index}`}>
                <div className="file-card-top">
                  <span className="file-thumb">{pdf ? 'PDF' : 'IMG'}</span>
                  <div className="file-meta">
                    <strong title={item.file.name}>{item.file.name}</strong>
                    <span className="file-card-meta">{metaLabel}</span>
                  </div>
                  <button
                    className="file-remove"
                    type="button"
                    aria-label={`Remove ${item.file.name}`}
                    onClick={() => removeFile(index)}
                  >
                    Remove
                  </button>
                </div>
                <div className="file-card-copies">
                  <span className="copies-label">Copies</span>
                  <div className="copies-stepper" aria-label={`Copies for ${item.file.name}`}>
                    <button
                      className="copies-btn"
                      type="button"
                      aria-label="Fewer copies"
                      disabled={item.copies <= 1}
                      onClick={() => setFileCopies(index, item.copies - 1)}
                    >
                      −
                    </button>
                    <span className="copies-value">{item.copies}×</span>
                    <button
                      className="copies-btn"
                      type="button"
                      aria-label="More copies"
                      disabled={item.copies >= 10}
                      onClick={() => setFileCopies(index, item.copies + 1)}
                    >
                      +
                    </button>
                  </div>
                </div>
                {billable != null && item.copies > 1 ? (
                  <p className="file-billable">
                    {item.pageCount} page{item.pageCount === 1 ? '' : 's'} × {item.copies} copies = {billable}
                  </p>
                ) : null}
              </li>
            );
          })}
        </ul>
      ) : null}
    </AppShell>
  );
}

function HomePage() {
  return (
    <AppShell
      brandAsHero
      title="ATHENA"
      subtitle="Scan the QR on the kiosk to start Quick Print from your phone."
    >
      <div className="hero-mark" aria-hidden="true">
        <IconQr />
      </div>
    </AppShell>
  );
}

function AstrologyPrintPage() {
  const { token = '' } = useParams();
  const [checkout, setCheckout] = useState<AstrologyPrintCheckout | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [done, setDone] = useState(false);

  useEffect(() => {
    let cancelled = false;
    void (async () => {
      try {
        const next = await getAstrologyPrintCheckout(token);
        if (cancelled) return;
        setCheckout(next);
        if (next.status === 'PAID') setDone(true);
      } catch (err) {
        if (!cancelled) {
          setError(err instanceof ApiError ? err.message : 'Checkout not found.');
        }
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [token]);

  async function onPay() {
    setBusy(true);
    setError(null);
    try {
      const order = await createAstrologyPrintOrder(token);
      if (order.alreadyPaid) {
        setDone(true);
        return;
      }
      if (!order.razorpay_order_id) {
        throw new Error('Payment order was not created');
      }
      await loadRazorpay();
      await new Promise<void>((resolve, reject) => {
        const checkoutWindow = new window.Razorpay({
          key: order.razorpay_key_id,
          amount: order.payment.amountPaise,
          currency: order.payment.currency,
          name: 'ATHENA Kundali',
          description: 'Color Kundali print',
          order_id: order.razorpay_order_id!,
          handler: (response) => {
            void verifyAstrologyPrintPayment(token, response)
              .then(() => {
                setDone(true);
                resolve();
              })
              .catch(reject);
          },
          modal: {
            ondismiss: () => reject(new Error('Payment cancelled')),
          },
        });
        checkoutWindow.open();
      });
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Payment failed. You can try again.');
    } finally {
      setBusy(false);
    }
  }

  if (error && !checkout) {
    return (
      <AppShell title="ATHENA" subtitle="Kundali print payment">
        <p className="banner error">{error}</p>
      </AppShell>
    );
  }

  if (!checkout) {
    return (
      <AppShell title="ATHENA" subtitle="Kundali print payment">
        <p>Loading…</p>
      </AppShell>
    );
  }

  if (done || checkout.status === 'PAID') {
    return (
      <AppShell title="ATHENA" subtitle="Payment complete">
        <p className="banner">Paid. Return to the kiosk to print your Kundali.</p>
      </AppShell>
    );
  }

  if (checkout.status === 'EXPIRED' || checkout.status === 'CANCELLED') {
    return (
      <AppShell title="ATHENA" subtitle="Payment unavailable">
        <p className="banner error">This payment window has expired. Start print again on the kiosk.</p>
      </AppShell>
    );
  }

  return (
    <AppShell title="ATHENA" subtitle="Kundali color print">
      <div className="pay-card">
        <h2>{checkout.title}</h2>
        <p className="amount">{formatMoney(checkout.amountPaise)}</p>
        <button type="button" className="primary" disabled={busy} onClick={() => void onPay()}>
          {busy ? 'Opening payment…' : error ? 'Pay again' : 'Pay now'}
        </button>
        {error ? <p className="banner error">{error}</p> : null}
      </div>
    </AppShell>
  );
}

export function App() {
  return (
    <Routes>
      <Route path="/" element={<HomePage />} />
      <Route path="/s/:token" element={<SessionPage />} />
      <Route path="/astrology-print/:token" element={<AstrologyPrintPage />} />
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}
