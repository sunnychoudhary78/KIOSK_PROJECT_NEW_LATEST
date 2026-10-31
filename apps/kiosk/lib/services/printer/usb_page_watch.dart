import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skp_kiosk/services/printer/printer_health.dart';
import 'package:skp_kiosk/services/printer/usb_snapshot.dart';

final usbPageWatchProvider = Provider<UsbPageWatch>((ref) {
  return UsbPageWatch();
});

/// Last successful USB page total from the 2-second watch.
/// A failed or busy read does not clear it.
class UsbPageWatch {
  static const freshLimit = Duration(seconds: 5);

  int? _pages;
  DateTime? _at;
  int? _statusCode;
  String? _statusMessage;
  bool _paperOutLatched = false;
  int? _tonerBlack;
  int? _tonerCyan;
  int? _tonerMagenta;
  int? _tonerYellow;
  int? _pagesColor;
  int? _pagesBlackAndWhite;
  int? _beltRemainingPages;
  int? _fuserRemainingPages;
  List<PrinterErrorHistoryEntry>? _errorHistory;
  bool _errorHistoryRead = false;
  bool _seenUsbOk = false;
  bool _lastUsbOk = false;
  DateTime? _lastUsbSuccessAt;

  /// While true, the compare loop must not open the USB pipe.
  bool suppress = false;

  int? get statusCode => _statusCode;

  String? get statusMessage => _statusMessage;

  /// Tray 1 `41236` until USB Ready `10001`. Failed reads leave it unchanged.
  bool get paperOutLatched => _paperOutLatched;

  int? get tonerBlack => _tonerBlack;

  int? get tonerCyan => _tonerCyan;

  int? get tonerMagenta => _tonerMagenta;

  int? get tonerYellow => _tonerYellow;

  int? get pagesColor => _pagesColor;

  int? get pagesBlackAndWhite => _pagesBlackAndWhite;

  int? get beltRemainingPages => _beltRemainingPages;

  int? get fuserRemainingPages => _fuserRemainingPages;

  bool get errorHistoryRead => _errorHistoryRead;

  List<PrinterErrorHistoryEntry> get errorHistory =>
      _errorHistory ?? const [];

  /// Null until the first successful USB read.
  bool? get lastUsbOk => _seenUsbOk ? _lastUsbOk : null;

  DateTime? get lastUsbSuccessAt => _lastUsbSuccessAt;

  void record(UsbSnapshot snapshot) {
    if (!snapshot.ok) {
      if (_seenUsbOk) _lastUsbOk = false;
      return;
    }
    _seenUsbOk = true;
    _lastUsbOk = true;
    _lastUsbSuccessAt = DateTime.now();
    if (snapshot.pagesTotal != null) {
      _pages = snapshot.pagesTotal;
      _at = DateTime.now();
    }
    if (snapshot.pagesColor != null) _pagesColor = snapshot.pagesColor;
    if (snapshot.pagesBlackAndWhite != null) {
      _pagesBlackAndWhite = snapshot.pagesBlackAndWhite;
    }
    if (snapshot.beltRemainingPages != null) {
      _beltRemainingPages = snapshot.beltRemainingPages;
    }
    if (snapshot.fuserRemainingPages != null) {
      _fuserRemainingPages = snapshot.fuserRemainingPages;
    }
    if (snapshot.errorHistory != null) {
      _errorHistory = snapshot.errorHistory;
      _errorHistoryRead = true;
    }
    if (snapshot.tonerBlack != null) _tonerBlack = snapshot.tonerBlack;
    if (snapshot.tonerCyan != null) _tonerCyan = snapshot.tonerCyan;
    if (snapshot.tonerMagenta != null) _tonerMagenta = snapshot.tonerMagenta;
    if (snapshot.tonerYellow != null) _tonerYellow = snapshot.tonerYellow;
    final code = snapshot.statusCode;
    if (code == null) return;
    _statusCode = code;
    _statusMessage = snapshot.statusMessage;
    if (code == usbStatusPaperOut) {
      _paperOutLatched = true;
    } else if (code == usbStatusReady) {
      _paperOutLatched = false;
    }
  }

  /// Total from the last [freshLimit], for the pre-spool baseline.
  int? freshPages({DateTime? now}) {
    final pages = _pages;
    final at = _at;
    if (pages == null || at == null) return null;
    final clock = now ?? DateTime.now();
    if (clock.difference(at) > freshLimit) return null;
    return pages;
  }

  /// Last good total, including one that has not moved since the baseline.
  int? get latestPages => _pages;
}
