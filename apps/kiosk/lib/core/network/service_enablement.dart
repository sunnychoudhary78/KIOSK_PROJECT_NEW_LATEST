import 'package:flutter/material.dart';
import 'package:skp_kiosk/app/router.dart';
import 'package:skp_kiosk/core/network/api_client.dart';
import 'package:skp_kiosk/features/home/presentation/under_maintenance_page.dart';

/// True when the API rejected the call because the service is off for this kiosk.
bool isServiceEnablementError(Object error) {
  if (error is! ApiException) {
    return false;
  }
  return error.code == 'service_disabled' || error.code == 'service_unavailable';
}

/// Replaces the current route with the shared Under maintenance screen.
void openUnderMaintenance(
  BuildContext context, {
  String? serviceTitle,
}) {
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute<void>(
      builder: (_) => UnderMaintenancePage(serviceTitle: serviceTitle),
    ),
    (route) => route.isFirst || route.settings.name == AppRoutes.home,
  );
}

/// Controllers call this (no BuildContext) when API enablement fails.
/// Opens [UnderMaintenancePage] and returns true when handled.
bool reportServiceEnablementBlocked(
  Object error, {
  String? serviceTitle,
}) {
  if (!isServiceEnablementError(error)) {
    return false;
  }
  final context = kioskNavigatorKey.currentContext;
  if (context != null) {
    openUnderMaintenance(context, serviceTitle: serviceTitle);
  }
  return true;
}
