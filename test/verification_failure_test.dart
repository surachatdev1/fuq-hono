import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nwl_secret_login/core/controller.dart';
import 'package:nwl_secret_login/core/models.dart';
import 'package:nwl_secret_login/data/hono.dart';
import 'package:nwl_secret_login/data/wire.dart';

class FailingVerificationApi extends HonoApi {
  FailingVerificationApi()
    : super(
        WireCodec({
          'protocol_version': 'hono-22.9-323',
          'key': '1234567890abcdef',
          'iv': 'abcdef1234567890',
          'bootstrap_key': 'fixture',
        }),
      );
  int historyReads = 0, writes = 0;
  @override
  Future<Enrollment> enrollment(Session s) async =>
      Enrollment(Uri.parse('https://example.test'), '', '', '', 1, true);
  @override
  Future<void> verify(Enrollment e, Uint8List jpeg) async =>
      throw const AppFailure('ตรวจภาพไม่สำเร็จภายใน 30 วินาที');
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
