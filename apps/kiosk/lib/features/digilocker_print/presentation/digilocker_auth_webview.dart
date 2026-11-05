import 'dart:async';

import 'package:flutter/material.dart';
import 'package:skp_kiosk/core/config/app_config.dart';
import 'package:skp_kiosk/core/theme/skp_tokens.dart';
import 'package:skp_kiosk/core/ui/kiosk_keyboard.dart';
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

  /// Remembers the last focused editable so Flutter keyboard taps still type
  /// after WebView2 loses focus.
  static const _focusTrackerScript = r'''
(function () {
  if (window.__kioskKbInstalled) return;
  window.__kioskKbInstalled = true;
  window.__kioskLastEditable = null;
  function isEditable(el) {
    if (!el) return false;
    var tag = (el.tagName || '').toLowerCase();
    if (tag === 'input' || tag === 'textarea') return true;
    if (el.isContentEditable) return true;
    return false;
  }
  document.addEventListener('focusin', function (e) {
    if (isEditable(e.target)) {
      window.__kioskLastEditable = e.target;
    }
  }, true);
})();
''';

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
      await _controller.addScriptToExecuteOnDocumentCreated(_focusTrackerScript);

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

  static String _jsStringLiteral(String value) {
    return "'${value
        .replaceAll(r'\', r'\\')
        .replaceAll("'", r"\'")
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r')}'";
  }

  Future<void> _injectChar(String value) async {
    widget.onActivity?.call();
    final literal = _jsStringLiteral(value);
    try {
      await _controller.executeScript('''
(function () {
  function isEditable(el) {
    if (!el) return false;
    var tag = (el.tagName || '').toLowerCase();
    if (tag === 'input' || tag === 'textarea') return true;
    if (el.isContentEditable) return true;
    return false;
  }
  function setNativeValue(el, next) {
    var proto = el.tagName === 'TEXTAREA'
      ? window.HTMLTextAreaElement.prototype
      : window.HTMLInputElement.prototype;
    var desc = Object.getOwnPropertyDescriptor(proto, 'value');
    if (desc && desc.set) {
      desc.set.call(el, next);
    } else {
      el.value = next;
    }
  }
  function notify(el, data, inputType) {
    try {
      el.dispatchEvent(new InputEvent('input', {
        bubbles: true,
        cancelable: true,
        data: data,
        inputType: inputType
      }));
    } catch (_) {
      el.dispatchEvent(new Event('input', { bubbles: true }));
    }
    el.dispatchEvent(new Event('change', { bubbles: true }));
  }
  var el = window.__kioskLastEditable;
  if (!isEditable(el)) {
    el = document.activeElement;
  }
  if (!isEditable(el)) return;
  var ch = $literal;
  if (el.isContentEditable) {
    try { document.execCommand('insertText', false, ch); } catch (_) {}
    return;
  }
  var start = (typeof el.selectionStart === 'number') ? el.selectionStart : (el.value || '').length;
  var end = (typeof el.selectionEnd === 'number') ? el.selectionEnd : (el.value || '').length;
  var v = el.value || '';
  var next = v.slice(0, start) + ch + v.slice(end);
  setNativeValue(el, next);
  var pos = start + ch.length;
  try { el.setSelectionRange(pos, pos); } catch (_) {}
  notify(el, ch, 'insertText');
})();
''');
    } catch (_) {
      // Ignore injection failures (e.g. page mid-navigation).
    }
  }

  Future<void> _injectBackspace() async {
    widget.onActivity?.call();
    try {
      await _controller.executeScript(r'''
(function () {
  function isEditable(el) {
    if (!el) return false;
    var tag = (el.tagName || '').toLowerCase();
    if (tag === 'input' || tag === 'textarea') return true;
    if (el.isContentEditable) return true;
    return false;
  }
  function setNativeValue(el, next) {
    var proto = el.tagName === 'TEXTAREA'
      ? window.HTMLTextAreaElement.prototype
      : window.HTMLInputElement.prototype;
    var desc = Object.getOwnPropertyDescriptor(proto, 'value');
    if (desc && desc.set) {
      desc.set.call(el, next);
    } else {
      el.value = next;
    }
  }
  function notify(el) {
    try {
      el.dispatchEvent(new InputEvent('input', {
        bubbles: true,
        cancelable: true,
        inputType: 'deleteContentBackward'
      }));
    } catch (_) {
      el.dispatchEvent(new Event('input', { bubbles: true }));
    }
    el.dispatchEvent(new Event('change', { bubbles: true }));
  }
  var el = window.__kioskLastEditable;
  if (!isEditable(el)) {
    el = document.activeElement;
  }
  if (!isEditable(el)) return;
  if (el.isContentEditable) {
    try { document.execCommand('delete', false, null); } catch (_) {}
    return;
  }
  var v = el.value || '';
  var start = (typeof el.selectionStart === 'number') ? el.selectionStart : v.length;
  var end = (typeof el.selectionEnd === 'number') ? el.selectionEnd : v.length;
  var next;
  var pos;
  if (start !== end) {
    next = v.slice(0, start) + v.slice(end);
    pos = start;
  } else if (start > 0) {
    next = v.slice(0, start - 1) + v.slice(end);
    pos = start - 1;
  } else {
    return;
  }
  setNativeValue(el, next);
  try { el.setSelectionRange(pos, pos); } catch (_) {}
  notify(el);
})();
''');
    } catch (_) {
      // Ignore injection failures (e.g. page mid-navigation).
    }
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
        color: SkpColors.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SkpColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              child: Webview(_controller),
            ),
          ),
          const Divider(height: 1, color: SkpColors.line),
          SizedBox(
            height: 200,
            child: KioskKeyboard(
              onKey: (value) => unawaited(_injectChar(value)),
              onBackspace: () => unawaited(_injectBackspace()),
            ),
          ),
        ],
      ),
    );
  }
}
