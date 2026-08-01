import 'package:flutter_test/flutter_test.dart';
import 'package:skp_kiosk/features/well_being/application/vitals_line_parser.dart';

void main() {
  group('VitalsLineParser firmware lines', () {
    late VitalsLineParser parser;

    setUp(() {
      parser = VitalsLineParser();
    });

    test('parses full valid firmware sample', () {
      final result = parser.parseLine(
        'RED=12000 IR=62000 HR=78 SpO2=98 validHR=1 validSpO2=1 validCount=2',
      );
      expect(result, isNotNull);
      expect(result!.finger, isTrue);
      expect(result.heartRate, 78);
      expect(result.spo2, 98);
      expect(result.validHr, isTrue);
      expect(result.validSpo2, isTrue);
      expect(result.validCount, 2);
      expect(result.fingerAbsent, isFalse);
    });

    test('HR=-- and SpO2=-- are missing values', () {
      final result = parser.parseLine(
        'RED=262143 IR=60000 HR=-- SpO2=-- validHR=0 validSpO2=0 validCount=0',
      );
      expect(result, isNotNull);
      expect(result!.heartRate, isNull);
      expect(result.spo2, isNull);
      expect(result.validHr, isFalse);
      expect(result.validSpo2, isFalse);
      expect(result.finger, isTrue);
    });

    test('finger false when IR below 50000', () {
      final result = parser.parseLine(
        'RED=1000 IR=12000 HR=-- SpO2=-- validHR=0 validSpO2=0 validCount=0',
      );
      expect(result, isNotNull);
      expect(result!.finger, isFalse);
      expect(result.fingerAbsent, isTrue);
    });

    test('finger true when IR above 50000', () {
      final result = parser.parseLine(
        'RED=1000 IR=50001 HR=72 SpO2=97 validHR=1 validSpO2=1 validCount=1',
      );
      expect(result!.finger, isTrue);
    });

    test('does not treat validHR=0 as wiping sample identity', () {
      final result = parser.parseLine(
        'RED=1000 IR=60000 HR=-- SpO2=-- validHR=0 validSpO2=0 validCount=0',
      );
      expect(result!.recognized, isTrue);
      expect(result.finger, isTrue);
      expect(result.validCount, 0);
    });

    test('ignores wifi boot noise', () {
      expect(parser.addChunk('Connecting to WiFi........\n'), isEmpty);
      expect(
        parser.addChunk('Kiosk Dashboard Web Server Ready: http://192.168.1.5\n'),
        isEmpty,
      );
    });

    test('buffers fragmented firmware line', () {
      expect(parser.addChunk('RED=12000 IR=62000 HR=7'), isEmpty);
      final results = parser.addChunk('8 SpO2=98 validHR=1 validSpO2=1 validCount=3\n');
      expect(results, hasLength(1));
      expect(results.single.heartRate, 78);
      expect(results.single.spo2, 98);
      expect(results.single.validCount, 3);
      expect(results.single.finger, isTrue);
    });

    test('tiny slices of validHR do not become HR=1', () {
      expect(parser.addChunk('va'), isEmpty);
      expect(parser.addChunk('lid'), isEmpty);
      // Completes as validHR=1 without IR — not a full firmware sample alone.
      final mid = parser.addChunk('HR=1\n');
      // May coalesce; force timeout flush with fake clock.
      final clock = _FakeClock(DateTime(2026, 1, 1));
      parser = VitalsLineParser(
        frameTimeout: const Duration(milliseconds: 400),
        clock: clock,
      );
      parser.addChunk('validHR=1\n');
      clock.advance(const Duration(milliseconds: 500));
      final flushed = parser.flushTimedOut();
      for (final result in [...mid, ...flushed]) {
        expect(result.heartRate, isNot(1));
      }
    });

    test('signal quality bands', () {
      final poor = parser.parseLine(
        'RED=1 IR=10000 HR=-- SpO2=-- validHR=0 validSpO2=0 validCount=0',
      );
      expect(poor!.signalQualityLabel, 'Poor');

      final fair = parser.parseLine(
        'RED=1 IR=60000 HR=-- SpO2=-- validHR=0 validSpO2=0 validCount=0',
      );
      expect(fair!.signalQualityLabel, 'Fair');

      final excellent = parser.parseLine(
        'RED=1 IR=90000 HR=80 SpO2=99 validHR=1 validSpO2=1 validCount=3',
      );
      expect(excellent!.signalQualityLabel, 'Excellent');
    });

    test('drops out-of-band HR even when validHR=1', () {
      final result = parser.parseLine(
        'RED=1 IR=60000 HR=1 SpO2=98 validHR=1 validSpO2=1 validCount=1',
      );
      expect(result!.heartRate, isNull);
      expect(result.spo2, 98);
    });
  });
}

class _FakeClock {
  _FakeClock(this._now);

  DateTime _now;

  DateTime call() => _now;

  void advance(Duration by) {
    _now = _now.add(by);
  }
}
