export const SMS_CONFIG_KEY = 'sms_config';
export const OTP_PRINT_CONFIG_KEY = 'otp_print_config';
export const CITIZEN_AUTH_CONFIG_KEY = 'citizen_auth_config';

export type SmsConfig = {
  provider: 'msg91';
  enabled: boolean;
  auth_key: string;
  sender_id: string;
  flow_id: string;
  otp_var_name: string;
  message_template: string;
};

export type OtpPrintConfig = {
  ttlSeconds: number;
  otpLength: number;
  maxPagesPerSession: number;
  maxDocumentsPerSession: number;
  maxVerifyAttempts: number;
  maxFileSizeMb: number;
};

export type CitizenAuthConfig = {
  ttlSeconds: number;
  otpLength: number;
  maxVerifyAttempts: number;
  requestCooldownSeconds: number;
};

export const DEFAULT_SMS_CONFIG: SmsConfig = {
  provider: 'msg91',
  enabled: false,
  auth_key: '',
  sender_id: '',
  flow_id: '',
  otp_var_name: 'OTP',
  message_template:
    'Your OTP for Smart Kiosk is --. Valid for 30 minutes. Do not share this code.',
};

export const DEFAULT_OTP_PRINT_CONFIG: OtpPrintConfig = {
  ttlSeconds: 1800,
  otpLength: 6,
  maxPagesPerSession: 10,
  maxDocumentsPerSession: 5,
  maxVerifyAttempts: 5,
  maxFileSizeMb: 15,
};

export const DEFAULT_CITIZEN_AUTH_CONFIG: CitizenAuthConfig = {
  ttlSeconds: 300,
  otpLength: 6,
  maxVerifyAttempts: 5,
  requestCooldownSeconds: 60,
};
