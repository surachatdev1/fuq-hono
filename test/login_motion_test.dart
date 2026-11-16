import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nwl_secret_login/core/controller.dart';
import 'package:nwl_secret_login/core/models.dart';
import 'package:nwl_secret_login/data/hono.dart';
import 'package:nwl_secret_login/data/wire.dart';
import 'package:nwl_secret_login/ui/app.dart';
import 'package:nwl_secret_login/ui/login_motion.dart';

class PendingLoginApi extends HonoApi {
  PendingLoginApi()
    : super(
        WireCodec({
          'protocol_version': 'hono-22.9-323',
          'key': '1234567890abcdef',
          'iv': 'abcdef1234567890',
          'bootstrap_key': 'fixture',
        }),
      );
  final result = Completer<Session>();
  int attempts = 0;
  List<WorkLocation>? workLocations;
  @override
  Future<Session> login(
    String company,
    String employee,
    String password,
    String device,
  ) {
    attempts++;
    return result.future;
  }

  @override
  Future<List<AttendanceEntry>> history(Session s, DateTime date) async => [];
  @override
  Future<AttendanceState> state(Session s) async => AttendanceState(
    1,
    false,
    true,
    [1],
    '',
    '',
    workLocations: workLocations,
  );
  @override
  Future<List<ProcessedAttendanceDay>> processedMonth(
    Session s,
    DateTime date,
  ) async => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({
      'installation': 'fixture-install',
    });
  });
  test(
    'remembered HONO coordinates are scoped to the signed-in account',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('hono_place_v1.["fixture","owner"]', '[18.0,99.0]');
      Future<AppController> signIn(
        String employee,
        List<WorkLocation> locations,
      ) async {
        final api = PendingLoginApi()..workLocations = locations;
        api.result.complete(
          Session(
            '',
            'fixture',
            '1',
            employee,
            'Fixture',
            'token',
            'key',
            'face',
            true,
          ),
        );
        final controller = AppController(api: api)
          ..places = [Place.thaiCcTower];
        addTearDown(controller.dispose);
        expect(
          await controller.login(
            'fixture',
            employee,
            'fixture',
            false,
            skipMotionDelay: true,
          ),
          isTrue,
        );
        return controller;
      }

      const location = WorkLocation(18, 99, 150);
      final owner = await signIn('owner', [location]);
      expect(owner.place?.fromHono, isTrue);
      expect(owner.place?.lat, 18);
      final other = await signIn('other', [location]);
      expect(other.place, Place.thaiCcTower);
      final revoked = await signIn('owner', [const WorkLocation(19, 99, 150)]);
      expect(revoked.place, isNull);
      expect(revoked.canScan, isFalse);
    },
  );
  testWidgets(
    'failed authentication removes waiting overlay without showing success',
    (t) async {
      final api = PendingLoginApi();
      final controller = AppController(api: api)..ready = true;
      await t.pumpWidget(NwlApp(controller: controller));
      final login = controller.login('fixture', 'owner', 'password', false);
      await t.pump();
      expect(controller.loginStage, LoginStage.connecting);
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'connecting people',
        ),
        findsOneWidget,
      );
      expect(
        await controller.login('fixture', 'owner', 'password', false),
        false,
      );
      expect(api.attempts, 1);
      api.result.completeError(const AppFailure('ไม่สำเร็จ'));
      await t.pump();
      expect(await login, false);
      expect(controller.session, isNull);
      expect(controller.loginStage, LoginStage.idle);
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'fuck u hono',
        ),
        findsNothing,
      );
      expect(find.byType(LoginMotionPage), findsNothing);
      await t.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
  testWidgets(
    'success touches, dissolves and lifts the palm before continuing once to home',
    (t) async {
      final api = PendingLoginApi();
      final c = AppController(api: api)..ready = true;
      await t.pumpWidget(NwlApp(controller: c));
      final login = c.login('fixture', 'owner', 'password', false);
      await t.pump();
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'fuck u hono',
        ),
        findsNothing,
      );
      api.result.complete(
        Session(
          '',
          'fixture',
          '1',
          'owner',
          'Fixture',
          'token',
          'key',
          'face',
          true,
          calendarKey: 'calendar',
        ),
      );
      await t.pump();
      await t.pump();
      expect(c.loginStage, LoginStage.contact);
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'connecting people',
        ),
        findsOneWidget,
      );
      await t.pump(const Duration(milliseconds: 500));
      expect(c.loginStage, LoginStage.connected);
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'fuck u hono',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('reaching-hands')), findsNothing);
      expect(find.byKey(const ValueKey('connected-hands')), findsOneWidget);
      final caption = find.ancestor(
        of: find.text('เชื่อมต่อสำเร็จ กำลังเปิดหน้าหลัก'),
        matching: find.byType(FadeTransition),
      );
      expect(t.widget<FadeTransition>(caption).opacity.value, 0);
      await t.pump(const Duration(milliseconds: 1400));
      expect(t.widget<FadeTransition>(caption).opacity.value, greaterThan(0));
      expect(t.widget<FadeTransition>(caption).opacity.value, lessThan(1));
      await t.pump(const Duration(milliseconds: 900));
      expect(t.widget<FadeTransition>(caption).opacity.value, 1);
      await t.pump(const Duration(milliseconds: 1000));
      await t.pump();
      expect(c.loginStage, LoginStage.idle);
      expect(find.byType(LoginMotionPage), findsNothing);
      await t.pump();
      expect(await login, true);
      expect(api.attempts, 1);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
  testWidgets('review controls remain accessible and never create a session', (
    t,
  ) async {
    final semantics = t.ensureSemantics();

    await t.pumpWidget(const MaterialApp(home: LoginMotionPreview()));
    await t.pump();
    expect(t.getSemantics(find.text('สำเร็จ')).label, 'สำเร็จ');
    await t.tap(find.text('สำเร็จ'));
    await t.pump();
    expect(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'fuck u hono',
      ),
      findsOneWidget,
    );
    await t.tap(find.text('กำลังเชื่อมต่อ'));
    await t.pump();
    expect(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'connecting people',
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'fuck u hono',
      ),
      findsNothing,
    );
    await t.pumpWidget(const SizedBox());
    semantics.dispose();
  });
  for (final width in [320.0, 1440.0]) {
    testWidgets(
      'motion fits $width px and reduced-motion shows the final state',
      (t) async {
        t.view.physicalSize = Size(width, 720);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        Widget frame(LoginStage stage) => MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 720),
              disableAnimations: true,
            ),
            child: LoginMotionPage(stage: stage),
          ),
        );
        await t.pumpWidget(frame(LoginStage.connecting));
        await t.pump();
        expect(
          find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.label == 'connecting people',
          ),
          findsOneWidget,
        );
        expect(t.takeException(), isNull);
        await t.pumpWidget(frame(LoginStage.connected));
        await t.pump();
        expect(
          find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.label == 'fuck u hono',
          ),
          findsOneWidget,
        );
        expect(
          find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.label == 'connecting people',
          ),
          findsNothing,
        );
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      },
    );
  }
}
