/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_SKP_API_BASE_URL: string;
  readonly VITE_PLAY_STORE_URL: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}

interface RazorpaySuccessResponse {
  razorpay_payment_id: string;
  razorpay_order_id: string;
  razorpay_signature: string;
}

interface RazorpayOptions {
  key: string;
  amount: number;
  currency: string;
  name: string;
  description: string;
  order_id: string;
  handler: (response: RazorpaySuccessResponse) => void;
  modal?: { ondismiss?: () => void };
}

interface RazorpayInstance {
  open(): void;
}

interface Window {
  Razorpay: new (options: RazorpayOptions) => RazorpayInstance;
}
