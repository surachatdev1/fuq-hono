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
          .timeout(const Duration(seconds: 60));
      final j = jsonDecode(response.body) as Map<String, dynamic>;
      if (j['code'] == 'unknown') throw const UnknownOutcome();
      if (response.statusCode != 200) {
        throw AppFailure(
          j['message'] as String? ?? 'เว็บเชื่อมต่อระบบไม่สำเร็จ',
        );
      }
      return j;
    } on AppFailure {
      rethrow;
    } catch (_) {
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
  Future<AttendanceState> state(Session s) async {
    final j = await call('state');
    return AttendanceState(
      number(j, 'inTimeFlag'),
      number(j, 'showbothinout') == 1,
      number(j, 'facial_recog') == 1,
      (j['facial_method'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((r) => number(r, 'method_id'))
          .whereType<int>()
          .toList(),
      value(j, 'intime'),
      value(j, 'outtime'),
    );
  }

  @override
  Future<Enrollment> enrollment(Session s) async {
    await call('enrollment');
    return Enrollment(Uri.parse('https://localhost/'), '', '', '', 1, true);
  }

  void clearProof() {
    _jpeg?.fillRange(0, _jpeg!.length, 0);
    _jpeg = null;
    _proof = null;
  }

  @override
  Future<void> verify(Enrollment e, Uint8List jpeg) async {
    clearProof();
    final j = await call('verify', {'jpeg': base64Encode(jpeg)});
    _proof = j['proof'] as String;
    _jpeg = Uint8List.fromList(jpeg);
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
