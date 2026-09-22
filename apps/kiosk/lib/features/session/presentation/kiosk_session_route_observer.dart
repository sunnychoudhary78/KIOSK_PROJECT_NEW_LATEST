import 'package:flutter/material.dart';

class KioskSessionRouteObserver extends NavigatorObserver {
  KioskSessionRouteObserver({required this.onHomeChanged});

  final void Function(bool onHome) onHomeChanged;

  void _emit() {
    final nav = navigator;
    if (nav == null) {
      return;
    }
    onHomeChanged(!nav.canPop());
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _emit();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _emit();

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _emit();

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _emit();
}
