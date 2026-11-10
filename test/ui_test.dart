import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nwl_secret_login/core/controller.dart';
import 'package:nwl_secret_login/core/models.dart';
import 'package:nwl_secret_login/ui/app.dart';
import 'package:nwl_secret_login/ui/camera.dart';
import 'package:nwl_secret_login/ui/design.dart';
import 'package:nwl_secret_login/ui/history_insights.dart';
import 'package:nwl_secret_login/features/attendance_insights.dart';
import 'package:nwl_secret_login/ui/reminder_preferences.dart';
import 'package:nwl_secret_login/ui/alarm_prompt.dart';
import 'package:nwl_secret_login/ui/early_checkout.dart';

void main() {
  setUpAll(() async {
    final loader = FontLoader('NotoSansThai')
      ..addFont(rootBundle.load('assets/NotoSansThai-Regular.ttf'))
      ..addFont(rootBundle.load('assets/NotoSansThai-Bold.ttf'));
    await loader.load();
    final latin = FontLoader('NotoSans')
      ..addFont(rootBundle.load('assets/NotoSans-Regular.ttf'))
      ..addFont(rootBundle.load('assets/NotoSans-Bold.ttf'));
    await latin.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<void> render(
    WidgetTester t,
    Widget page, {
    double width = 390,
    double height = 844,
    double scale = 1,
  }) async {
    t.view.physicalSize = Size(width, height);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      NwlApp(
        controller: AppController(),
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, height),
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
          ),
          child: page,
        ),
      ),
    );
    await t.runAsync(
      () => precacheImage(
        const AssetImage('assets/motion/time-orbit.webp'),
        t.element(find.byType(MaterialApp)),
      ),
    );
    await t.pump(const Duration(milliseconds: 700));
    expect(t.takeException(), isNull);
  }

  testWidgets(
    'login validates empty fields; password visibility and demo navigation',
    (t) async {
      final c = AppController()..ready = true;
      await t.pumpWidget(NwlApp(controller: c));
      await t.pump();
      await t.ensureVisible(find.text('เข้าสู่ระบบ'));
      await t.tap(find.text('เข้าสู่ระบบ'));
      await t.pump();
      expect(find.text('กรอกรหัสพนักงาน'), findsOneWidget);
      await t.ensureVisible(find.byTooltip('แสดงรหัสผ่าน'));
      await t.tap(find.byTooltip('แสดงรหัสผ่าน'));
      await t.pump();
      expect(find.byTooltip('ซ่อนรหัสผ่าน'), findsOneWidget);
      await t.ensureVisible(find.text('ทดลองใช้งานก่อนเข้าสู่ระบบ'));
      await t.tap(find.text('ทดลองใช้งานก่อนเข้าสู่ระบบ'));
      await t.pump();
      expect(find.text('วันนี้ของคุณ'), findsOneWidget);
      expect(c.demo, true);
    },
  );
  testWidgets(
    'alarm popup appears above settings and opens the root attendance flow',
    (t) async {
      final c = AppController()
        ..ready = true
        ..demo = true;
      await t.pumpWidget(NwlApp(controller: c));
      await t.pump();
      await t.tap(find.byTooltip('เตือนลงเวลาและวันทำงาน'));
      await t.pumpAndSettle();
      c.showReminder(false);
      await t.pumpAndSettle();
      expect(find.text('พร้อมเริ่มวันทำงาน'), findsOneWidget);
      await t.tap(find.text('เข้าสู่ระบบเพื่อลงเวลา'));
      await t.pumpAndSettle();
      expect(c.reminderPrompt, false);
      expect(find.text('วันนี้ของคุณ'), findsOneWidget);
      expect(find.text('ไม่พลาดเวลาสำคัญ'), findsNothing);
    },
  );
  testWidgets('saved places and choice survive a new preferences read', (
    t,
  ) async {
    final c = AppController();
    await c.savePlace(
      const Place('Office', 18.7, 98.9, 'https://maps.google.com/?q=18.7,98.9'),
    );
    expect(
      (await SharedPreferences.getInstance()).getString('places'),
      contains('Office'),
    );
    await c.deletePlace(0);
    expect(c.place, isNull);
  });
  testWidgets('early checkout warning fits a narrow screen', (t) async {
    await render(
      t,
      Scaffold(body: EarlyCheckoutDialog(now: DateTime(2026, 11, 9, 17, 30))),
      width: 320,
      height: 640,
      scale: 1.3,
    );
    expect(find.text('ออกก่อนเวลาเลิกงาน?'), findsOneWidget);
    expect(find.text('ยังไม่ออก'), findsOneWidget);
    expect(find.text('ยืนยันและสแกนหน้า'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('selected five screen render capture', (t) async {
    final c = AppController()
      ..ready = true
      ..demo = true
      ..places = [const Place('สำนักงาน NWL', 18.7883, 98.9853, '')];
    const place = Place('สำนักงาน NWL', 18.7883, 98.9853, '');
    const preview = Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.account_circle_outlined, size: 78, color: muted),
          SizedBox(height: 12),
          Text('UI PREVIEW', style: TextStyle(color: muted)),
          Text(
            'ภาพตัวอย่าง · ไม่ส่งข้อมูลจริง',
            style: TextStyle(color: muted, fontSize: 11),
          ),
        ],
      ),
    );
    c.logs = [
      const AttendanceEntry('I', '06-Nov-2026----  8:52am', 1),
      const AttendanceEntry('O', '06-Nov-2026----  6:02pm', 1),
    ];
    c.date = DateTime(2026, 11, 6);
    c.processedDay = ProcessedAttendanceDay(
      c.date,
      inTime: '08:52',
      outTime: '18:02',
      status: 'Present',
      holiday: false,
    );
    final pages = <String, Widget>{
      'alarm-popup': AlarmPrompt(
        controller: c,
        clockTime: DateTime(2026, 11, 6, 8, 20),
      ),
      'history': Scaffold(body: HistoryInsightsPage(controller: c)),
      'reminders': ReminderPreferencesPage(controller: c),
      'splash': const SplashPage(),
      'login': LoginPage(controller: c),
      'today': HomePage(controller: c),
      'clock-in': Scaffold(
        appBar: AppBar(title: const Text('ลงเวลาเข้างาน')),
        body: const SafeArea(
          child: ScanView(
            punch: Punch.checkIn,
            place: place,
            preview: preview,
            found: true,
            blink: true,
            matched: true,
            busy: true,
            stage: 'กำลังบันทึกเวลาเข้างาน…',
          ),
        ),
      ),
      'clock-out': Scaffold(
        appBar: AppBar(title: const Text('ลงเวลาออกงาน')),
        body: SafeArea(
          child: ScanView(
            punch: Punch.checkOut,
            place: place,
            preview: preview,
            error: 'อยู่ในที่สว่าง แล้วสแกนอีกครั้ง',
            onRetry: () {},
            onBack: () {},
          ),
        ),
      ),
    };
    for (final page in pages.entries) {
      await render(t, page.value);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('captures/${page.key}.png'),
      );
    }
    await render(
      t,
      Scaffold(body: HistoryInsightsPage(controller: c)),
      width: 320,
      height: 640,
      scale: 1.3,
    );
    c.lateReport = LateReport(DateTime(2026, 11), [
      LateDay(
        DateTime(2026, 11, 6),
        DayAttendance.late,
        firstIn: DateTime(2026, 11, 6, 9, 31),
        minutes: 31,
      ),
      LateDay(DateTime(2026, 11, 7), DayAttendance.holiday),
    ]);
    await t.tap(find.text('สรุปรายเดือน'));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('31 นาที'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('captures/monthly-lateness.png'),
    );
    expect(t.takeException(), isNull);
    await render(
      t,
      ReminderPreferencesPage(controller: c),
      width: 320,
      height: 640,
      scale: 1.3,
    );
    await t.ensureVisible(find.text('เพิ่มวันหยุด'));
    await t.pump();
    expect(t.takeException(), isNull);
    await render(
      t,
      LoginPage(controller: c),
      width: 320,
      height: 640,
      scale: 1.3,
    );
    await t.ensureVisible(find.text('ทดลองใช้งานก่อนเข้าสู่ระบบ'));
    await t.pump();
    expect(t.takeException(), isNull);
    await render(
      t,
      AlarmPrompt(controller: c, clockTime: DateTime(2026, 11, 6, 8, 20)),
      width: 320,
      height: 640,
      scale: 1.3,
    );
    await t.ensureVisible(find.text('ปิดการปลุก'));
    await t.pump();
    expect(t.takeException(), isNull);
    await render(t, pages['clock-out']!, width: 320, height: 640, scale: 1.3);
    await t.ensureVisible(find.text('ยืนยันและสแกนใหม่'));
    await t.pump();
    expect(t.takeException(), isNull);
  });
}
