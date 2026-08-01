import { createHash, randomBytes } from 'node:crypto';
import type { AppConfig } from '../../config/index.js';
import { AppError } from '../../shared/errors.js';
import type {
  DigiLockerClient,
  DigiLockerDocumentRef,
  DigiLockerFileDownload,
  DigiLockerPkcePair,
  DigiLockerSessionStart,
  DigiLockerTokenResult,
  DigiLockerUserDetails,
} from './digilocker.types.js';
import { EAADHAAR_SYNTHETIC_URI, eaadhaarXmlToPdf } from './digilocker.eaadhaar.js';
import type { Logger } from '../logging/logger.js';

function digiLockerErrorMessage(payload: Record<string, unknown>, fallback: string): string {
  if (typeof payload.error_description === 'string' && payload.error_description.length > 0) {
    return payload.error_description;
  }
  if (typeof payload.error === 'string' && payload.error.length > 0) {
    return payload.error;
  }
  return fallback;
}

function mapDigiLockerHttpError(
  response: Response,
  payload: Record<string, unknown>,
  fallbackCode: string,
  fallbackMessage: string,
): AppError {
  const digiCode = typeof payload.error === 'string' ? payload.error : undefined;
  const message = digiLockerErrorMessage(payload, fallbackMessage);

  if (response.status === 403 || digiCode === 'insufficient_scope') {
    return new AppError(
      'digilocker_insufficient_scope',
      fallbackMessage.includes('MeriPehchaan') || fallbackMessage.includes('partner')
        ? fallbackMessage
        : 'DigiLocker denied this API (insufficient_scope). Enable e-Aadhaar / Aadhaar privileges for this Client ID in the MeriPehchaan partner portal, then End session and sign in again.',
      403,
      { status: response.status, digiLockerError: digiCode, digiLockerMessage: message },
    );
  }

  return new AppError(fallbackCode, message, response.status >= 400 && response.status < 600 ? response.status : 502, {
    status: response.status,
    digiLockerError: digiCode,
  });
}

function base64Url(buffer: Buffer): string {
  return buffer
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/g, '');
}

function joinUrl(base: string, path: string): string {
  const normalizedBase = base.replace(/\/$/, '');
  const normalizedPath = path.startsWith('/') ? path : `/${path}`;
  return `${normalizedBase}${normalizedPath}`;
}

function extractMime(mime: unknown): string | undefined {
  if (typeof mime === 'string' && mime.length > 0) {
    return mime;
  }
  if (Array.isArray(mime)) {
    for (const entry of mime) {
      if (typeof entry === 'string' && entry.length > 0) {
        return entry;
      }
      if (entry && typeof entry === 'object') {
        const values = Object.keys(entry as Record<string, unknown>);
        if (values.length > 0) {
          return values[0];
        }
      }
    }
  }
  return undefined;
}

function extractItems(payload: Record<string, unknown>): unknown[] {
  if (Array.isArray(payload.items)) {
    return payload.items;
  }
  if (Array.isArray(payload.documents)) {
    return payload.documents;
  }
  if (Array.isArray(payload)) {
    return payload;
  }
  return [];
}

function mapDocumentItem(
  raw: unknown,
  source: 'issued' | 'uploaded',
): DigiLockerDocumentRef | null {
  const item = raw as Record<string, unknown>;
  const type = typeof item.type === 'string' ? item.type.toLowerCase() : undefined;
  if (type === 'dir') {
    return null;
  }
  const uri = String(item.uri ?? '').trim();
  if (!uri) {
    return null;
  }
  return {
    id: uri,
    uri,
    name: String(item.name ?? item.description ?? 'Document'),
    issuer: String(item.issuer ?? item.issuerid ?? (source === 'uploaded' ? 'Uploaded' : 'Unknown issuer')),
    mimeType: extractMime(item.mime),
    doctype: typeof item.doctype === 'string' ? item.doctype : undefined,
    description: typeof item.description === 'string' ? item.description : undefined,
    source,
  };
}

