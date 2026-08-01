/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_SKP_API_BASE_URL: string;
  readonly VITE_SKP_APP_NAME: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
