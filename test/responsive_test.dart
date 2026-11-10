import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nwl_secret_login/core/controller.dart';
import 'package:nwl_secret_login/ui/app.dart';

void main() {
  for (final width in [320.0, 390.0, 768.0, 1024.0, 1440.0]) {
    testWidgets('responsive shell and navigation at $width px', (t) async {
      t.view.physicalSize = Size(width, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final c = AppController()
        ..ready = true
        ..demo = true;
      await t.pumpWidget(NwlApp(controller: c));
      await t.pump();
      expect(t.takeException(), isNull);
      expect(
        find.byType(NavigationRail),
        width >= 840 ? findsOneWidget : findsNothing,
      );
      expect(
        find.byType(NavigationBar),
        width < 840 ? findsOneWidget : findsNothing,
      );
      await t.tap(find.byKey(const ValueKey('nav-history')));
      await t.pump();
      expect(find.text('ประวัติและการมาสาย'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      c.dispose();
    });
    testWidgets('login fits $width px', (t) async {
      t.view.physicalSize = Size(width, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final c = AppController()..ready = true;
      await t.pumpWidget(NwlApp(controller: c));
      await t.pump();
      expect(find.text('เริ่มวันทำงานของคุณ'), findsOneWidget);
      await t.ensureVisible(find.text('ทดลองใช้งานก่อนเข้าสู่ระบบ'));
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      c.dispose();
    });
  }
}
