import { z } from 'zod';

const envSchema = z.object({
  SKP_NODE_ENV: z.enum(['local', 'dev', 'staging', 'prod', 'test']).default('local'),
  SKP_PORT: z.coerce.number().int().positive().default(3000),
  SKP_LOG_LEVEL: z.enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace']).default('info'),
  SKP_DATABASE_URL: z.string().min(1),
  SKP_JWT_SECRET: z.string().min(32),
  SKP_JWT_ACCESS_TTL_SECONDS: z.coerce.number().int().positive().default(3600),
  SKP_CORS_ORIGINS: z.string().default('http://localhost:5173'),
  SKP_OTP_TTL_SECONDS: z.coerce.number().int().positive().default(300),
  SKP_OTP_LENGTH: z.coerce.number().int().min(4).max(8).default(6),
  SKP_RATE_LIMIT_WINDOW_MS: z.coerce.number().int().positive().default(60_000),
  SKP_RATE_LIMIT_MAX: z.coerce.number().int().positive().default(120),
  SKP_DIGILOCKER_BASE_URL: z.string().url(),
  SKP_DIGILOCKER_CLIENT_ID: z.string().min(1),
  SKP_DIGILOCKER_CLIENT_SECRET: z.string().min(1),
  SKP_DIGILOCKER_REDIRECT_URI: z.string().url(),
  SKP_DIGILOCKER_AUTHORIZE_PATH: z.string().default('/public/oauth2/1/authorize'),
  SKP_DIGILOCKER_TOKEN_PATH: z.string().default('/public/oauth2/2/token'),
  SKP_DIGILOCKER_FILES_ISSUED_PATH: z.string().default('/public/oauth2/2/files/issued'),
  SKP_DIGILOCKER_FILES_UPLOADED_PATH: z.string().default('/public/oauth2/1/files'),
  SKP_DIGILOCKER_FILE_PATH_PREFIX: z.string().default('/public/oauth2/1/file'),
  SKP_DIGILOCKER_USER_PATH: z.string().default('/public/oauth2/1/user'),
  SKP_DIGILOCKER_EAADHAAR_PATH: z.string().default('/public/oauth2/3/xml/eaadhaar'),
  SKP_DIGILOCKER_SCOPE: z.string().default('openid'),
  SKP_SMS_PROVIDER: z.enum(['noop', 'msg91']).default('noop'),
  SKP_MSG91_AUTH_KEY: z.string().default(''),
  SKP_MSG91_SENDER_ID: z.string().default(''),
  SKP_MSG91_FLOW_ID: z.string().default(''),
  /** MSG91 Flow shortcode for OTP (must match ##name## in the Flow template). */
  SKP_MSG91_OTP_VAR: z.string().default('var1'),
  /** MSG91 Flow shortcode for expiry text (must match ##name## in the Flow template). */
  SKP_MSG91_EXPIRY_VAR: z.string().default('var2'),
  SKP_RAZORPAY_KEY_ID: z.string().optional().default(''),
  SKP_RAZORPAY_KEY_SECRET: z.string().optional().default(''),
  SKP_RAZORPAY_WEBHOOK_SECRET: z.string().optional().default(''),
  SKP_PAYMENT_WINDOW_MINUTES: z.coerce.number().int().positive().default(15),
  SKP_VEDASTRO_BASE_URL: z.string().url().default('https://api.vedastro.org/api'),
  SKP_AI_PROVIDER: z.enum(['openai', 'noop']).default('noop'),
  SKP_OPENAI_API_KEY: z.string().optional().default(''),
  SKP_OPENAI_MODEL: z.string().min(1).default('gpt-4o'),
});

export type AppConfig = {
  env: z.infer<typeof envSchema>['SKP_NODE_ENV'];
  port: number;
  logLevel: z.infer<typeof envSchema>['SKP_LOG_LEVEL'];
  databaseUrl: string;
  auth: {
    jwtSecret: string;
    accessTtlSeconds: number;
  };
  corsOrigins: string[];
  otp: {
    ttlSeconds: number;
    length: number;
  };
  rateLimit: {
    windowMs: number;
    max: number;
  };
  digilocker: {
    baseUrl: string;
    clientId: string;
    clientSecret: string;
    redirectUri: string;
    authorizePath: string;
    tokenPath: string;
    filesIssuedPath: string;
    filesUploadedPath: string;
    filePathPrefix: string;
    userPath: string;
    eaadhaarPath: string;
    scope: string;
  };
  smsProvider: z.infer<typeof envSchema>['SKP_SMS_PROVIDER'];
  msg91: {
    authKey: string;
    senderId: string;
    flowId: string;
    otpVar: string;
    expiryVar: string;
  };
  razorpay: {
    keyId: string;
    keySecret: string;
    webhookSecret: string;
  };
  payments: {
    windowMinutes: number;
  };
  vedastro: {
    baseUrl: string;
  };
  aiProvider: z.infer<typeof envSchema>['SKP_AI_PROVIDER'];
  openai: {
    apiKey: string;
    model: string;
  };
};

