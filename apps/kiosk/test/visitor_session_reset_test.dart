import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skp_kiosk/features/session/application/visitor_session_reset.dart';

void main() {
  test('bestEffortTimed completes when work finishes under the limit', () {
    fakeAsync((async) {
      var ran = false;
      var done = false;
      bestEffortTimed(
        'ok',
        () async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          ran = true;
        },
        const Duration(seconds: 1),
      ).then((_) => done = true);

      async.elapse(const Duration(milliseconds: 100));
      async.flushMicrotasks();
      expect(ran, isTrue);
      expect(done, isTrue);
    });
  });

  test('bestEffortTimed returns on timeout without waiting forever', () {
    fakeAsync((async) {
      var done = false;
      bestEffortTimed(
        'hang',
        () => Completer<void>().future,
        const Duration(seconds: 5),
      ).then((_) => done = true);

      async.elapse(const Duration(seconds: 4));
      async.flushMicrotasks();
      expect(done, isFalse);

      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();
      expect(done, isTrue);
    });
  });

  test('bestEffortTimed swallows errors from the step', () {
    fakeAsync((async) {
      var done = false;
      bestEffortTimed(
        'boom',
        () async => throw StateError('boom'),
        const Duration(seconds: 1),
      ).then((_) => done = true);

      async.flushMicrotasks();
      expect(done, isTrue);
    });
  });
}
