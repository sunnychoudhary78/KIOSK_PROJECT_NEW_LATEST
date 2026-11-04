import 'package:flutter/widgets.dart';

/// Emits service analytics when named routes are pushed.
class ServiceAnalyticsRouteObserver extends NavigatorObserver {
  ServiceAnalyticsRouteObserver({required this.onRoute});

  final void Function(RouteSettings settings) onRoute;

  void _maybeTrack(Route<dynamic>? route) {
    final settings = route?.settings;
    if (settings == null) {
      return;
    }
    onRoute(settings);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _maybeTrack(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _maybeTrack(newRoute);
  }
}
