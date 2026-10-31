import 'package:flutter_test/flutter_test.dart';
import 'package:skp_admin/features/printer/data/printer_display.dart';

void main() {
  test('accepts a whole number of pages from 1 to 2000', () {
    expect(validateTrayPages('1'), isNull);
    expect(validateTrayPages(' 2000 '), isNull);
    expect(validateTrayPages('10'), isNull);
  });

  test('rejects empty, fractional, and out-of-range tray loads', () {
    const message = 'Enter a whole number of pages from 1 to 2000';
    expect(validateTrayPages(''), message);
    expect(validateTrayPages('0'), message);
    expect(validateTrayPages('2001'), message);
    expect(validateTrayPages('1.5'), message);
    expect(validateTrayPages('abc'), message);
  });

  test('stops the printer refresh poll when the new report has landed', () {
    expect(
      printerRefreshSettled(
        printerHealthAt: '2026-10-26T12:00:01.000Z',
        printerRefreshRequestedAt: null,
        requestedAt: '2026-10-26T12:00:00.000Z',
      ),
      isTrue,
    );
    expect(
      printerRefreshSettled(
        printerHealthAt: '2026-10-26T12:00:00.000Z',
        printerRefreshRequestedAt: null,
        requestedAt: '2026-10-26T12:00:00.000Z',
      ),
      isTrue,
    );
  });

  test('keeps polling while the request is pending or the report is older', () {
    expect(
      printerRefreshSettled(
        printerHealthAt: '2026-10-26T12:00:05.000Z',
        printerRefreshRequestedAt: '2026-10-26T12:00:00.000Z',
        requestedAt: '2026-10-26T12:00:00.000Z',
      ),
      isFalse,
    );
    expect(
      printerRefreshSettled(
        printerHealthAt: '2026-10-26T11:59:59.000Z',
        printerRefreshRequestedAt: null,
        requestedAt: '2026-10-26T12:00:00.000Z',
      ),
      isFalse,
    );
    expect(
      printerRefreshSettled(
        printerHealthAt: null,
        printerRefreshRequestedAt: null,
        requestedAt: '2026-10-26T12:00:00.000Z',
      ),
      isFalse,
    );
    expect(
      printerRefreshSettled(
        printerHealthAt: 'not-a-date',
        printerRefreshRequestedAt: null,
        requestedAt: '2026-10-26T12:00:00.000Z',
      ),
      isFalse,
    );
  });
}
