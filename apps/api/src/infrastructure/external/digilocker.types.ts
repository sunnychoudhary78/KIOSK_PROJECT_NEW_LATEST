export type DigiLockerPkcePair = {
  codeVerifier: string;
  codeChallenge: string;
  codeChallengeMethod: 'S256';
};

export type DigiLockerSessionStart = {
  authorizationUrl: string;
  state: string;
  codeVerifier: string;
  expiresInSeconds: number;
};

export type DigiLockerTokenResult = {
  accessToken: string;
  tokenType: string;
  expiresIn: number;
  scope?: string;
  idToken?: string;
  consentValidTill?: string;
};

export type DigiLockerDocumentSource = 'issued' | 'uploaded' | 'eaadhaar';

export type DigiLockerDocumentRef = {
  id: string;
  name: string;
  issuer: string;
  mimeType?: string;
  doctype?: string;
  description?: string;
  uri: string;
  source: DigiLockerDocumentSource;
};

export type DigiLockerUserDetails = {
  digilockerId?: string;
  name?: string;
  dob?: string;
  gender?: string;
  eaadhaar?: string;
};

export type DigiLockerFileDownload = {
  bytes: Buffer;
  contentType: string;
  fileName?: string;
};

export interface DigiLockerClient {
  createPkcePair(): DigiLockerPkcePair;
  buildAuthorizeUrl(input: {
    state: string;
    codeChallenge: string;
    redirectUri?: string;
    scope?: string;
  }): string;
  exchangeCode(input: {
    code: string;
    codeVerifier: string;
    redirectUri?: string;
  }): Promise<DigiLockerTokenResult>;
  listIssuedDocuments(accessToken: string): Promise<DigiLockerDocumentRef[]>;
  listUploadedDocuments(accessToken: string): Promise<DigiLockerDocumentRef[]>;
  listAllDocuments(accessToken: string): Promise<DigiLockerDocumentRef[]>;
  getUserDetails(accessToken: string): Promise<DigiLockerUserDetails>;
  downloadEaadhaarXml(accessToken: string): Promise<string>;
  downloadFile(accessToken: string, uri: string): Promise<DigiLockerFileDownload>;
}
