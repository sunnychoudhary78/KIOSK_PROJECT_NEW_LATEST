import 'package:flutter_test/flutter_test.dart';
import 'package:skp_kiosk/features/well_being/application/vitals_line_parser.dart';

void main() {
  group('VitalsLineParser v2 firmware protocol', () {
    late VitalsLineParser parser;

    setUp(() {
      parser = VitalsLineParser();
    });

    test('parses ready with sensor flags', () {
      final result = parser.parseLine(
        '{"status":"ready","max30102":true,"mlx90614":false}',
      );
      expect(result, isNotNull);
      expect(result!.kind, VitalsMessageKind.ready);
      expect(result.max30102Ok, isTrue);
      expect(result.mlx90614Ok, isFalse);
    });

    test('parses place_finger and finger_detected', () {
      final place = parser.parseLine('{"status":"place_finger"}');
      expect(place!.kind, VitalsMessageKind.placeFinger);
      expect(place.fingerAbsent, isTrue);

      final detected = parser.parseLine('{"status":"finger_detected"}');
      expect(detected!.kind, VitalsMessageKind.fingerDetected);
      expect(detected.finger, isTrue);
    });

    test('parses recording countdowns for both sensors', () {
      final max = parser.parseLine(
        '{"status":"recording","sensor":"max30102","elapsed":3,"remaining":17}',
      );
      expect(max!.kind, VitalsMessageKind.recording);
      expect(max.isMaxRecording, isTrue);
      expect(max.elapsedSeconds, 3);
      expect(max.remSeconds, 17);

      final temp = parser.parseLine(
        '{"status":"recording","sensor":"mlx90614","elapsed":10,"remaining":50}',
      );
      expect(temp!.isTempRecording, isTrue);
      expect(temp.remSeconds, 50);
    });

    test('parses oxi result with null temps', () {
      final result = parser.parseLine(
        '{"bpm":75.5,"spo2":98.0,"object_f":null,"ambient_f":null}',
      );
      expect(result!.kind, VitalsMessageKind.result);
      expect(result.finalHeartRate, 75.5);
      expect(result.finalSpO2, 98.0);
      expect(result.temperatureC, isNull);
      expect(result.ok, isTrue);
    });

    test('parses firmware complete oxi result', () {
      final result = parser.parseLine(
        '{"status":"complete","bpm":75.5,"spo2":98.0,"object_f":null,"ambient_f":null}',
      );
      expect(result!.kind, VitalsMessageKind.result);
      expect(result.finalHeartRate, 75.5);
      expect(result.finalSpO2, 98.0);
      expect(result.temperatureC, isNull);
      expect(result.ok, isTrue);
    });

    test('parses firmware complete temp result', () {
      final result = parser.parseLine(
        '{"status":"complete","bpm":null,"spo2":null,"object_f":98.6,"ambient_f":75.20}',
      );
      expect(result!.kind, VitalsMessageKind.result);
      expect(result.heartRate, isNull);
      expect(result.spo2, isNull);
      expect(result.temperatureF, closeTo(98.6, 0.01));
      expect(result.temperatureC, closeTo(37.0, 0.05));
      expect(result.ambientTempF, closeTo(75.2, 0.01));
      expect(result.ok, isTrue);
    });

    test('parses complete with all-null vitals as unsuccessful result', () {
      final result = parser.parseLine(
        '{"status":"complete","bpm":null,"spo2":null,"object_f":null,"ambient_f":null}',
      );
      expect(result!.kind, VitalsMessageKind.result);
      expect(result.heartRate, isNull);
      expect(result.spo2, isNull);
      expect(result.temperatureC, isNull);
      expect(result.ok, isFalse);
    });

    test('parses temp result and converts F to C', () {
      final result = parser.parseLine(
        '{"bpm":null,"spo2":null,"object_f":98.6,"ambient_f":75.20}',
      );
      expect(result!.kind, VitalsMessageKind.result);
      expect(result.heartRate, isNull);
      expect(result.spo2, isNull);
      expect(result.temperatureF, closeTo(98.6, 0.01));
      expect(result.temperatureC, closeTo(37.0, 0.05));
      expect(result.ambientTempF, closeTo(75.2, 0.01));
      expect(result.canCaptureTemp, isTrue);
    });

    test('parses aborted finger_removed', () {
      final result = parser.parseLine(
        '{"status":"aborted","reason":"finger_removed"}',
      );
      expect(result!.kind, VitalsMessageKind.aborted);
      expect(result.isFingerRemovedAbort, isTrue);
      expect(result.abortReason, 'finger_removed');
    });

    test('maps sensor-not-found statuses to errors', () {
      final max = parser.parseLine('{"status":"max30102_not_found"}');
      expect(max!.kind, VitalsMessageKind.error);
      expect(max.errorMessage, 'max30102_not_found');

      final temp = parser.parseLine('{"status":"mlx90614_not_found"}');
      expect(temp!.kind, VitalsMessageKind.error);
    });

    test('buffers fragmented JSON across chunks', () {
      expect(
        parser.addChunk('{"bpm":72.0,"spo2":97.'),
        isEmpty,
      );
      final results = parser.addChunk('0,"object_f":null,"ambient_f":null}\n');
      expect(results, hasLength(1));
      expect(results.single.finalHeartRate, 72.0);
      expect(results.single.finalSpO2, 97.0);
    });

    test('ignores non-JSON lines and old protocol', () {
      expect(parser.addChunk('Connecting to WiFi........\n'), isEmpty);
      expect(parser.addChunk('hello\n'), isEmpty);
      expect(
        parser.parseLine(
          '{"mode":"oxi","st":2,"bpm":78,"spo2":98,"rem":12,"pct":16,'
          '"fb":0,"fs":0,"ok":0}',
        ),
        isNull,
      );
    });

    test('drops out-of-band bpm/spo2 on result', () {
      final result = parser.parseLine(
        '{"bpm":1,"spo2":50,"object_f":null,"ambient_f":null}',
      );
      expect(result!.heartRate, isNull);
      expect(result.spo2, isNull);
      expect(result.ok, isFalse);
    });

    test('parses sensor_started', () {
      final result = parser.parseLine('{"status":"sensor_started"}');
      expect(result!.kind, VitalsMessageKind.sensorStarted);
    });
  });
}
