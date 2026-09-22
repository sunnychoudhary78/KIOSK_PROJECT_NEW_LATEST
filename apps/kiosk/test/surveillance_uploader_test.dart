import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:skp_kiosk/core/config/app_config.dart';
import 'package:skp_kiosk/core/network/api_client.dart';
import 'package:skp_kiosk/features/surveillance/data/surveillance_recorder.dart';
import 'package:skp_kiosk/features/surveillance/data/surveillance_upload_queue.dart';
import 'package:skp_kiosk/features/surveillance/data/surveillance_uploader.dart';

class _StubRecorder implements SurveillanceRecorder {
  @override
  Stream<SurveillanceNativeEvent> get events => const Stream.empty();

  @override
  Future<String?> getRootDir(String deviceId) async => null;

  @override
  Future<void> pauseForPalm() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> start(SurveillanceStartConfig config) async {}

  @override
  Future<void> stop() async {}
}

void main() {
  late Directory dir;
  late File segment;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('skp_surv_up');
    segment = File(p.join(dir.path, '2026-09-03', '143052_abc.mp4'));
    segment.parent.createSync(recursive: true);
    segment.writeAsBytesSync(List<int>.filled(16, 7));
  });

  tearDown(() {
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });

  test('putFileToUrl does not send Authorization', () async {
    http.BaseRequest? captured;
    final api = ApiClient(
      config: const AppConfig(apiBaseUrl: 'http://example.test/v1', environment: 'test'),
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response('', 200);
      }),
    );
    api.setAccessToken('device-jwt');
    await api.putFileToUrl(url: 'https://r2.example/put', file: segment);
    expect(captured, isNotNull);
    expect(captured!.method, 'PUT');
    expect(captured!.headers['authorization'], isNull);
    expect(captured!.headers['content-type'], 'video/mp4');
  });

  test('deletes local file only after complete succeeds', () async {
    final methods = <String>[];
    final api = ApiClient(
      config: const AppConfig(apiBaseUrl: 'http://example.test/v1', environment: 'test'),
      httpClient: MockClient((request) async {
        methods.add('${request.method} ${request.url.path}');
        if (request.method == 'POST' && request.url.path.endsWith('upload-url')) {
          return http.Response(
            jsonEncode({
              'segmentId': 'seg-1',
              'objectKey': 'surveillance/t/d/2026-09-03/143052_abc.mp4',
              'uploadUrl': 'https://r2.example/put',
              'alreadyUploaded': false,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.method == 'PUT') {
          expect(request.headers['authorization'], isNull);
          return http.Response('', 200);
        }
        if (request.method == 'POST' && request.url.path.endsWith('complete')) {
          return http.Response(jsonEncode({'ok': true, 'status': 'uploaded'}), 200);
        }
        return http.Response('nope', 500);
      }),
    );
    api.setAccessToken('device-jwt');
    final queue = SurveillanceUploadQueue(
      queueFile: File(p.join(dir.path, surveillanceQueueFileName)),
    );
    final uploader = SurveillanceUploader(
      api: api,
      recorder: _StubRecorder(),
      tickInterval: const Duration(days: 1),
      rootOverride: dir,
      queue: queue,
    );
    await uploader.attach(deviceId: 'device-1');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(segment.existsSync(), isFalse);
    expect(queue.items, isEmpty);
    expect(methods.where((m) => m.startsWith('PUT')), isNotEmpty);
    expect(methods.where((m) => m.endsWith('complete')), isNotEmpty);
    await uploader.detach();
  });

  test('keeps the file and backs off when complete fails', () async {
    final api = ApiClient(
      config: const AppConfig(apiBaseUrl: 'http://example.test/v1', environment: 'test'),
      httpClient: MockClient((request) async {
        if (request.method == 'POST' && request.url.path.endsWith('upload-url')) {
          return http.Response(
            jsonEncode({
              'segmentId': 'seg-1',
              'uploadUrl': 'https://r2.example/put',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.method == 'PUT') {
          return http.Response('', 200);
        }
        return http.Response(
          jsonEncode({'code': 'upload_incomplete', 'message': 'missing'}),
          409,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final queue = SurveillanceUploadQueue(
      queueFile: File(p.join(dir.path, surveillanceQueueFileName)),
    );
    final uploader = SurveillanceUploader(
      api: api,
      recorder: _StubRecorder(),
      tickInterval: const Duration(days: 1),
      rootOverride: dir,
      queue: queue,
    );
    await uploader.attach(deviceId: 'device-1');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(segment.existsSync(), isTrue);
    expect(queue.items, hasLength(1));
    expect(queue.items.single.attempts, greaterThan(0));
    await uploader.detach();
  });
}
