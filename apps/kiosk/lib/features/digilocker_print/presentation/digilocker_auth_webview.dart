import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';

/// DigiLocker OAuth redirect registered with MeriPehchaan (exact match prefix).
const digilockerOAuthCallbackPrefix =
    'http://localhost:3000/api/v1/auth/digilocker/callback';

/// In-app WebView2 pane for MeriPehchaan DigiLocker authorization.
class DigilockerAuthWebView extends StatefulWidget {
  const DigilockerAuthWebView({
    super.key,
    required this.authorizationUrl,
    required this.onCallbackReached,
    this.onError,
  });

  final String authorizationUrl;
  final VoidCallback onCallbackReached;
  final ValueChanged<String>? onError;

  @override
  State<DigilockerAuthWebView> createState() => _DigilockerAuthWebViewState();
}

class _DigilockerAuthWebViewState extends State<DigilockerAuthWebView> {
  final WebviewController _controller = WebviewController();
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
        // Ignore errors after we already hit the localhost callback.
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
    if (_callbackReported) {
      return;
    }
    if (!url.startsWith(digilockerOAuthCallbackPrefix)) {
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
    unawaited(_urlSub?.cancel() ?? Future.value());
    unawaited(_errorSub?.cancel() ?? Future.value());
    unawaited(_controller.dispose());
    super.dispose();
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text('Sign in to DigiLocker — stay in this window'),
          ),
        ),
        Expanded(child: Webview(_controller)),
      ],
    );
  }
}
