import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nwl_secret_login/core/controller.dart';
import 'package:nwl_secret_login/core/models.dart';
import 'package:nwl_secret_login/ui/app.dart';
import 'package:nwl_secret_login/ui/login_motion.dart';
import 'package:nwl_secret_login/ui/login_motion_abstract.dart';

void main() {
  setUpAll(() async {
    for (final family in ['NotoSans', 'NotoSansThai']) {
      final loader = FontLoader(family)
        ..addFont(rootBundle.load('assets/$family-Regular.ttf'))
        ..addFont(rootBundle.load('assets/$family-Bold.ttf'));
      await loader.load();
    }
  });
  testWidgets('abstract artwork is confined to the preview route', (t) async {
    await t.pumpWidget(const MaterialApp(home: LoginMotionPreview()));
    await t.pump();
    expect(find.byType(AbstractLoginMotionPage), findsOneWidget);
    expect(find.byType(LoginMotionPage), findsNothing);
    await t.pumpWidget(
      const MaterialApp(home: LoginMotionPage(stage: LoginStage.connected)),
    );
    await t.pump();
    expect(find.byType(AbstractLoginMotionPage), findsNothing);
    expect(find.text('fuck u hono'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('abstract posters preserve type behind hands and fit mobile', (
    t,
  ) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    for (final stage in [LoginStage.connecting, LoginStage.connected]) {
      await t.pumpWidget(
        NwlApp(
          controller: AppController()..ready = true,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844),
              disableAnimations: true,
            ),
            child: AbstractLoginMotionPage(stage: stage),
          ),
        ),
      );
      await t.runAsync(() async {
        final context = t.element(find.byType(AbstractLoginMotionPage));
        await Future.wait([
          precacheImage(
            const AssetImage('assets/motion/login-hands.png'),
            context,
          ),
          precacheImage(
            const AssetImage('assets/motion/palm-rise.webp'),
            context,
          ),
          precacheImage(
            const AssetImage('assets/motion/abstract-glass.webp'),
            context,
          ),
        ]);
      });
      await t.pump();
      final type = find.byKey(const ValueKey('poster-type-layer'));
      final hand = find.byKey(
        ValueKey(
          stage == LoginStage.connected ? 'connected-hands' : 'reaching-hands',
        ),
      );
      final stack = find.ancestor(of: type, matching: find.byType(Stack)).first;
      final paints = find
          .descendant(of: stack, matching: find.byType(CustomPaint))
          .evaluate()
          .toList();
      expect(
        paints.indexOf(type.evaluate().single),
        lessThan(paints.indexOf(hand.evaluate().single)),
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('captures/abstract-${stage.name}.png'),
      );
      expect(t.takeException(), isNull);
    }
    await t.pumpWidget(const SizedBox());
  });
  for (final width in [320.0, 1440.0]) {
    testWidgets('abstract preview fits $width px with reduced motion', (
      t,
    ) async {
      t.view.physicalSize = Size(width, 720);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      for (final stage in [LoginStage.connecting, LoginStage.connected]) {
        await t.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 720),
                disableAnimations: true,
              ),
              child: AbstractLoginMotionPage(stage: stage),
            ),
          ),
        );
        await t.pump();
        expect(t.takeException(), isNull);
      }
      await t.pumpWidget(const SizedBox());
    });
  }
}
