import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nwl_secret_login/ui/app_icons.dart';

void main() {
  testWidgets('stroke icons remain square in stretched empty states', (
    t,
  ) async {
    await t.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [NwlIcon(Icons.history_rounded, size: 44)],
            ),
          ),
        ),
      ),
    );
    final painter = find.descendant(
      of: find.byType(NwlIcon),
      matching: find.byType(CustomPaint),
    );
    expect(t.getSize(painter), const Size(44, 44));
  });
}
