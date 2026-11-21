import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/core/auth/device_auth.dart';
import 'package:skp_kiosk/core/network/api_client.dart';
import 'package:skp_kiosk/features/service_analytics/application/service_analytics_tracker.dart';
import 'package:skp_kiosk/features/service_analytics/domain/service_event_keys.dart';
import 'package:skp_kiosk/features/support/data/support_repository.dart';
import 'package:skp_kiosk/features/support/domain/support_category.dart';

final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  return SupportRepository(ref.watch(apiClientProvider));
});

enum SupportFormFocus { message, phone }

class SupportFormState {
  const SupportFormState({
    this.category = SupportCategory.other,
    this.message = '',
    this.phone = '',
    this.focus = SupportFormFocus.message,
    this.submitting = false,
    this.submitted = false,
    this.error,
  });

  final SupportCategory category;
  final String message;
  final String phone;
  final SupportFormFocus focus;
  final bool submitting;
  final bool submitted;
  final String? error;

  bool get canSubmit => !submitting && !submitted;

  SupportFormState copyWith({
    SupportCategory? category,
    String? message,
    String? phone,
    SupportFormFocus? focus,
    bool? submitting,
    bool? submitted,
    String? error,
    bool clearError = false,
  }) {
    return SupportFormState(
      category: category ?? this.category,
      message: message ?? this.message,
      phone: phone ?? this.phone,
      focus: focus ?? this.focus,
      submitting: submitting ?? this.submitting,
      submitted: submitted ?? this.submitted,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class SupportController extends Notifier<SupportFormState> {
  static const _messageMax = 500;
  static const _phoneMax = 10;

  @override
  SupportFormState build() => const SupportFormState();

  void selectCategory(SupportCategory category) {
    if (state.submitting || state.submitted) return;
    state = state.copyWith(category: category, clearError: true);
    // ignore: discarded_futures
    ref.read(serviceAnalyticsTrackerProvider).track(
          ServiceEventKeys.supportCategory(category.apiValue),
        );
  }

  void setFocus(SupportFormFocus focus) {
    if (state.submitting || state.submitted) return;
    state = state.copyWith(focus: focus);
  }

  void setPhone(String value) {
    if (state.submitting || state.submitted) return;
    final digits = value.replaceAll(RegExp(r'\D'), '');
    final clipped =
        digits.length > _phoneMax ? digits.substring(0, _phoneMax) : digits;
    state = state.copyWith(phone: clipped, clearError: true);
  }

  void typeKey(String value) {
    if (state.submitting || state.submitted) return;
    if (state.focus == SupportFormFocus.phone) {
      setPhone(state.phone + value);
      return;
    }
    if (state.message.length >= _messageMax) return;
    state = state.copyWith(
      message: state.message + value,
      clearError: true,
    );
  }

  void backspace() {
    if (state.submitting || state.submitted) return;
    if (state.focus == SupportFormFocus.phone) {
      if (state.phone.isEmpty) return;
      state = state.copyWith(
        phone: state.phone.substring(0, state.phone.length - 1),
        clearError: true,
      );
      return;
    }
    if (state.message.isEmpty) return;
    state = state.copyWith(
      message: state.message.substring(0, state.message.length - 1),
      clearError: true,
    );
  }

  String? _validate() {
    final message = state.message.trim();
    if (message.isEmpty) {
      return 'Please describe the issue.';
    }
    if (message.length > _messageMax) {
      return 'Message must be $_messageMax characters or fewer.';
    }

    final phone = state.phone.replaceAll(RegExp(r'\D'), '');
    if (phone.isEmpty) {
      return 'Phone number is required.';
    }
    if (phone.length != _phoneMax) {
      return 'Enter a valid 10-digit mobile number.';
    }
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
      return 'Enter a valid 10-digit mobile number.';
    }
    return null;
  }

  Future<void> submit() async {
    if (!state.canSubmit) return;

    final validationError = _validate();
    if (validationError != null) {
      final focus = state.message.trim().isEmpty
          ? SupportFormFocus.message
          : SupportFormFocus.phone;
      state = state.copyWith(error: validationError, focus: focus);
      return;
    }

    state = state.copyWith(submitting: true, clearError: true);
    try {
      await ref.read(supportRepositoryProvider).submit(
            category: state.category,
            message: state.message.trim(),
            phone: state.phone.replaceAll(RegExp(r'\D'), ''),
          );
      ref
          .read(serviceAnalyticsTrackerProvider)
          .track(ServiceEventKeys.supportSubmit);
      state = state.copyWith(submitting: false, submitted: true);
    } on ApiException catch (error) {
      state = state.copyWith(
        submitting: false,
        error: error.code == 'rate_limited'
            ? 'Please wait a few minutes before sending another message.'
            : error.code == 'invalid_phone'
                ? 'Enter a valid 10-digit mobile number.'
                : error.message,
      );
    } on SocketException {
      state = state.copyWith(
        submitting: false,
        error: 'You appear to be offline. Try again when connected.',
      );
    } catch (_) {
      state = state.copyWith(
        submitting: false,
        error: 'Could not send your message. Please try again.',
      );
    }
  }
}

final supportControllerProvider =
    NotifierProvider.autoDispose<SupportController, SupportFormState>(
  SupportController.new,
);
