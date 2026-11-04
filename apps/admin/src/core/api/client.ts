import { config } from '../config';
import {
  clearAccessToken,
  clearRefreshToken,
  getAccessToken,
  getRefreshToken,
  setAccessToken,
  setRefreshToken,
} from '../auth/session';
import { ApiError } from '../errors/api-error';

type RequestOptions = {
  method?: string;
  body?: unknown;
  token?: string | null;
  formData?: FormData;
};

type RefreshResponse = {
  accessToken: string;
  refreshToken: string;
};

const refreshSkewSeconds = 60;

type AccessTokenListener = (token: string | null) => void;

let accessTokenListener: AccessTokenListener | null = null;
let refreshInFlight: Promise<string | null> | null = null;

export function setAccessTokenListener(listener: AccessTokenListener | null): void {
  accessTokenListener = listener;
}

function notifyAccessToken(token: string | null): void {
  accessTokenListener?.(token);
}

function accessTokenExpiresWithin(token: string, seconds: number): boolean {
  const segment = token.split('.')[1];
  if (!segment) return false;
  try {
    const payload = JSON.parse(atob(segment.replace(/-/g, '+').replace(/_/g, '/'))) as { exp?: unknown };
    if (typeof payload.exp !== 'number') return false;
    return payload.exp * 1000 <= Date.now() + seconds * 1000;
  } catch {
    return false;
  }
}

function expireSession(): void {
  clearAccessToken();
  clearRefreshToken();
  notifyAccessToken(null);
  if (window.location.pathname !== '/login') {
    window.location.assign('/login?reason=expired');
  }
}

async function refreshAccessToken(): Promise<string | null> {
  if (!refreshInFlight) {
    refreshInFlight = requestRefresh().finally(() => {
      refreshInFlight = null;
    });
  }
  return refreshInFlight;
}

async function requestRefresh(): Promise<string | null> {
  const refreshToken = getRefreshToken();
  if (!refreshToken) return null;

  try {
    const response = await fetch(`${config.apiBaseUrl}/auth/admin/refresh`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Correlation-Id': crypto.randomUUID(),
      },
      body: JSON.stringify({ refreshToken }),
    });
    if (!response.ok) return null;
    const body = (await response.json()) as Partial<RefreshResponse>;
    if (!body.accessToken || !body.refreshToken) return null;
    setAccessToken(body.accessToken);
    setRefreshToken(body.refreshToken);
    notifyAccessToken(body.accessToken);
    return body.accessToken;
  } catch {
    return null;
  }
}

async function refreshOrExpire(): Promise<string> {
  const next = await refreshAccessToken();
  if (!next) {
    expireSession();
    throw new ApiError('unauthorized', 'Your session expired. Sign in again.');
  }
  return next;
}

async function parseError(response: Response): Promise<ApiError> {
  let code = 'request_failed';
  let message = response.statusText;
  let correlationId: string | undefined;
  try {
    const payload = (await response.json()) as {
      code?: string;
      message?: string;
      correlationId?: string;
    };
    code = payload.code ?? code;
    message = payload.message ?? message;
    correlationId = payload.correlationId;
  } catch {
    // ignore parse errors
  }
  return new ApiError(code, message, correlationId);
}

async function send(path: string, options: RequestOptions, token: string | null): Promise<Response> {
  const headers: Record<string, string> = {
    'X-Correlation-Id': crypto.randomUUID(),
  };

  if (!options.formData) {
    headers['Content-Type'] = 'application/json';
  }

  if (token) {
    headers.Authorization = `Bearer ${token}`;
  }

  return fetch(`${config.apiBaseUrl}${path}`, {
    method: options.method ?? (options.body || options.formData ? 'POST' : 'GET'),
    headers,
    body: options.formData ? options.formData : options.body ? JSON.stringify(options.body) : undefined,
  });
}

async function parseSuccess<T>(response: Response): Promise<T> {
  if (response.status === 204) {
    return undefined as T;
  }
  return (await response.json()) as T;
}

