import 'package:flutter/material.dart';
import 'package:skp_mobile/core/theme/app_theme.dart';
import 'package:skp_mobile/features/otp_print/application/otp_print_models.dart';
import 'package:skp_mobile/l10n/app_localizations.dart';

(String, Color) challengeStatusStyle(AppLocalizations l10n, OtpChallenge challenge) {
  if (challenge.status == 'awaiting_payment' && !challenge.isExpired) {
    return (l10n.statusPayNow, const Color(0xFF8A6A12));
  }
  if (challenge.status == 'pending' && !challenge.isExpired) {
    return (l10n.statusOtpSent, SkpColors.accent);
  }
  if (challenge.status == 'redeemed') {
    final job = challenge.printJob?.status;
    if (job == 'completed') return (l10n.statusPrinted, SkpColors.success);
    if (job == 'failed') return (l10n.statusCancelled, SkpColors.danger);
    return (l10n.statusPrinted, SkpColors.success);
  }
  if (challenge.status == 'cancelled') {
    return (l10n.statusCancelled, SkpColors.muted);
  }
  return (l10n.statusExpired, SkpColors.muted);
}
