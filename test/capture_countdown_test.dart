import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:nwl_secret_login/ui/scan_view.dart';
import 'package:nwl_secret_login/core/models.dart';
import 'package:nwl_secret_login/data/maps.dart';

void main() {
  testWidgets(
    'countdown and preparation message are visible on a small screen',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScanView(
              punch: Punch.checkIn,
              place: const Place('Office', 18, 99, ''),
              preview: const ColoredBox(color: Colors.black),
              countdown: 3,
              found: true,
              blink: true,
            ),
          ),
        ),
      );
      expect(find.text('3'), findsOneWidget);
      expect(find.text('เตรียมตัวถ่ายภาพ'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  test('camera waits three seconds of fresh observations after blink', () {
    final c = CaptureCountdown();
    final start = DateTime(2026);
    for (var ms = 0; ms < 3000; ms += 200) {
      expect(
        c.observe(
          now: start.add(Duration(milliseconds: ms)),
          ready: true,
          eyesOpen: true,
        ),
        false,
      );
    }
    expect(
      c.observe(
        now: start.add(const Duration(seconds: 3)),
        ready: true,
        eyesOpen: true,
      ),
      true,
    );
  });
  test('lost face or stalled camera restarts countdown; closed eyes wait', () {
    final c = CaptureCountdown();
    final start = DateTime(2026);
    c.observe(now: start, ready: true, eyesOpen: true);
    expect(
      c.observe(
        now: start.add(const Duration(seconds: 4)),
        ready: true,
        eyesOpen: true,
      ),
      false,
    );
    expect(c.remaining, 3);
    c.observe(
      now: start.add(const Duration(milliseconds: 4200)),
      ready: false,
      eyesOpen: true,
    );
    expect(c.remaining, isNull);
    for (var ms = 4400; ms <= 7600; ms += 200) {
      expect(
        c.observe(
          now: start.add(Duration(milliseconds: ms)),
          ready: true,
          eyesOpen: false,
        ),
        false,
      );
    }
    expect(
      c.observe(
        now: start.add(const Duration(milliseconds: 7800)),
        ready: true,
        eyesOpen: true,
      ),
      true,
    );
    c.reset();
    expect(c.remaining, isNull);
  });
  test('pasted coordinates and nested Google share links resolve', () async {
    final maps = Maps();
    final pin = await maps.resolve('18.7883, 98.9853');
    expect(pin.lat, 18.7883);
    expect(pin.viewport, false);
    final nested = await maps.resolve(
      'https://maps.app.goo.gl/?link=${Uri.encodeComponent('https://www.google.com/maps?q=18.7,98.9')}',
    );
    expect(nested.lng, 98.9);
    await expectLater(maps.resolve('91, 99'), throwsA(isA<AppFailure>()));
  });
}
