import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:skp_kiosk/core/config/app_config.dart';
import 'package:skp_kiosk/core/network/api_client.dart';
import 'package:skp_kiosk/core/network/user_facing_error.dart';

void main() {
  const config = AppConfig(
    apiBaseUrl: 'http://example.test/v1',
    environment: 'test',
  );

  test('post throws TimeoutException when the client never responds', () {
    fakeAsync((async) {
      Object? caught;
      var settled = false;
      final api = ApiClient(
        config: config,
        requestTimeout: const Duration(seconds: 15),
        httpClient: MockClient((_) => Completer<http.Response>().future),
      );

      unawaited(() async {
        try {
          await api.post('/auth/device/token', body: {'a': 'b'});
        } catch (error) {
          caught = error;
        } finally {
          settled = true;
        }
      }());

      async.elapse(const Duration(seconds: 14));
      async.flushMicrotasks();
      expect(settled, isFalse);
      expect(caught, isNull);

      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();
      expect(settled, isTrue);
      expect(caught, isA<TimeoutException>());
      expect(
        userFacingError(caught!),
        "Can't reach the server. Check the connection and try again.",
      );
    });
  });

  test('get uses the same default timeout budget', () {
    fakeAsync((async) {
      Object? caught;
      var settled = false;
      final api = ApiClient(
        config: config,
        requestTimeout: const Duration(seconds: 2),
        httpClient: MockClient((_) => Completer<http.Response>().future),
      );

      unawaited(() async {
        try {
          await api.get('/devices/x/heartbeat');
        } catch (error) {
          caught = error;
        } finally {
          settled = true;
        }
      }());

      async.elapse(const Duration(seconds: 2));
      async.flushMicrotasks();
      expect(settled, isTrue);
      expect(caught, isA<TimeoutException>());
    });
  });
}
