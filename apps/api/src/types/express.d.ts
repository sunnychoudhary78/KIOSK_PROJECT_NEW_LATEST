import type { AuthPrincipal } from './auth.js';

declare global {
  namespace Express {
    interface Request {
      correlationId?: string;
      principal?: AuthPrincipal;
    }
  }
}

export {};
