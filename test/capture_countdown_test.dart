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
  testWidgets('capture status stays visible when the preview stops', (
    tester,
  ) async {
    void retry() {}
    Future<void> render({
      bool busy = false,
      bool unknown = false,
      int? countdown,
    }) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScanView(
            punch: Punch.checkIn,
            place: const Place('Office', 18, 99, ''),
            preview: const ColoredBox(color: Colors.black),
            photoTaken: busy || unknown,
            busy: busy,
            countdown: countdown,
            found: true,
            blink: true,
            stage: 'กำลังตรวจภาพสดและเทียบใบหน้า',
            outcomeUnknown: unknown,
            error: unknown ? const UnknownOutcome().message : '',
            onRetry: retry,
          ),
        ),
      ),
    );
    await render(countdown: 0);
    expect(find.text('พร้อม'), findsNothing);
    await render(busy: true);
    expect(find.text('ถ่ายภาพแล้ว'), findsOneWidget);
    expect(find.text('กำลังยืนยันตัวตน'), findsOneWidget);
    expect(find.text('กำลังตรวจภาพสดและเทียบใบหน้า'), findsOneWidget);
    await render(unknown: true);
    expect(find.text('ยังยืนยันผลการลงเวลาไม่ได้'), findsOneWidget);
    expect(find.text('ตรวจประวัติลงเวลา'), findsOneWidget);
    expect(find.text('ยืนยันและสแกนใหม่'), findsNothing);
  });
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
    expect(c.isDue(start.add(const Duration(milliseconds: 2999))), isFalse);
    expect(c.isDue(start.add(const Duration(seconds: 3))), isTrue);
    expect(c.isDue(start.add(const Duration(seconds: 4))), isFalse);
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
  test('fast web scan keeps one blink through a brief positioning miss', () {
    final guide = FaceScanGuide(
      positionHold: const Duration(milliseconds: 400),
      positionGrace: const Duration(milliseconds: 250),
      captureHold: const Duration(seconds: 1),
    );
    final start = DateTime(2026);
    bool frame(
      int ms, {
      double eyes = .95,
      bool centered = true,
      bool one = true,
    }) => guide.observe(
      now: start.add(Duration(milliseconds: ms)),
      suitable: centered && one,
      oneFaceOutOfPosition: !centered && one,
      left: eyes,
      right: eyes,
    );
    for (var ms = 0; ms <= 420; ms += 70) {
      expect(frame(ms), isFalse);
    }
    expect(guide.positioned, isTrue);
    expect(frame(490, eyes: .2), isFalse);
    expect(frame(560), isFalse);
    expect(guide.blink.complete, isTrue);
    expect(guide.countdown.remaining, 1);
    expect(frame(630, centered: false), isFalse);
    expect(guide.blink.complete, isTrue);
    expect(guide.countdown.remaining, isNull);
    for (var ms = 700; ms < 1700; ms += 70) {
      expect(frame(ms), isFalse);
    }
    expect(frame(1750), isTrue);

    expect(frame(1820, one: false), isFalse);
    expect(guide.blink.complete, isFalse);
    expect(guide.positioned, isFalse);
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
