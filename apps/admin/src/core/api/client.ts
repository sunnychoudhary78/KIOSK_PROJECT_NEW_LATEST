import { config } from '../config';
import { ApiError } from '../errors/api-error';

type RequestOptions = {
  method?: string;
  body?: unknown;
  token?: string | null;
  formData?: FormData;
};

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

export async function apiRequest<T>(path: string, options: RequestOptions = {}): Promise<T> {
  const headers: Record<string, string> = {
    'X-Correlation-Id': crypto.randomUUID(),
  };

  if (!options.formData) {
    headers['Content-Type'] = 'application/json';
  }

  if (options.token) {
    headers.Authorization = `Bearer ${options.token}`;
  }

  const response = await fetch(`${config.apiBaseUrl}${path}`, {
    method: options.method ?? (options.body || options.formData ? 'POST' : 'GET'),
    headers,
    body: options.formData
      ? options.formData
      : options.body
        ? JSON.stringify(options.body)
        : undefined,
  });

  if (!response.ok) {
    throw await parseError(response);
  }

  if (response.status === 204) {
    return undefined as T;
  }

  return (await response.json()) as T;
}