export async function apiRequest<T>(path: string, options: RequestOptions = {}): Promise<T> {
  let token = options.token ? (getAccessToken() ?? options.token) : null;
  if (token && accessTokenExpiresWithin(token, refreshSkewSeconds)) {
    token = await refreshOrExpire();
  }

  let response = await send(path, options, token);
  if (!response.ok && response.status === 401 && options.token) {
    const error = await parseError(response);
    if (error.code === 'unauthorized') {
      token = await refreshOrExpire();
      response = await send(path, options, token);
    } else {
      throw error;
    }
  }

  if (!response.ok) {
    throw await parseError(response);
  }

  return parseSuccess<T>(response);
}

export type UploadProgress = {
  loaded: number;
  total: number;
  percent: number | null;
};

type UploadFormDataOptions = {
  formData: FormData;
  token?: string | null;
  method?: string;
  onProgress?: (progress: UploadProgress) => void;
};

function parseXhrError(xhr: XMLHttpRequest): ApiError {
  let code = 'request_failed';
  let message = xhr.statusText || 'Upload failed';
  let correlationId: string | undefined;
  try {
    const payload = JSON.parse(xhr.responseText) as {
      code?: string;
      message?: string;
      correlationId?: string;
    };
    code = payload.code ?? code;
    message = payload.message ?? message;
    correlationId = payload.correlationId;
  } catch {
    // ignore parse errors
  }
  return new ApiError(code, message, correlationId);
}

function sendFormDataXhr<T>(
  path: string,
  formData: FormData,
  token: string | null,
  onProgress?: (progress: UploadProgress) => void,
  method = 'POST',
): Promise<{ status: number; body: T | undefined; unauthorized: boolean }> {
  return new Promise((resolve, reject) => {
    const xhr = new XMLHttpRequest();
    xhr.open(method, `${config.apiBaseUrl}${path}`);
    xhr.setRequestHeader('X-Correlation-Id', crypto.randomUUID());
    if (token) {
      xhr.setRequestHeader('Authorization', `Bearer ${token}`);
    }

    xhr.upload.onprogress = (event) => {
      if (!onProgress) return;
      if (event.lengthComputable && event.total > 0) {
        onProgress({
          loaded: event.loaded,
          total: event.total,
          percent: Math.min(100, Math.round((event.loaded / event.total) * 100)),
        });
      } else {
        onProgress({ loaded: event.loaded, total: 0, percent: null });
      }
    };

    xhr.onload = () => {
      const unauthorized =
        xhr.status === 401 &&
        (() => {
          try {
            const payload = JSON.parse(xhr.responseText) as { code?: string };
            return payload.code === 'unauthorized';
          } catch {
            return true;
          }
        })();

      if (xhr.status >= 200 && xhr.status < 300) {
        if (xhr.status === 204 || !xhr.responseText) {
          resolve({ status: xhr.status, body: undefined, unauthorized: false });
          return;
        }
        try {
          resolve({
            status: xhr.status,
            body: JSON.parse(xhr.responseText) as T,
            unauthorized: false,
          });
        } catch {
          reject(new ApiError('request_failed', 'Invalid JSON response'));
        }
        return;
      }

      if (unauthorized) {
        resolve({ status: xhr.status, body: undefined, unauthorized: true });
        return;
      }

      reject(parseXhrError(xhr));
    };

    xhr.onerror = () => {
      reject(new ApiError('request_failed', 'Network error during upload'));
    };

    xhr.onabort = () => {
      reject(new ApiError('request_failed', 'Upload aborted'));
    };

    xhr.send(formData);
  });
}

/** Multipart upload with progress. Prefer this over apiRequest for large FormData bodies. */
export async function apiUploadFormData<T>(
  path: string,
  options: UploadFormDataOptions,
): Promise<T> {
  let token = options.token ? (getAccessToken() ?? options.token) : null;
  if (token && accessTokenExpiresWithin(token, refreshSkewSeconds)) {
    token = await refreshOrExpire();
  }

  let result = await sendFormDataXhr<T>(
    path,
    options.formData,
    token,
    options.onProgress,
    options.method ?? 'POST',
  );

  if (result.unauthorized && options.token) {
    token = await refreshOrExpire();
    result = await sendFormDataXhr<T>(
      path,
      options.formData,
      token,
      options.onProgress,
      options.method ?? 'POST',
    );
  }

  if (result.unauthorized) {
    throw new ApiError('unauthorized', 'Your session expired. Sign in again.');
  }

  return result.body as T;
}
