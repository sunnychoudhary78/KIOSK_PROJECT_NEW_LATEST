export const SMS_CONFIG_KEY = 'sms_config';
export const OTP_PRINT_CONFIG_KEY = 'otp_print_config';
export const CITIZEN_AUTH_CONFIG_KEY = 'citizen_auth_config';

export type OtpPrintConfig = {
  ttlSeconds: number;
  otpLength: number;
  maxPagesPerSession: number;
  maxDocumentsPerSession: number;
  maxVerifyAttempts: number;
  maxFileSizeMb: number;
  /** B/W pages included at no charge per OTP print session. */
  freePagesPerSession: number;
  /** Rupees charged for each B/W page above the free allowance. */
  extraPageChargeRupees: number;
  /** Color pages included at no charge per OTP print session. */
  freeColorPagesPerSession: number;
  /** Rupees charged for each color page above the free allowance. */
  extraColorPageChargeRupees: number;
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
  maxPagesPerSession: 10,
  maxDocumentsPerSession: 5,
  maxVerifyAttempts: 5,
  maxFileSizeMb: 15,
  freePagesPerSession: 5,
  extraPageChargeRupees: 10,
  freeColorPagesPerSession: 0,
  extraColorPageChargeRupees: 20,
};

export const DEFAULT_CITIZEN_AUTH_CONFIG: CitizenAuthConfig = {
  ttlSeconds: 300,
  otpLength: 6,
  maxVerifyAttempts: 5,
  requestCooldownSeconds: 60,
};
