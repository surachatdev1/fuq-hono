import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nwl_secret_login/ui/web_permission_setup.dart';

void main() {
  testWidgets('permission setup explains required and optional access', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showDialog<bool>(
                  context: context,
                  builder: (_) => const WebPermissionSetupDialog(),
                ),
                child: const Text('Open setup'),
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('Open setup'));
    await t.pumpAndSettle();
    expect(find.text('เตรียมสิทธิ์ก่อนใช้งาน'), findsOneWidget);
    expect(find.text('กล้องหน้า'), findsOneWidget);
    expect(find.text('เสียงเตือนการลงเวลา'), findsOneWidget);
    expect(find.textContaining('ไม่ขอตำแหน่ง GPS'), findsOneWidget);
    expect(find.text('อนุญาตและตรวจกล้อง'), findsOneWidget);

    // VM tests use a platform stub: no permission prompt on test machines.
    await t.tap(find.text('อนุญาตและตรวจกล้อง'));
    await t.pumpAndSettle();
    expect(find.textContaining('เบราว์เซอร์นี้ไม่รองรับ'), findsOneWidget);
    await t.tap(find.text('เข้าใช้งานก่อน'));
    await t.pumpAndSettle();
    expect(find.text('เตรียมสิทธิ์ก่อนใช้งาน'), findsNothing);
  });
}
