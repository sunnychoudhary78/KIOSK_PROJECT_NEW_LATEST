export const SMS_CONFIG_KEY = 'sms_config';
export const OTP_PRINT_CONFIG_KEY = 'otp_print_config';
export const QUICK_PRINT_CONFIG_KEY = 'quick_print_config';
export const CITIZEN_AUTH_CONFIG_KEY = 'citizen_auth_config';

export type OtpPrintConfig = {
  ttlSeconds: number;
  otpLength: number;
  maxDocumentsPerSession: number;
  maxVerifyAttempts: number;
  maxFileSizeMb: number;
};

export type QuickPrintConfig = {
  ttlSeconds: number;
};

export type CitizenAuthConfig = {
  ttlSeconds: number;
  otpLength: number;
  maxVerifyAttempts: number;
  requestCooldownSeconds: number;
};

export const DEFAULT_OTP_PRINT_CONFIG: OtpPrintConfig = {
  ttlSeconds: 1800,
  otpLength: 6,
  maxDocumentsPerSession: 5,
  maxVerifyAttempts: 5,
  maxFileSizeMb: 15,
};

export const DEFAULT_QUICK_PRINT_CONFIG: QuickPrintConfig = {
  ttlSeconds: 600,
};

export const DEFAULT_CITIZEN_AUTH_CONFIG: CitizenAuthConfig = {
  ttlSeconds: 300,
  otpLength: 6,
  maxVerifyAttempts: 5,
  requestCooldownSeconds: 60,
};