let cached: Readonly<AppConfig> | undefined;

export function loadConfig(env: NodeJS.ProcessEnv = process.env): Readonly<AppConfig> {
  if (cached && env === process.env) {
    return cached;
  }

  // Prefer SKP_* DigiLocker vars; fall back to legacy MERIPEHCHAAN_* if present.
  const normalized: NodeJS.ProcessEnv = {
    ...env,
    SKP_DIGILOCKER_CLIENT_ID: env.SKP_DIGILOCKER_CLIENT_ID ?? env.MERIPEHCHAAN_CLIENT_ID,
    SKP_DIGILOCKER_CLIENT_SECRET: env.SKP_DIGILOCKER_CLIENT_SECRET ?? env.MERIPEHCHAAN_CLIENT_SECRET,
    SKP_DIGILOCKER_REDIRECT_URI: env.SKP_DIGILOCKER_REDIRECT_URI ?? env.MERIPEHCHAAN_REDIRECT_URI,
  };

  const parsed = envSchema.safeParse(normalized);
  if (!parsed.success) {
    const details = parsed.error.issues.map((i) => `${i.path.join('.')}: ${i.message}`).join('; ');
    throw new Error(`Invalid configuration: ${details}`);
  }

  const data = parsed.data;
  const config: AppConfig = {
    env: data.SKP_NODE_ENV,
    port: data.SKP_PORT,
    logLevel: data.SKP_LOG_LEVEL,
    databaseUrl: data.SKP_DATABASE_URL,
    auth: {
      jwtSecret: data.SKP_JWT_SECRET,
      accessTtlSeconds: data.SKP_JWT_ACCESS_TTL_SECONDS,
    },
    corsOrigins: data.SKP_CORS_ORIGINS.split(',').map((o) => o.trim()).filter(Boolean),
    otp: {
      ttlSeconds: data.SKP_OTP_TTL_SECONDS,
      length: data.SKP_OTP_LENGTH,
    },
    rateLimit: {
      windowMs: data.SKP_RATE_LIMIT_WINDOW_MS,
      max: data.SKP_RATE_LIMIT_MAX,
    },
    digilocker: {
      baseUrl: data.SKP_DIGILOCKER_BASE_URL.replace(/\/$/, ''),
      clientId: data.SKP_DIGILOCKER_CLIENT_ID,
      clientSecret: data.SKP_DIGILOCKER_CLIENT_SECRET,
      redirectUri: data.SKP_DIGILOCKER_REDIRECT_URI,
      authorizePath: data.SKP_DIGILOCKER_AUTHORIZE_PATH,
      tokenPath: data.SKP_DIGILOCKER_TOKEN_PATH,
      filesIssuedPath: data.SKP_DIGILOCKER_FILES_ISSUED_PATH,
      filesUploadedPath: data.SKP_DIGILOCKER_FILES_UPLOADED_PATH,
      filePathPrefix: data.SKP_DIGILOCKER_FILE_PATH_PREFIX,
      userPath: data.SKP_DIGILOCKER_USER_PATH,
      eaadhaarPath: data.SKP_DIGILOCKER_EAADHAAR_PATH,
      scope: data.SKP_DIGILOCKER_SCOPE,
    },
    smsProvider: data.SKP_SMS_PROVIDER,
    msg91: {
      authKey: data.SKP_MSG91_AUTH_KEY.trim(),
      senderId: data.SKP_MSG91_SENDER_ID.trim(),
      flowId: data.SKP_MSG91_FLOW_ID.trim(),
      otpVar: data.SKP_MSG91_OTP_VAR.trim() || 'var1',
      expiryVar: data.SKP_MSG91_EXPIRY_VAR.trim() || 'var2',
    },
    razorpay: {
      keyId: data.SKP_RAZORPAY_KEY_ID.trim(),
      keySecret: data.SKP_RAZORPAY_KEY_SECRET.trim(),
      webhookSecret: data.SKP_RAZORPAY_WEBHOOK_SECRET.trim(),
    },
    payments: {
      windowMinutes: data.SKP_PAYMENT_WINDOW_MINUTES,
    },
    vedastro: {
      baseUrl: data.SKP_VEDASTRO_BASE_URL.replace(/\/$/, ''),
    },
    aiProvider: data.SKP_AI_PROVIDER,
    openai: {
      apiKey: data.SKP_OPENAI_API_KEY.trim(),
      model: data.SKP_OPENAI_MODEL.trim() || 'gpt-4o',
    },
  };

  cached = Object.freeze(config);
  return cached;
}

export function resetConfigCache(): void {
  cached = undefined;
}
