const API_BASE = (import.meta.env.VITE_SKP_API_BASE_URL || 'http://localhost:3000/v1').replace(
  /\/$/,
  '',
);

export type PrintQuote = {
  printColorMode: 'bw' | 'color';
  pageCount: number;
  freePages: number;
  extraPages: number;
  chargePerPageRupees: number;
  amountPaise: number;
  currency: string;
  paymentRequired: boolean;
};

export type PrintLimits = {
  maxPagesPerSession: number;
  freePagesPerSession: number;
  extraPageChargeRupees: number;
  freeColorPagesPerSession: number;
  extraColorPageChargeRupees: number;
};

export type QuickPrintSession = {
  id: string;
  status: 'waiting_upload' | 'awaiting_payment' | 'ready' | 'consumed' | 'expired' | 'cancelled';
  expiresAt: string;
  documentLabel: string;
  pageCount: number;
  printColorMode: 'bw' | 'color';
  deviceName: string | null;
  paymentRequired: boolean;
  documents: Array<{ id: string; fileName: string; pageCount: number; byteSize: number }>;
  quote: PrintQuote | null;
  printLimits: PrintLimits;
};

export type RazorpayOrder = {
  alreadyPaid: boolean;
  sessionReady?: boolean;
  razorpay_order_id?: string;
  razorpay_key_id: string;
  payment: {
    amountPaise: number;
    currency: string;
  };
};

export class ApiError extends Error {
  constructor(
    public readonly code: string,
    message: string,
  ) {
    super(message);
    this.name = 'ApiError';
  }
}

async function parseError(response: Response): Promise<never> {
  let code = 'request_failed';
  let message = response.statusText || 'Request failed';
  try {
    const body = (await response.json()) as { code?: string; message?: string };
    code = body.code || code;
    message = body.message || message;
  } catch {
    // keep defaults
  }
  throw new ApiError(code, message);
}

export async function getSession(token: string): Promise<QuickPrintSession> {
  const response = await fetch(`${API_BASE}/quick-print/public/sessions/${encodeURIComponent(token)}`);
  if (!response.ok) {
    await parseError(response);
  }
  return (await response.json()) as QuickPrintSession;
}

export async function uploadDocuments(
  token: string,
  files: File[],
  printColorMode: 'bw' | 'color',
): Promise<QuickPrintSession> {
  const body = new FormData();
  body.set('printColorMode', printColorMode);
  for (const file of files) {
    body.append('files', file);
  }
  const response = await fetch(
    `${API_BASE}/quick-print/public/sessions/${encodeURIComponent(token)}/documents`,
    { method: 'POST', body },
  );
  if (!response.ok) {
    await parseError(response);
  }
  return (await response.json()) as QuickPrintSession;
}

export async function createOrder(token: string): Promise<RazorpayOrder> {
  const response = await fetch(
    `${API_BASE}/quick-print/public/sessions/${encodeURIComponent(token)}/razorpay/order`,
    { method: 'POST' },
  );
  if (!response.ok) {
    await parseError(response);
  }
  return (await response.json()) as RazorpayOrder;
}

export async function verifyPayment(
  token: string,
  input: {
    razorpay_order_id: string;
    razorpay_payment_id: string;
    razorpay_signature: string;
  },
): Promise<{ sessionReady?: boolean }> {
  const response = await fetch(
    `${API_BASE}/quick-print/public/sessions/${encodeURIComponent(token)}/razorpay/verify`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(input),
    },
  );
  if (!response.ok) {
    await parseError(response);
  }
  return (await response.json()) as { sessionReady?: boolean };
}

export function loadRazorpay(): Promise<void> {
  if (window.Razorpay) {
    return Promise.resolve();
  }
  return new Promise((resolve, reject) => {
    const existing = document.querySelector<HTMLScriptElement>('script[data-skp-razorpay]');
    if (existing) {
      existing.addEventListener('load', () => resolve());
      existing.addEventListener('error', () => reject(new Error('Could not load Razorpay')));
      return;
    }
    const script = document.createElement('script');
    script.src = 'https://checkout.razorpay.com/v1/checkout.js';
    script.async = true;
    script.dataset.skpRazorpay = '1';
    script.onload = () => resolve();
    script.onerror = () => reject(new Error('Could not load Razorpay'));
    document.body.appendChild(script);
  });
}
