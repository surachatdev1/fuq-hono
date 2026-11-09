import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nwl_secret_login/ui/early_checkout.dart';

void main() {
  test('early checkout warning stops exactly at 18:00 Bangkok wall time', () {
    expect(earlyCheckoutMinutes(DateTime(2026, 11, 9, 17, 30)), 30);
    expect(earlyCheckoutMinutes(DateTime(2026, 11, 9, 17, 59, 59)), 1);
    expect(earlyCheckoutMinutes(DateTime(2026, 11, 9, 18)), 0);
    expect(earlyCheckoutMinutes(DateTime(2026, 11, 9, 19)), 0);
  });

  for (final proceed in [false, true]) {
    testWidgets(
      'early checkout ${proceed ? 'confirmation' : 'cancellation'} returns explicit choice',
      (tester) async {
        bool? result;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: TextButton(
                    onPressed: () async {
                      result = await showDialog<bool>(
                        context: context,
                        builder: (_) => EarlyCheckoutDialog(
                          now: DateTime(2026, 11, 9, 17, 30),
                        ),
                      );
                    },
                    child: const Text('เปิด'),
                  ),
                );
              },
            ),
          ),
        );
        await tester.tap(find.text('เปิด'));
        await tester.pumpAndSettle();
        expect(find.textContaining('18:00'), findsOneWidget);
        expect(find.textContaining('30 นาที'), findsOneWidget);
        expect(result, isNull);
        await tester.tap(
          find.text(proceed ? 'ยืนยันและสแกนหน้า' : 'ยังไม่ออก'),
        );
        await tester.pumpAndSettle();
        expect(result, proceed);
      },
    );
  }
}