export function createDigiLockerClient(config: AppConfig, logger?: Logger): DigiLockerClient {
  const digi = config.digilocker;

  function createPkcePair(): DigiLockerPkcePair {
    const codeVerifier = base64Url(randomBytes(32));
    const codeChallenge = base64Url(createHash('sha256').update(codeVerifier).digest());
    return {
      codeVerifier,
      codeChallenge,
      codeChallengeMethod: 'S256',
    };
  }

  function buildAuthorizeUrl(input: {
    state: string;
    codeChallenge: string;
    redirectUri?: string;
    scope?: string;
  }): string {
    const url = new URL(joinUrl(digi.baseUrl, digi.authorizePath));
    url.searchParams.set('response_type', 'code');
    url.searchParams.set('client_id', digi.clientId);
    url.searchParams.set('redirect_uri', input.redirectUri ?? digi.redirectUri);
    url.searchParams.set('state', input.state);
    url.searchParams.set('code_challenge', input.codeChallenge);
    url.searchParams.set('code_challenge_method', 'S256');
    url.searchParams.set('scope', input.scope ?? digi.scope);
    return url.toString();
  }

  async function exchangeCode(input: {
    code: string;
    codeVerifier: string;
    redirectUri?: string;
  }): Promise<DigiLockerTokenResult> {
    const body = new URLSearchParams({
      code: input.code,
      grant_type: 'authorization_code',
      client_id: digi.clientId,
      client_secret: digi.clientSecret,
      redirect_uri: input.redirectUri ?? digi.redirectUri,
      code_verifier: input.codeVerifier,
    });

    const response = await fetch(joinUrl(digi.baseUrl, digi.tokenPath), {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        Accept: 'application/json',
      },
      body,
    });

    const payload = (await response.json().catch(() => ({}))) as Record<string, unknown>;
    if (!response.ok) {
      throw new AppError(
        'digilocker_token_exchange_failed',
        typeof payload.error_description === 'string'
          ? payload.error_description
          : 'DigiLocker token exchange failed',
        502,
        { status: response.status },
      );
    }

    const accessToken = payload.access_token;
    if (typeof accessToken !== 'string' || accessToken.length === 0) {
      throw new AppError('digilocker_token_invalid', 'DigiLocker token response missing access_token', 502);
    }

    return {
      accessToken,
      tokenType: typeof payload.token_type === 'string' ? payload.token_type : 'Bearer',
      expiresIn: typeof payload.expires_in === 'number' ? payload.expires_in : 3600,
      scope: typeof payload.scope === 'string' ? payload.scope : undefined,
      idToken: typeof payload.id_token === 'string' ? payload.id_token : undefined,
      consentValidTill:
        typeof payload.consent_valid_till === 'string' ? payload.consent_valid_till : undefined,
    };
  }

  async function listIssuedDocuments(accessToken: string): Promise<DigiLockerDocumentRef[]> {
    const response = await fetch(joinUrl(digi.baseUrl, digi.filesIssuedPath), {
      method: 'GET',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        Accept: 'application/json',
      },
    });

    const payload = (await response.json().catch(() => ({}))) as Record<string, unknown>;
    if (!response.ok) {
      throw new AppError(
        'digilocker_list_failed',
        'Failed to list DigiLocker issued documents',
        502,
        { status: response.status },
      );
    }

    logger?.info({ digiLockerIssuedRaw: payload }, 'DigiLocker issued documents raw response');

    const mapped: DigiLockerDocumentRef[] = [];
    for (const raw of extractItems(payload)) {
      const doc = mapDocumentItem(raw, 'issued');
      if (doc) {
        mapped.push(doc);
      }
    }
    return mapped;
  }

  async function listUploadedDocuments(accessToken: string): Promise<DigiLockerDocumentRef[]> {
    // Root uploaded folder: /public/oauth2/1/files/ (trailing slash omitted is OK)
    const response = await fetch(joinUrl(digi.baseUrl, digi.filesUploadedPath), {
      method: 'GET',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        Accept: 'application/json',
      },
    });

    const payload = (await response.json().catch(() => ({}))) as Record<string, unknown>;
    if (!response.ok) {
      // Uploaded list may be empty/unavailable depending on consent; don't fail the whole flow.
      if (response.status === 404 || response.status === 403 || response.status === 429) {
        logger?.warn(
          {
            status: response.status,
            digiLockerError: payload.error,
          },
          'DigiLocker uploaded list unavailable; continuing with issued documents only',
        );
        return [];
      }
      throw new AppError(
        'digilocker_list_uploaded_failed',
        digiLockerErrorMessage(payload, 'Failed to list DigiLocker uploaded documents'),
        502,
        { status: response.status },
      );
    }

    const mapped: DigiLockerDocumentRef[] = [];
    for (const raw of extractItems(payload)) {
      const doc = mapDocumentItem(raw, 'uploaded');
      if (doc) {
        mapped.push(doc);
      }
    }
    return mapped;
  }

  async function listAllDocuments(accessToken: string): Promise<DigiLockerDocumentRef[]> {
    const [issued, uploaded] = await Promise.all([
      listIssuedDocuments(accessToken),
      listUploadedDocuments(accessToken),
    ]);
    const byUri = new Map<string, DigiLockerDocumentRef>();
    for (const doc of [...issued, ...uploaded]) {
      if (!byUri.has(doc.uri)) {
        byUri.set(doc.uri, doc);
      }
    }

    logger?.info(
      {
        issuedCount: issued.length,
        uploadedCount: uploaded.length,
        issuedDoctypes: issued.map((d) => d.doctype ?? '(none)'),
      },
      'DigiLocker document list received',
    );

    return [...byUri.values()];
  }

  async function getUserDetails(accessToken: string): Promise<DigiLockerUserDetails> {
    const response = await fetch(joinUrl(digi.baseUrl, digi.userPath), {
      method: 'GET',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        Accept: 'application/json',
      },
    });
    const payload = (await response.json().catch(() => ({}))) as Record<string, unknown>;
    if (!response.ok) {
      throw new AppError('digilocker_user_failed', 'Failed to fetch DigiLocker user details', 502, {
        status: response.status,
      });
    }
    return {
      digilockerId: typeof payload.digilockerid === 'string' ? payload.digilockerid : undefined,
      name: typeof payload.name === 'string' ? payload.name : undefined,
      dob: typeof payload.dob === 'string' ? payload.dob : undefined,
      gender: typeof payload.gender === 'string' ? payload.gender : undefined,
      eaadhaar: typeof payload.eaadhaar === 'string' ? payload.eaadhaar : undefined,
    };
  }

  async function downloadEaadhaarXml(accessToken: string): Promise<string> {
    const response = await fetch(joinUrl(digi.baseUrl, digi.eaadhaarPath), {
      method: 'GET',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        Accept: 'application/xml, text/xml, */*',
      },
    });
    if (!response.ok) {
      const contentType = response.headers.get('content-type') ?? '';
      let payload: Record<string, unknown> = {};
      if (contentType.includes('json')) {
        payload = (await response.json().catch(() => ({}))) as Record<string, unknown>;
      } else {
        const text = await response.text().catch(() => '');
        try {
          payload = JSON.parse(text) as Record<string, unknown>;
        } catch {
          payload = text ? { error_description: text.slice(0, 300) } : {};
        }
      }
      throw mapDigiLockerHttpError(
        response,
        payload,
        'digilocker_eaadhaar_failed',
        'e-Aadhaar API not enabled for this DigiLocker partner Client ID. Enable e-Aadhaar / Aadhaar privileges in the MeriPehchaan portal, then End session and sign in again.',
      );
    }
    return response.text();
  }

  async function downloadFile(accessToken: string, uri: string): Promise<DigiLockerFileDownload> {
    if (uri === EAADHAAR_SYNTHETIC_URI) {
      const xml = await downloadEaadhaarXml(accessToken);
      return {
        bytes: eaadhaarXmlToPdf(xml),
        contentType: 'application/pdf',
        fileName: 'eaadhaar.pdf',
      };
    }

    const encodedUri = encodeURIComponent(uri);
    const url = `${joinUrl(digi.baseUrl, digi.filePathPrefix)}/${encodedUri}`;
    const response = await fetch(url, {
      method: 'GET',
      headers: {
        Authorization: `Bearer ${accessToken}`,
      },
    });

    if (!response.ok) {
      const contentType = response.headers.get('content-type') ?? '';
      let payload: Record<string, unknown> = {};
      if (contentType.includes('json')) {
        payload = (await response.json().catch(() => ({}))) as Record<string, unknown>;
      } else {
        const text = await response.text().catch(() => '');
        try {
          payload = JSON.parse(text) as Record<string, unknown>;
        } catch {
          payload = text ? { error_description: text.slice(0, 300) } : {};
        }
      }
      throw mapDigiLockerHttpError(
        response,
        payload,
        'digilocker_download_failed',
        'Failed to download DigiLocker document',
      );
    }

    const arrayBuffer = await response.arrayBuffer();
    const contentType = response.headers.get('content-type') ?? 'application/pdf';
    const disposition = response.headers.get('content-disposition') ?? '';
    const match = /filename="?([^";]+)"?/i.exec(disposition);

    return {
      bytes: Buffer.from(arrayBuffer),
      contentType,
      fileName: match?.[1],
    };
  }

  return {
    createPkcePair,
    buildAuthorizeUrl,
    exchangeCode,
    listIssuedDocuments,
    listUploadedDocuments,
    listAllDocuments,
    getUserDetails,
    downloadEaadhaarXml,
    downloadFile,
  };
}

/** Helper used by session service when starting OAuth. */
export function startDigiLockerAuthorization(
  client: DigiLockerClient,
  input?: { redirectUri?: string; scope?: string },
): DigiLockerSessionStart & { codeChallenge: string } {
  const pkce = client.createPkcePair();
  const state = base64Url(randomBytes(24));
  const authorizationUrl = client.buildAuthorizeUrl({
    state,
    codeChallenge: pkce.codeChallenge,
    redirectUri: input?.redirectUri,
    scope: input?.scope,
  });
  return {
    authorizationUrl,
    state,
    codeVerifier: pkce.codeVerifier,
    codeChallenge: pkce.codeChallenge,
    expiresInSeconds: 600,
  };
}
