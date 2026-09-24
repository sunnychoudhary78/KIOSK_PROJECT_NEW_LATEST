import 'dart:async';

import 'package:flutter/material.dart';
import 'package:skp_kiosk/core/config/app_config.dart';
import 'package:webview_windows/webview_windows.dart';

/// In-app WebView2 pane for MeriPehchaan DigiLocker authorization.
class DigilockerAuthWebView extends StatefulWidget {
  const DigilockerAuthWebView({
    super.key,
    required this.authorizationUrl,
    required this.onCallbackReached,
    this.onError,
    this.onActivity,
  });

  final String authorizationUrl;
  final VoidCallback onCallbackReached;
  final ValueChanged<String>? onError;
  final VoidCallback? onActivity;

  @override
  State<DigilockerAuthWebView> createState() => _DigilockerAuthWebViewState();
}

class _DigilockerAuthWebViewState extends State<DigilockerAuthWebView> {
  final WebviewController _controller = WebviewController();
  final String _oauthCallbackPrefix =
      AppConfig.fromEnvironment().digilockerOAuthCallbackUrl;
  StreamSubscription<String>? _urlSub;
  StreamSubscription<WebErrorStatus>? _errorSub;
  bool _ready = false;
  bool _callbackReported = false;
  String? _initError;

  @override
  void initState() {
    super.initState();
    unawaited(_init());
  }

  Future<void> _init() async {
    try {
      final version = await WebviewController.getWebViewVersion();
      if (version == null) {
        final message =
            'Microsoft Edge WebView2 Runtime is required for DigiLocker sign-in. '
            'Install it from Microsoft, then restart the kiosk.';
        setState(() => _initError = message);
        widget.onError?.call(message);
        return;
      }

      await _controller.initialize();
      // Allow DigiLocker consent / OTP windows (deny was swallowing the share picker).
      await _controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.sameWindow);
      // Force a fresh DigiLocker session so cached consent does not skip the picker.
      await _controller.clearCookies();
      await _controller.clearCache();

      _urlSub = _controller.url.listen(_onUrl);
      _errorSub = _controller.onLoadError.listen((status) {
        // Ignore errors after we already hit the OAuth callback.
        if (_callbackReported) {
          return;
        }
        widget.onError?.call('DigiLocker page failed to load ($status).');
      });

      await _controller.loadUrl(widget.authorizationUrl);
      if (mounted) {
        setState(() => _ready = true);
      }
    } catch (error) {
      final message =
          'Could not start in-app DigiLocker browser: $error';
      if (mounted) {
        setState(() => _initError = message);
      }
      widget.onError?.call(message);
    }
  }

  void _onUrl(String url) {
    widget.onActivity?.call();
    if (_callbackReported) {
      return;
    }
    if (!url.startsWith(_oauthCallbackPrefix)) {
      return;
    }
    _callbackReported = true;
    // Allow the WebView navigation to complete so the API can exchange the code.
    Future<void>.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        widget.onCallbackReached();
      }
    });
  }

  @override
  void dispose() {
    unawaited(_teardown());
    super.dispose();
  }

  Future<void> _teardown() async {
    await _urlSub?.cancel();
    await _errorSub?.cancel();
    try {
      await _controller.clearCookies();
      await _controller.clearCache();
    } catch (_) {}
    try {
      await _controller.dispose();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_initError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _initError!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      );
    }

    if (!_ready) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading DigiLocker…'),
          ],
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF132029),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A3A42)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF2A3A42))),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_outline, color: Color(0xFF2EC4A0)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Sign in here — do not leave this screen',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15)),
              child: Webview(_controller),
            ),
          ),
        ],
      ),
    );
  }
}
