import { type ReactNode, useEffect, useMemo, useRef, useState } from 'react';
import { Navigate, Route, Routes, useParams } from 'react-router-dom';
import {
  ApiError,
  createOrder,
  getSession,
  loadRazorpay,
  uploadDocuments,
  verifyPayment,
  type QuickPrintSession,
} from './api';

const PLAY_STORE_URL =
  import.meta.env.VITE_PLAY_STORE_URL ||
  'https://play.google.com/store/apps/details?id=com.smartkiosk.skp_mobile';

type Step = 'chooser' | 'upload' | 'pay' | 'done' | 'error';

function formatMoney(paise: number): string {
  return `₹${(paise / 100).toFixed(0)}`;
}

function formatBytes(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${Math.round(bytes / 1024)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

function IconPrint() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path
        d="M7 8V4h10v4M7 17H5a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2M7 13h10v7H7v-7Z"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinejoin="round"
      />
    </svg>
  );
}

function IconPhone() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <rect x="7" y="3" width="10" height="18" rx="2.2" stroke="currentColor" strokeWidth="1.8" />
      <path d="M11 18h2" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
    </svg>
  );
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

function AppShell({
  brand = 'Quick Print',
  step,
  title,
  subtitle,
  status,
  statusTone,
  footer,
  children,
}: {
  brand?: string;
  step?: string;
  title: string;
  subtitle?: string;
  status?: ReactNode;
  statusTone?: 'ok' | 'danger' | 'spin';
  footer?: ReactNode;
  children?: ReactNode;
}) {
  return (
    <div className="shell">
      <div className="glow" aria-hidden="true" />
      <header className="topbar">
        <div className="brand-lockup">
          <span className="mark">
            <IconPrint />
          </span>
          <div>
            <p className="brand">{brand}</p>
            <p className="brand-sub">Smart Kiosk</p>
          </div>
        </div>
        {step ? <span className="step-pill">{step}</span> : null}
      </header>
      <main className={status ? 'body body-status' : 'body'}>
        {status ? <div className={`status-icon ${statusTone ?? ''}`}>{status}</div> : null}
        <h1>{title}</h1>
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
  const [files, setFiles] = useState<File[]>([]);
  const [colorMode, setColorMode] = useState<'bw' | 'color'>('bw');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

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
    if (!session) return 0;
    return colorMode === 'color'
      ? session.printLimits.freeColorPagesPerSession
      : session.printLimits.freePagesPerSession;
  }, [colorMode, session]);

  const extraCharge = useMemo(() => {
    if (!session) return 0;
    return colorMode === 'color'
      ? session.printLimits.extraColorPageChargeRupees
      : session.printLimits.extraPageChargeRupees;
  }, [colorMode, session]);

  function addFiles(list: FileList | null) {
    const incoming = Array.from(list ?? []).filter(
      (file) => file.type === 'application/pdf' || file.name.toLowerCase().endsWith('.pdf'),
    );
    setFiles((prev) => {
      const map = new Map(prev.map((file) => [`${file.name}:${file.size}`, file]));
      for (const file of incoming) {
        map.set(`${file.name}:${file.size}`, file);
      }
      return Array.from(map.values());
    });
  }

  function removeFile(index: number) {
    setFiles((prev) => prev.filter((_, i) => i !== index));
    if (fileInputRef.current) {
      fileInputRef.current.value = '';
    }
  }

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
          name: 'Smart Kiosk Print',
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

  if (step === 'error') {
    return (
      <AppShell
        brand="Smart Kiosk"
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
        brand="Smart Kiosk"
        title="Opening print session"
        subtitle="Connecting to this kiosk…"
        status={<IconSpinner />}
        statusTone="spin"
      />
    );
  }

  if (step === 'chooser') {
    return (
      <AppShell
        title="Print from this kiosk"
        subtitle="Continue here on your phone, or get the app if you print often."
      >
        <span className="chip">{session.deviceName || 'This kiosk'}</span>
        <div className="choices">
          <button className="choice choice-primary" type="button" onClick={() => setStep('upload')}>
            <span className="choice-icon">
              <IconPhone />
            </span>
            <span className="choice-copy">
              <span className="choice-title">Print from this phone</span>
              <span className="choice-sub">Upload PDFs in the browser and send them to the machine</span>
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

  if (step === 'done') {
    return (
      <AppShell
        title="Look at the kiosk"
        subtitle="Your documents are ready. Finish preview and print on the machine."
        status={<IconCheck />}
        statusTone="ok"
      >
        {session.documentLabel ? <div className="card doc-label">{session.documentLabel}</div> : null}
      </AppShell>
    );
  }

  if (step === 'pay') {
    const quote = session.quote;
    return (
      <AppShell
        step="2 / 2"
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
        <div className="card receipt">
          <div className="receipt-row">
            <span>Pages</span>
            <strong>{quote ? quote.pageCount : session.pageCount}</strong>
          </div>
          <div className="receipt-row">
            <span>Extra pages</span>
            <strong>{quote ? quote.extraPages : '—'}</strong>
          </div>
          <div className="receipt-row receipt-total">
            <span>Amount due</span>
            <strong>{quote ? formatMoney(quote.amountPaise) : 'Payment required'}</strong>
          </div>
        </div>
      </AppShell>
    );
  }

  return (
    <AppShell
      step="1 / 2"
      title="Upload PDFs"
      subtitle="Choose black & white or color, then send the files to this kiosk."
      footer={
        <>
          {error ? <p className="banner error">{error}</p> : null}
          <button className="primary" type="button" disabled={busy || files.length === 0} onClick={() => void onUpload()}>
            {busy ? 'Uploading…' : files.length ? `Send ${files.length} file${files.length === 1 ? '' : 's'} to kiosk` : 'Send to kiosk'}
          </button>
        </>
      }
    >
      <div className="card limits">
        <div className="limit-row">
          <span>Free pages</span>
          <strong>
            {freePages} {colorMode === 'color' ? 'color' : 'B/W'}
          </strong>
        </div>
        <div className="limit-row">
          <span>Extra pages</span>
          <strong>₹{extraCharge} each</strong>
        </div>
        <div className="limit-row">
          <span>Session max</span>
          <strong>{session.printLimits.maxPagesPerSession} pages</strong>
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
          accept="application/pdf,.pdf"
          multiple
          onChange={(event) => addFiles(event.target.files)}
        />
        <strong>Tap to add PDFs</strong>
        <small>You can attach more than one file</small>
      </label>
      {files.length > 0 ? (
        <ul className="files">
          {files.map((file, index) => (
            <li className="file-chip" key={`${file.name}-${file.size}-${index}`}>
              <span className="file-thumb">PDF</span>
              <span className="file-meta">
                <strong>{file.name}</strong>
                <span>{formatBytes(file.size)}</span>
              </span>
              <button className="icon-btn" type="button" aria-label={`Remove ${file.name}`} onClick={() => removeFile(index)}>
                ×
              </button>
            </li>
          ))}
        </ul>
      ) : null}
    </AppShell>
  );
}

function HomePage() {
  return (
    <AppShell
      title="Scan the QR on the kiosk"
      subtitle="This page only works from a kiosk Quick Print code."
      status={<IconQr />}
    />
  );
}

export function App() {
  return (
    <Routes>
      <Route path="/" element={<HomePage />} />
      <Route path="/s/:token" element={<SessionPage />} />
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}
