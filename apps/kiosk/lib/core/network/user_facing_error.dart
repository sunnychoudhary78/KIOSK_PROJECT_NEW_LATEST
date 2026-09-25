import 'dart:async';
import 'dart:io';

import 'package:skp_kiosk/core/network/api_client.dart';

const _fallback = 'Something went wrong. Please try again.';
const _network = "Can't reach the server. Check the connection and try again.";

const _codeMessages = <String, String>{
  'amount_mismatch': 'Payment amount did not match. Please try again.',
  'device_inactive': 'This kiosk has been stopped.',
  'digilocker_download_failed': 'Could not download the DigiLocker document. Please try again.',
  'digilocker_eaadhaar_failed': 'Could not fetch Aadhaar from DigiLocker. Please try again.',
  'digilocker_insufficient_scope': 'DigiLocker did not share the needed documents. Try again and allow access.',
  'digilocker_list_failed': 'Could not load DigiLocker documents. Please try again.',
  'digilocker_list_uploaded_failed': 'Could not load DigiLocker documents. Please try again.',
  'digilocker_oauth_denied': 'DigiLocker sign-in was cancelled. Please try again.',
  'digilocker_token_exchange_failed': 'Could not connect to DigiLocker. Please try again.',
  'digilocker_token_invalid': 'Could not connect to DigiLocker. Please try again.',
  'digilocker_user_failed': 'Could not load DigiLocker account details. Please try again.',
  'forbidden': 'This action is not allowed.',
  'invalid_credentials': 'Device key or secret is incorrect.',
  'invalid_file_type': 'Only PDF files can be printed.',
  'invalid_pdf': 'That PDF could not be read. Try another file.',
  'invalid_phone': 'Enter a valid 10-digit mobile number.',
  'not_found': 'That item was not found. Please try again.',
  'otp_empty': 'No documents are linked to this OTP.',
  'otp_expired': 'This OTP has expired. Request a new one.',
  'otp_invalid': 'That OTP is invalid or already used.',
  'otp_locked': 'Too many attempts. Request a new OTP.',
  'otp_unavailable': 'Print OTP is not available right now.',
  'payload_missing': 'The document is not ready to print.',
  'payment_expired': 'Payment window has expired. Upload again.',
  'payment_required': 'Payment is not complete yet.',
  'payment_unavailable': 'Payment is not available for this print.',
  'phone_required': 'A mobile number is required to continue.',
  'request_failed': _fallback,
  'page_limit_exceeded': 'Too many pages for this kiosk. Remove some pages and try again.',
  'payments_not_configured': 'Paid printing is not available on this kiosk right now.',
  'session_cancelled': 'This print session was cancelled.',
  'session_expired': 'This print session has expired. Start again.',
  'session_not_accepting': 'This session already has documents.',
  'session_not_ready': 'Documents are not ready yet. Wait for the phone upload.',
  'service_disabled': 'This service is not available on this kiosk.',
  'service_unavailable': 'This service is not available right now.',
  'sms_failed': 'Could not send the SMS. Please try again.',
  'unauthorized': 'Session expired. Please try again.',
  'validation_error': 'Please check the details and try again.',
  'vedastro_failed': 'Could not prepare the reading. Please try again.',
};

/// Citizen-facing text for banners. Never returns `ApiException(...)`.
String userFacingError(Object error) {
  if (error is ApiException) {
    if (_isCitizenMessage(error.message)) {
      return error.message.trim();
    }
    return _codeMessages[error.code] ?? _fallback;
  }

  if (error is SocketException ||
      error is TimeoutException ||
      error is HttpException ||
      error is HandshakeException) {
    return _network;
  }

  if (error is StateError && _isCitizenMessage(error.message)) {
    return error.message;
  }

  final raw = error.toString();
  if (_looksLikeNetwork(raw)) {
    return _network;
  }
  return _fallback;
}

bool _isCitizenMessage(String message) {
  final trimmed = message.trim();
  if (trimmed.isEmpty || trimmed.length > 160) {
    return false;
  }
  if (trimmed.contains('Exception') ||
      trimmed.contains('Error:') ||
      trimmed.contains('\n') ||
      trimmed.contains(' at ')) {
    return false;
  }
  return trimmed.contains(' ');
}

bool _looksLikeNetwork(String raw) {
  final lower = raw.toLowerCase();
  return lower.contains('socketexception') ||
      lower.contains('clientexception') ||
      lower.contains('failed host lookup') ||
      lower.contains('connection refused') ||
      lower.contains('connection reset') ||
      lower.contains('timed out') ||
      lower.contains('timeout');
}
