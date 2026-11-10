import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nwl_secret_login/core/controller.dart';
import 'package:nwl_secret_login/core/models.dart';
import 'package:nwl_secret_login/ui/app.dart';
import 'package:nwl_secret_login/ui/scan_view.dart';
import 'package:nwl_secret_login/ui/design.dart';

void main() {
  setUpAll(() async {
    final fonts = FontLoader('NotoSansThai')
      ..addFont(rootBundle.load('assets/NotoSansThai-Regular.ttf'));
    await fonts.load();
    final latin = FontLoader('NotoSans')
      ..addFont(rootBundle.load('assets/NotoSans-Regular.ttf'))
      ..addFont(rootBundle.load('assets/NotoSans-Bold.ttf'));
    await latin.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  void noScroll(WidgetTester t) {
    for (final scroll in t.stateList<ScrollableState>(
      find.byType(Scrollable),
    )) {
      if (axisDirectionToAxis(scroll.widget.axisDirection) == Axis.horizontal) {
        continue;
      }
      expect(
        scroll.position.maxScrollExtent,
        lessThanOrEqualTo(1),
        reason: 'screen should fit without scrolling',
      );
    }
    expect(t.takeException(), isNull);
  }

  for (final height in [667.0, 553.0]) {
    testWidgets('iPhone 8 login and home fit at 375 x $height', (t) async {
      t.view.physicalSize = Size(375, height);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final c = AppController()..ready = true;
      await t.pumpWidget(NwlApp(controller: c));
      await t.pump();
      noScroll(t);
      expect(find.text('เข้าสู่ระบบ').hitTestable(), findsOneWidget);
      c.demo = true;
      c.notifyListeners();
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      noScroll(t);
      expect(find.text('เลือกสถานที่').hitTestable(), findsOneWidget);
      c.places = [const Place('สำนักงาน', 18, 99, '')];
      c.notifyListeners();
      await t.pump();
      noScroll(t);
      expect(find.text('สแกนเข้างาน').hitTestable(), findsOneWidget);
      await t.pumpWidget(
        NwlApp(
          controller: c,
          home: AddPlacePage(controller: c),
        ),
      );
      await t.pump();
      noScroll(t);
      await t.enterText(find.byType(TextField).first, 'สำนักงาน');
      await t.enterText(
        find.byType(TextField).last,
        'https://www.google.com/maps/@18,99,16z',
      );
      await t.tap(find.text('อ่านพิกัดจากลิงก์'));
      await t.pumpAndSettle();
      noScroll(t);
      expect(find.text('บันทึกสถานที่').hitTestable(), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      c.dispose();
    });
    for (final state in ['position', 'blink', 'countdown', 'error', 'busy']) {
      testWidgets('iPhone 8 scan $state fits at 375 x $height', (t) async {
        t.view.physicalSize = Size(375, height);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        await t.pumpWidget(
          MaterialApp(
            theme: appTheme(),
            home: Scaffold(
              appBar: AppBar(title: const Text('ลงเวลาเข้างาน')),
              body: SafeArea(
                child: ScanView(
                  punch: Punch.checkIn,
                  place: const Place('สำนักงาน', 18, 99, ''),
                  preview: const ColoredBox(color: Colors.black),
                  found: state != 'position',
                  blink: state == 'countdown',
                  countdown: state == 'countdown' ? 3 : null,
                  busy: state == 'busy',
                  error: state == 'error'
                      ? 'ตรวจใบหน้าไม่สำเร็จภายใน 30 วินาที กรุณาจัดใบหน้าให้อยู่ในกรอบแล้วลองใหม่'
                      : '',
                  stage: state == 'position'
                      ? 'ขยับใบหน้าเข้ามาใกล้อีกนิด'
                      : 'กะพริบตา 1 ครั้ง แล้วลืมตา',
                  onBack: () {},
                  onRetry: () {},
                ),
              ),
            ),
          ),
        );
        await t.pump();
        noScroll(t);
        if (height == 667 && state == 'blink') {
          await expectLater(
            find.byType(Scaffold),
            matchesGoldenFile('captures/iphone8-scan.png'),
          );
        }
        if (state != 'busy') {
          expect(find.text('กลับหน้าหลัก').hitTestable(), findsOneWidget);
        }
      });
    }
  }
  test(
    'guidance requires positioning before blink and resets if face disappears',
    () {
      final guide = FaceScanGuide();
      final start = DateTime(2026);
      bool frame(int ms, {bool face = true, double eyes = 1}) => guide.observe(
        now: start.add(Duration(milliseconds: ms)),
        suitable: face,
        left: eyes,
        right: eyes,
        guidance: 'ขยับใบหน้าเข้ามาใกล้อีกนิด',
      );
      frame(0, face: false);
      expect(guide.hint, contains('ใกล้'));
      frame(100);
      frame(300, eyes: 0);
      frame(500);
      expect(guide.blink.complete, false);
      frame(700);
      frame(900);
      expect(guide.positioned, true);
      expect(guide.blink.complete, false);
      frame(1100, eyes: 0);
      frame(1300);
      expect(guide.blink.complete, true);
      for (var ms = 1500; ms < 4300; ms += 200) {
        expect(frame(ms), false);
      }
      expect(frame(4300), true);
      frame(4500, face: false);
      expect(guide.positioned, false);
      expect(guide.blink.complete, false);
      expect(guide.countdown.remaining, isNull);
    },
  );
}
