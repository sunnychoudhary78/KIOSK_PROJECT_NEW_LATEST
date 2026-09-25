import { useEffect, useMemo, useState } from 'react';
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

function SessionPage() {
  const { token = '' } = useParams();
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
      <main className="page">
        <div className="brand">Smart Kiosk</div>
        <h1>Link unavailable</h1>
        <p className="error">{error}</p>
      </main>
    );
  }

  if (!session) {
    return (
      <main className="page">
        <div className="brand">Smart Kiosk</div>
        <h1>Opening print session…</h1>
      </main>
    );
  }

  if (step === 'chooser') {
    return (
      <main className="page">
        <div className="brand">Quick Print</div>
        <h1>Print from this kiosk</h1>
        <p>
          {session.deviceName
            ? `You are connected to ${session.deviceName}.`
            : 'You are connected to this kiosk.'}{' '}
          Continue here, or get the app if you print often.
        </p>
        <div className="stack">
          <button className="primary" type="button" onClick={() => setStep('upload')}>
            Continue in browser
          </button>
          <a className="button secondary" href={PLAY_STORE_URL}>
            Get the app
          </a>
        </div>
      </main>
    );
  }

  if (step === 'done') {
    return (
      <main className="page">
        <div className="brand">Quick Print</div>
        <h1>Look at the kiosk</h1>
        <p className="ok">Your documents are ready. Finish preview and print on the machine.</p>
        {session.documentLabel ? <div className="card">{session.documentLabel}</div> : null}
      </main>
    );
  }

  if (step === 'pay') {
    const quote = session.quote;
    return (
      <main className="page">
        <div className="brand">Quick Print</div>
        <h1>Pay extra pages</h1>
        <div className="card limits">
          <div>
            {quote
              ? `${quote.pageCount} pages · ${quote.extraPages} extra`
              : `${session.pageCount} pages`}
          </div>
          <strong>{quote ? formatMoney(quote.amountPaise) : 'Payment required'}</strong>
        </div>
        {error ? <p className="error">{error}</p> : null}
        <button className="primary" type="button" disabled={busy} onClick={() => void onPay()}>
          {busy ? 'Opening payment…' : error ? 'Pay again' : 'Pay now'}
        </button>
      </main>
    );
  }

  return (
    <main className="page">
      <div className="brand">Quick Print</div>
      <h1>Upload PDFs</h1>
      <div className="card limits">
        <div>This kiosk: {freePages} free {colorMode === 'color' ? 'color' : 'B/W'} pages</div>
        <div>Extra pages: ₹{extraCharge} each</div>
        <div>Max {session.printLimits.maxPagesPerSession} pages in one session</div>
      </div>
      <div className="row">
        <label>
          <input
            type="radio"
            name="color"
            checked={colorMode === 'bw'}
            onChange={() => setColorMode('bw')}
          />
          Black & white
        </label>
        <label>
          <input
            type="radio"
            name="color"
            checked={colorMode === 'color'}
            onChange={() => setColorMode('color')}
          />
          Color
        </label>
      </div>
      <input
        type="file"
        accept="application/pdf,.pdf"
        multiple
        onChange={(event) => setFiles(Array.from(event.target.files ?? []))}
      />
      {files.length > 0 ? (
        <ul className="files">
          {files.map((file) => (
            <li key={file.name}>{file.name}</li>
          ))}
        </ul>
      ) : null}
      {error ? <p className="error">{error}</p> : null}
      <button className="primary" type="button" disabled={busy || files.length === 0} onClick={() => void onUpload()}>
        {busy ? 'Uploading…' : 'Send to kiosk'}
      </button>
    </main>
  );
}

function HomePage() {
  return (
    <main className="page">
      <div className="brand">Quick Print</div>
      <h1>Scan the QR on the kiosk</h1>
      <p>This page only works from a kiosk Quick Print code.</p>
    </main>
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
