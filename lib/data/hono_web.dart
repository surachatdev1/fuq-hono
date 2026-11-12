import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/browser_client.dart';
import '../core/models.dart';
import 'hono.dart';
import 'wire.dart';

HonoApi createApi(Map<String, dynamic> material) => WebHonoApi(material);

// Provider tokens and enrollment keys never cross the same-origin API boundary.
class WebHonoApi extends HonoApi {
  WebHonoApi(Map<String, dynamic> material) : super(WireCodec(material));
  final browser = BrowserClient()..withCredentials = true;
  Uint8List? _jpeg;
  String? _proof;
  ({int historyCount, bool checkIn, bool checkOut})? _verifiedAttendance;
  // Fire-and-forget diagnostics are deliberately data-free and never block a login.
  Future<void> _reportBrowserFailure(String route, String kind) async {
    final collector = BrowserClient();
    try {
      await collector
          .post(
            Uri.base.resolve('/api/client-event'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'targetRoute': route, 'kind': kind}),
          )
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      // The browser may be offline or Safari may reject the request entirely.
    } finally {
      collector.close();
    }
  }

  Future<Map<String, dynamic>> call(
    String route, [
    Map<String, dynamic> body = const {},
  ]) async {
    try {
      final response = await browser
          .post(
            Uri.base.resolve('/api/$route'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(Duration(seconds: route == 'verify' ? 30 : 60));
      Map<String, dynamic> j;
      try {
        j = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        unawaited(_reportBrowserFailure(route, 'invalid_response'));
        throw AppFailure(
          'เซิร์ฟเวอร์ตอบกลับผิดรูปแบบ (HTTP ${response.statusCode}) '
          'กรุณาลองใหม่หรือติดต่อผู้ดูแล',
        );
      }
      if (j['code'] == 'unknown') throw const UnknownOutcome();
      if (response.statusCode != 200) {
        final message = j['message'] as String? ?? 'เว็บเชื่อมต่อระบบไม่สำเร็จ';
        final id = j['requestId'] is String
            ? j['requestId'] as String
            : response.headers['x-request-id'];
        throw AppFailure(
          id == null || id.isEmpty
              ? '$message (HTTP ${response.statusCode})'
              : '$message (HTTP ${response.statusCode}) · รหัสตรวจสอบ: $id',
        );
      }
      return j;
    } on AppFailure {
      rethrow;
    } on TimeoutException {
      unawaited(_reportBrowserFailure(route, 'timeout'));
      if (route == 'verify') {
        throw const AppFailure('ตรวจภาพไม่สำเร็จภายใน 30 วินาที กรุณาสแกนใหม่');
      }
      throw const AppFailure('เชื่อมต่อเว็บไม่สำเร็จ กรุณาลองใหม่');
    } catch (_) {
      unawaited(_reportBrowserFailure(route, 'network_failure'));
      throw const AppFailure('เชื่อมต่อเว็บไม่สำเร็จ กรุณาลองใหม่');
    }
  }

  @override
  Future<Session> login(
    String company,
    String employee,
    String password,
    String deviceId,
  ) async {
    final j = await call('login', {
      'company': company,
      'employee': employee,
      'password': password,
    });
    return Session(
      '',
      j['company'] as String,
      'web',
      j['employee'] as String,
      j['name'] as String,
      'web',
      'web',
      'web',
      true,
      calendarKey: 'web',
    );
  }

  @override
  Future<List<AttendanceEntry>> history(Session s, DateTime date) async =>
      HonoApi.parseHistory(
        await call('history', {'date': HonoApi.dateKey(date)}),
        s.employee,
      );
  @override
  Future<List<ProcessedAttendanceDay>> processedMonth(
    Session s,
    DateTime month,
  ) async => HonoApi.parseProcessedCalendar(
    await call('calendar', {'date': HonoApi.dateKey(month)}),
    s.employee,
    month,
  );
  @override
  Future<AttendanceState> state(Session s) async =>
      HonoApi.parseAttendanceState(await call('state'));

  @override
  Future<Enrollment> enrollment(Session s) async {
    // /verify loads and validates enrollment within its shared 30-second budget.
    return Enrollment(Uri.parse('https://localhost/'), '', '', '', 1, true);
  }

  void clearProof() {
    _jpeg?.fillRange(0, _jpeg!.length, 0);
    _jpeg = null;
    _proof = null;
    _verifiedAttendance = null;
  }

  @override
  Future<void> verify(Enrollment e, Uint8List jpeg) async {
    clearProof();
    final j = await call('verify', {'jpeg': base64Encode(jpeg)});
    final attendance = j['attendance'];
    if (attendance case {
      'historyCount': final int count,
      'checkIn': final bool checkIn,
      'checkOut': final bool checkOut,
    } when count >= 0) {
      _verifiedAttendance = (
        historyCount: count,
        checkIn: checkIn,
        checkOut: checkOut,
      );
    } else if (attendance != null) {
      throw const AppFailure('สถานะลงเวลาจากระบบไม่ครบ กรุณาสแกนใหม่');
    }
    _proof = j['proof'] as String;
    _jpeg = Uint8List.fromList(jpeg);
  }

  @override
  Future<void> confirmAttendanceAfterVerification(
    Session session,
    Punch punch,
    DateTime date,
    int knownHistoryCount,
  ) async {
    final attendance = _verifiedAttendance;
    if (attendance == null) {
      // Older deployments only return the proof.
      return super.confirmAttendanceAfterVerification(
        session,
        punch,
        date,
        knownHistoryCount,
      );
    }
    final allowed = punch == Punch.checkIn
        ? attendance.checkIn
        : attendance.checkOut;
    if (!allowed || attendance.historyCount > knownHistoryCount) {
      clearProof();
      throw const AttendanceChanged();
    }
  }

  @override
  Future<void> submit(
    Session s,
    Place place,
    Punch punch,
    Uint8List png,
  ) async {
    if (_jpeg == null || _proof == null) {
      throw const AppFailure('กรุณาสแกนใหม่');
    }
    try {
      await call('submit', {
        'proof': _proof,
        'jpeg': base64Encode(_jpeg!),
        'lat': place.lat,
        'lng': place.lng,
        'punch': punch.wire,
      });
    } on AppFailure catch (e) {
      // A missing response after POST is never interpreted as permission to resend.
      if (e.message == 'เชื่อมต่อเว็บไม่สำเร็จ กรุณาลองใหม่') {
        throw const UnknownOutcome();
      }
      rethrow;
    } finally {
      clearProof();
    }
  }

  @override
  Future<void> signOut() async {
    clearProof();
    await call('logout');
  }

  @override
  void close() {
    clearProof();
    browser.close();
    super.close();
  }
}
