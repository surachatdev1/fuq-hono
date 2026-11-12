import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nwl_secret_login/core/controller.dart';
import 'package:nwl_secret_login/core/models.dart';
import 'package:nwl_secret_login/data/hono.dart';
import 'package:nwl_secret_login/data/wire.dart';

class FailingVerificationApi extends HonoApi {
  FailingVerificationApi({this.failVerification = true})
    : super(
        WireCodec({
          'protocol_version': 'hono-22.9-323',
          'key': '1234567890abcdef',
          'iv': 'abcdef1234567890',
          'bootstrap_key': 'fixture',
        }),
      );
  final bool failVerification;
  static const staleState = AttendanceState(1, false, true, [], '', '');
  AttendanceState latestState = staleState;
  int historyReads = 0, writes = 0;
  @override
  Future<Enrollment> enrollment(Session s) async =>
      Enrollment(Uri.parse('https://example.test'), '', '', '', 1, true);
  @override
  Future<void> verify(Enrollment e, Uint8List jpeg) async {
    if (failVerification) {
      throw const AppFailure('ตรวจภาพไม่สำเร็จภายใน 30 วินาที');
    }
  }

  @override
  Future<AttendanceState> state(Session s) async => latestState;

  @override
  Future<List<ProcessedAttendanceDay>> processedMonth(
    Session s,
    DateTime month,
  ) async => [];

  @override
  Future<List<AttendanceEntry>> history(Session s, DateTime date) async {
    historyReads++;
    return [];
  }

  @override
  Future<void> submit(
    Session s,
    Place place,
    Punch punch,
    Uint8List png,
  ) async {
    writes++;
  }
}

void main() {
  test(
    'acknowledged check-in stays disabled while HONO history is empty',
    () async {
      final api = FailingVerificationApi(failVerification: false);
      const place = Place('Office', 18, 99, '');
      final c = AppController(api: api)
        ..session = Session(
          'https://example.test',
          'test',
          '1',
          'own',
          'Test',
          'fixture',
          'fixture',
          'fixture',
          true,
        )
        ..places = [place]
        ..state = FailingVerificationApi.staleState;
      addTearDown(c.dispose);
      Uint8List capture() => img.encodeJpg(img.Image(width: 16, height: 16));

      await c.submitFresh(
        capture(),
        DateTime.now(),
        Punch.checkIn,
        place,
        (_, __) {},
      );
      expect(c.logs, isEmpty);
      expect(c.checkedIn, isTrue);
      expect(c.canScanPunch(Punch.checkIn), isFalse);
      expect(c.canScanPunch(Punch.checkOut), isTrue);
      await expectLater(
        c.submitFresh(
          capture(),
          DateTime.now(),
          Punch.checkIn,
          place,
          (_, __) {},
        ),
        throwsA(isA<AppFailure>()),
      );
      expect(api.writes, 1);
      await c.submitFresh(
        capture(),
        DateTime.now(),
        Punch.checkOut,
        place,
        (_, __) {},
      );
      expect(api.writes, 2);
    },
  );

  test(
    'native submit checks whether the frozen work area still exists',
    () async {
      final api = FailingVerificationApi(failVerification: false)
        ..latestState = const AttendanceState(
          1,
          false,
          true,
          [],
          '',
          '',
          workLocations: [WorkLocation(18, 99, 150)],
        );
      final c = AppController(api: api)
        ..session = Session(
          'https://example.test',
          'psd',
          '1',
          'own',
          'Test',
          'fixture',
          'fixture',
          'fixture',
          true,
        );
      addTearDown(c.dispose);
      await c.refresh(includeProcessed: false);
      c.selectHonoPlace(0);
      final place = c.place!;
      api.latestState = const AttendanceState(
        1,
        false,
        true,
        [],
        '',
        '',
        workLocations: [WorkLocation(19, 99, 150)],
      );
      await expectLater(
        c.submitFresh(
          img.encodeJpg(img.Image(width: 16, height: 16)),
          DateTime.now(),
          Punch.checkIn,
          place,
          (_, __) {},
        ),
        throwsA(
          isA<AppFailure>().having(
            (e) => e.message,
            'message',
            contains('พื้นที่ลงเวลาของ HONO เปลี่ยนแล้ว'),
          ),
        ),
      );
      expect(api.writes, 0);
    },
  );

  test(
    'verification timeout is returned immediately without refreshing or writing',
    () async {
      final api = FailingVerificationApi();
      const place = Place('Office', 18, 99, '');
      final c = AppController(api: api)
        ..session = Session(
          'https://example.test',
          'test',
          '1',
          'own',
          'Test',
          'fixture',
          'fixture',
          'fixture',
          true,
        )
        ..places = [place]
        ..state = const AttendanceState(1, true, true, [], '', '');
      final bytes = Uint8List.fromList(
        img.encodeJpg(img.Image(width: 16, height: 16)),
      );
      await expectLater(
        c.submitFresh(bytes, DateTime.now(), Punch.checkIn, place, (_, __) {}),
        throwsA(isA<AppFailure>()),
      );
      expect(api.historyReads, 0);
      expect(api.writes, 0);
      expect(c.busy, false);
      expect(bytes.every((b) => b == 0), true);
      c.dispose();
    },
  );
}
