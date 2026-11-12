import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../core/models.dart';
import 'wire.dart';

String value(Map<String, dynamic> j, String k) => j[k]?.toString().trim() ?? '';
int? number(Map<String, dynamic> j, String k) => int.tryParse(value(j, k));
bool truth(Object? o) => o.toString().toLowerCase() == 'true';
void requireResult(Map<String, dynamic> j) {
  if (!truth(j['result'])) {
    throw const AppFailure('HONO ปฏิเสธรายการ กรุณาตรวจบัญชีและสิทธิ์');
  }
}

class Session {
  Session(
    this.base,
    this.company,
    this.php,
    this.employee,
    this.name,
    this.token,
    this.markKey,
    this.faceKey,
    this.legacy, {
    this.calendarKey = '',
  });
  final String base, company, php, employee, name, token, markKey, faceKey;
  final bool legacy;
  final String calendarKey;
  Map<String, String> get common => {
    'comp_code': company,
    'api_key': markKey,
    'userid': employee,
    'token': token,
  };
}

class Enrollment {
  Enrollment(
    this.endpoint,
    this.key,
    this.group,
    this.person,
    this.threshold,
    this.spoof,
  );
  final Uri endpoint;
  final String key, group, person;
  final double threshold;
  final bool spoof;
  factory Enrollment.parse(Map<String, dynamic> j) {
    requireResult(j);
    String required(String k) {
      final s = value(j, k);
      if (s.isEmpty || s == 'null') {
        throw const AppFailure('ข้อมูลยืนยันใบหน้าไม่ครบ');
      }
      return s;
    }

    final endpoint = Uri.parse(required('FacialEndPoint'));
    final host = endpoint.host;
    if (endpoint.scheme != 'https' ||
        endpoint.port != 443 ||
        endpoint.userInfo.isNotEmpty ||
        endpoint.hasQuery ||
        endpoint.hasFragment ||
        !(host.endsWith('.cognitiveservices.azure.com') ||
            host.endsWith('.api.cognitive.microsoft.com')) ||
        !['/', '', '/face/v1.0', '/face/v1.0/'].contains(endpoint.path)) {
      throw const AppFailure('ปลายทางยืนยันใบหน้าไม่รองรับ');
    }
    final threshold = double.tryParse(required('Facialthreshold'));
    final person = required('PersonID');
    final spoof = required('spoof');
    if (threshold == null ||
        !threshold.isFinite ||
        threshold < 0 ||
        threshold > 1 ||
        !RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
        ).hasMatch(person) ||
        !['0', '1'].contains(spoof)) {
      throw const AppFailure('เกณฑ์ยืนยันใบหน้าไม่ถูกต้อง');
    }
    return Enrollment(
      endpoint,
      required('FacialSubscription'),
      required('GroupID'),
      person,
      threshold,
      spoof == '1',
    );
  }
}

class HonoApi {
  HonoApi(this.codec, {http.Client? client})
    : _client = client ?? http.Client();
  final WireCodec codec;
  final http.Client _client;
  void close() => _client.close();
  Future<void> signOut() async {}
  Future<dynamic> _send(http.BaseRequest request) async {
    request.followRedirects = false;
    try {
      return await (() async {
        final reply = await _client.send(request);
        if (reply.statusCode != 200) {
          throw const AppFailure('ระบบตอบกลับไม่สำเร็จ กรุณาลองใหม่');
        }
        final bytes = <int>[];
        await for (final chunk in reply.stream) {
          bytes.addAll(chunk);
          if (bytes.length > 2000000) {
            throw const AppFailure('ข้อมูลตอบกลับเกินขนาด');
          }
        }
        try {
          return jsonDecode(utf8.decode(bytes));
        } catch (_) {
          throw const AppFailure('รูปแบบข้อมูลจากระบบไม่ถูกต้อง');
        }
      })().timeout(const Duration(seconds: 30));
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const AppFailure('เชื่อมต่อไม่สำเร็จ ตรวจอินเทอร์เน็ตแล้วลองใหม่');
    }
  }

  Future<Map<String, dynamic>> _get(
    String endpoint,
    Map<String, String> fields,
    String php, {
    bool bootstrap = false,
  }) async {
    final inner = WireCodec.query(endpoint, fields);
    final uri = Uri.parse(endpoint).replace(
      queryParameters: {
        'encryption_key': bootstrap
            ? codec.hex(inner)
            : codec.encode(inner, php),
        'type': 'android',
      },
    );
    final j = await _send(http.Request('GET', uri));
    if (j is! Map<String, dynamic>) {
      throw const AppFailure('ข้อมูลจากระบบไม่ถูกต้อง');
    }
    return j;
  }

  Future<dynamic> _post(
    Uri uri,
    Object payload, {
    Map<String, String>? headers,
    bool binary = false,
  }) {
    final r = http.Request('POST', uri)..headers.addAll(headers ?? {});
    if (binary) {
      r.headers['Content-Type'] = 'application/octet-stream';
      r.bodyBytes = payload as List<int>;
    } else {
      r.headers['Content-Type'] = 'application/json';
      r.body = jsonEncode(payload);
    }
    return _send(r);
  }

  Future<Session> login(
    String company,
    String employee,
    String password,
    String deviceId,
  ) async {
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9-]{0,62}$').hasMatch(company) ||
        employee.isEmpty ||
        password.isEmpty) {
      throw const AppFailure('กรอกรหัสบริษัท รหัสพนักงาน และรหัสผ่าน');
    }
    const bootstrap =
        'https://api.honohr.com/sapi/Service/getCompanyLogo_ml_v2';
    final config = await _get(
      bootstrap,
      {'comp_code': company, 'version': '35'},
      '0',
      bootstrap: true,
    );
    requireResult(config);
    if ((number(config, 'sso') ?? 0) != 0) {
      throw const AppFailure('บริษัทนี้ใช้ SSO กรุณาใช้ HONO เดิม');
    }
    final comp = value(config, 'companycode');
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9-]{0,62}$').hasMatch(comp)) {
      throw const AppFailure('รหัสบริษัทไม่ถูกต้อง');
    }
    final theme = number(config, 'mobileTheme');
    final domain = theme == 1
        ? value(config, 'domain_name')
        : 'honohr.com/sapi/';
    if (domain.contains(RegExp(r'[?#@\\]'))) {
      throw const AppFailure('โดเมนบริษัทไม่รองรับ');
    }
    final base = 'https://$comp.${domain}Service/';
    final uri = Uri.parse(base);
    if (uri.scheme != 'https' ||
        uri.port != 443 ||
        uri.userInfo.isNotEmpty ||
        !(uri.host.endsWith('.hono.ai') || uri.host.endsWith('.honohr.com'))) {
      throw const AppFailure('โดเมนบริษัทไม่รองรับ');
    }
    final php = value(config, 'phpversion');
    final function = value(config, 'loginfunction');
    if (!RegExp(r'^[A-Za-z0-9_/-]+$').hasMatch(function) ||
        function.startsWith('/') ||
        function.contains('..')) {
      throw const AppFailure('วิธีเข้าสู่ระบบไม่รองรับ');
    }
    final keys = await _get('${base}dynamicAPIKeys_v2', {
      'comp_code': comp,
      'api_key': codec.bootstrap,
    }, php);
    requireResult(keys);
    final apiKeys = keys['api_keys'] as Map<String, dynamic>? ?? {};
    if (value(apiKeys, 'LOGIN').isEmpty) {
      throw const AppFailure('ไม่พบสิทธิ์เข้าสู่ระบบ');
    }
    final endpoint = '$base$function';
    final inner = WireCodec.query(endpoint, {
      'comp_code': comp,
      'api_key': value(apiKeys, 'LOGIN'),
      'userid': employee,
      'pass': php == '1' ? password : codec.hex(password),
      'iemi_no': deviceId,
      'lang_id': '1',
    });
    final raw = await _post(Uri.parse(endpoint), {
      'type': 'android',
      'encryption_key': codec.encode(inner, php),
    });
    if (raw is! Map<String, dynamic>) {
      throw const AppFailure('ข้อมูลบัญชีไม่ถูกต้อง');
    }
    requireResult(raw);
    if ((number(raw, 'authmfa') ?? 0) != 0) {
      throw const AppFailure('บัญชีต้องยืนยัน MFA ผ่าน HONO เดิม');
    }
    for (final key in ['ResetPasswordFlag', 'COCFlagV2']) {
      if (value(raw, key) == '1' || truth(raw[key])) {
        throw const AppFailure(
          'โปรดยืนยันเงื่อนไขหรือเปลี่ยนรหัสผ่านใน HONO เดิม',
        );
      }
    }
    final token = value(raw, 'tokenID'), code = value(raw, 'Usercode');
    if (token.isEmpty ||
        token == 'null' ||
        code.isEmpty ||
        code == 'null' ||
        (theme == 1 && raw['rolecheck'] == null)) {
      throw const AppFailure('ข้อมูล session ไม่ครบ');
    }
    return Session(
      base,
      comp,
      php,
      code,
      value(raw, 'Username').isEmpty ? code : value(raw, 'Username'),
      token,
      value(apiKeys, 'MARKIN_MARKOUT'),
      value(apiKeys, 'FACIAL_RECOG'),
      number(config, 'honoapp_facial') == 0,
      calendarKey: value(apiKeys, 'CALENDAR'),
    );
  }

  static String dateKey(DateTime now) =>
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  Future<List<AttendanceEntry>> history(Session s, DateTime date) async {
    final j = await _get('${s.base}UserVisitFetchRecords_v2', {
      'comp_code': s.company,
      'api_key': s.markKey,
      'userid': s.employee,
      'punchdate': dateKey(date),
      'token': s.token,
      'mngr_code': s.employee,
    }, s.php);
    return parseHistory(j, s.employee);
  }

  Future<List<ProcessedAttendanceDay>> processedMonth(
    Session s,
    DateTime month,
  ) async {
    if (s.calendarKey.isEmpty) {
      throw const AppFailure('เข้าสู่ระบบใหม่เพื่ออ่านปฏิทินหลังประมวลผล');
    }
    final first = DateTime(month.year, month.month),
        last = DateTime(month.year, month.month + 1, 0);
    final endpoint = Uri.parse(
      s.base,
    ).resolve('../CalendarMaster/showCalendar_v2').toString();
    final j = await _get(endpoint, {
      'comp_code': s.company,
      'api_key': s.calendarKey,
      'emp_code': s.employee,
      'from_date': dateKey(first),
      'to_date': dateKey(last),
      'role': 'Employee',
      'loggedin_user': s.employee,
      'token': s.token,
    }, '1');
    return parseProcessedCalendar(j, s.employee, month);
  }

  static List<ProcessedAttendanceDay> parseProcessedCalendar(
    Map<String, dynamic> j,
    String owner,
    DateTime month,
  ) {
    requireResult(j);
    dynamic rows = j['show_calendar'];
    if (rows is String) {
      rows = jsonDecode(rows);
    }
    if (rows is! List) {
      throw const AppFailure('ไม่พบปฏิทินหลังประมวลผล');
    }
    if (j['emp_code'] != null && value(j, 'emp_code') != owner) {
      throw const AppFailure('ปฏิทินไม่ตรงกับบัญชี');
    }
    final seen = <String>{};
    return rows.map((r) {
      if (r is! Map<String, dynamic> ||
          (r['emp_code'] != null && value(r, 'emp_code') != owner)) {
        throw const AppFailure('ปฏิทินไม่ตรงกับบัญชี');
      }
      final key = value(r, 'start');
      if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(key)) {
        throw const AppFailure('วันที่ในปฏิทินไม่ถูกต้อง');
      }
      final date = DateTime.tryParse(key);
      if (date == null ||
          dateKey(date) != key ||
          date.year != month.year ||
          date.month != month.month ||
          !seen.add(key)) {
        throw const AppFailure('ปฏิทินไม่ตรงเดือนที่เลือกหรือมีวันที่ซ้ำ');
      }
      if (!r.containsKey('startTime') || !r.containsKey('endTime')) {
        throw const AppFailure('เวลาในปฏิทินไม่ครบ');
      }
      return ProcessedAttendanceDay(
        date,
        inTime: value(r, 'startTime'),
        outTime: value(r, 'endTime'),
        status: value(r, 'status'),
        holiday: value(r, 'isHoliday') == '1' || value(r, 'isWeeklyOff') == '1',
        pending: value(r, 'typeOfAwaitingApproval').isNotEmpty,
      );
    }).toList();
  }

  static List<AttendanceEntry> parseHistory(
    Map<String, dynamic> j,
    String owner,
  ) {
    final rows = j['data'];
    if (!truth(j['result'])) {
      // A no-record reply is not proof of a holiday. Authentication/permission
      // errors must remain errors, even when accompanied by data: [].
      final message = [
        'error',
        'message',
        'msg',
      ].map((k) => value(j, k)).join(' ').toLowerCase();
      final noRows = rows == null || (rows is List && rows.isEmpty);
      final denied = RegExp(
        r'token|session|auth|permission|unauthori|forbidden|expired|สิทธิ|หมดอายุ',
      ).hasMatch(message);
      final emptyMessage = RegExp(
        r'no\s+(?:data|records?)\b|(?:data|records?)\s+not\s+found|ไม่พบข้อมูล|ไม่มีรายการ',
      ).hasMatch(message);
      if (noRows && !denied && emptyMessage) return [];
      throw const AppFailure(
        'HONO ไม่คืนประวัติของวันที่เลือก กรุณาโหลดใหม่หรือตรวจสิทธิ์',
      );
    }
    if (rows is! List) throw const AppFailure('ไม่พบข้อมูลประวัติ');
    return rows.map((row) {
      if (row is! Map<String, dynamic> ||
          value(row, 'emp_code') != owner ||
          value(row, 'punch_time').isEmpty) {
        throw const AppFailure('รายการไม่ตรงกับบัญชีที่เข้าสู่ระบบ');
      }
      return AttendanceEntry(
        value(row, 'flag'),
        value(row, 'punch_time'),
        number(row, 'status'),
      );
    }).toList();
  }

  Future<AttendanceState> state(Session s) async {
    final j = await _get('${s.base}checkForAttMethod_v2', s.common, s.php);
    requireResult(j);
    return parseAttendanceState(j);
  }

  static AttendanceState parseAttendanceState(Map<String, dynamic> j) {
    final methods = (j['facial_method'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map((m) => number(m, 'method_id'))
        .whereType<int>()
        .toList();
    final rows = j['work_location_lat_long'];
    List<WorkLocation>? locations;
    if (rows is List) {
      final valid = List<WorkLocation>.unmodifiable(
        rows.map(WorkLocation.fromJson).whereType<WorkLocation>(),
      );
      if (rows.isEmpty || valid.isNotEmpty) locations = valid;
    }
    return AttendanceState(
      number(j, 'inTimeFlag'),
      number(j, 'showbothinout') == 1,
      number(j, 'facial_recog') == 1,
      methods,
      value(j, 'intime'),
      value(j, 'outtime'),
      workLocations: locations,
      checkInRecorded: j['check_in_recorded'] == true,
    );
  }

  Future<void> confirmAttendanceAfterVerification(
    Session session,
    Punch punch,
    DateTime date,
    int knownHistoryCount, {
    required Place place,
    bool confirmedCheckIn = false,
  }) async {
    final latestState = await state(session);
    final latestHistory = await history(session, date);
    final allowed = confirmedCheckIn
        ? punch == Punch.checkOut
        : latestState.allows(punch, latestHistory);
    if (!latestState.face ||
        !allowed ||
        latestHistory.length > knownHistoryCount) {
      throw const AttendanceChanged();
    }
    if (place.fromHono &&
        latestState.workLocations?.any((area) => area.matches(place)) != true) {
      throw const AppFailure(
        'พื้นที่ลงเวลาของ HONO เปลี่ยนแล้ว กรุณาเลือกใหม่',
      );
    }
  }

  Future<Enrollment> enrollment(Session s) async {
    if (!s.legacy || s.faceKey.isEmpty) {
      throw const AppFailure('ยังไม่รองรับวิธียืนยันใบหน้าของบริษัทนี้');
    }
    final endpoint =
        '${s.base.substring(0, s.base.length - 'Service/'.length)}FacialMaster/getPersonFace_v2';
    return Enrollment.parse(
      await _get(endpoint, {
        'comp_code': s.company,
        'api_key': s.faceKey,
        'emp_code': s.employee,
        'token': s.token,
      }, s.php),
    );
  }

  Future<void> verify(Enrollment e, Uint8List jpeg) async {
    if (jpeg.length < 3 ||
        jpeg.length > 6000000 ||
        jpeg[0] != 255 ||
        jpeg[1] != 216 ||
        jpeg[2] != 255) {
      throw const AppFailure('ภาพจากกล้องไม่ถูกต้อง');
    }
    if (e.spoof) {
      final j = await _post(
        Uri.parse('https://devgpt.honohr.com/attendance/checkSpoofing/'),
        {'imageselect': base64Encode(jpeg)},
      );
      if (j is! Map || !truth(j['status'])) {
        throw const AppFailure('ภาพไม่ผ่านการตรวจ spoofing กรุณาสแกนใหม่');
      }
    }
    final headers = {'Ocp-Apim-Subscription-Key': e.key};
    final faces = await _post(
      e.endpoint.replace(
        path: '/face/v1.0/detect',
        queryParameters: {
          'returnFaceId': 'true',
          'returnFaceLandmarks': 'false',
        },
      ),
      jpeg,
      headers: headers,
      binary: true,
    );
    if (faces is! List || faces.length != 1 || faces.first is! Map) {
      throw const AppFailure('ต้องพบใบหน้าเพียงคนเดียว');
    }
    final faceId = faces.first['faceId'];
    if (faceId is! String || faceId.isEmpty) {
      throw const AppFailure('ไม่พบ Face ID');
    }
    final matches = await _post(
      e.endpoint.replace(path: '/face/v1.0/identify'),
      {
        'personGroupId': e.group,
        'faceIds': [faceId],
        'maxNumOfCandidatesReturned': 1,
        'confidenceThreshold': .5,
      },
      headers: headers,
    );
    if (matches is! List ||
        matches.length != 1 ||
        matches.first is! Map ||
        matches.first['faceId'] != faceId) {
      throw const AppFailure('ผลยืนยันไม่ตรงกับภาพที่ส่ง');
    }
    final candidates = matches.first['candidates'];
    if (candidates is! List || candidates.isEmpty || candidates.first is! Map) {
      throw const AppFailure('ไม่พบใบหน้าที่ลงทะเบียน');
    }
    final c = candidates.first as Map;
    final confidence = double.tryParse(c['confidence'].toString());
    if (c['personId'].toString().toLowerCase() != e.person.toLowerCase() ||
        confidence == null ||
        !confidence.isFinite ||
        confidence < 0 ||
        confidence > 1 ||
        confidence * 100 <= companyThresholdPercent(e.threshold)) {
      throw const AppFailure(
        'ใบหน้าไม่ตรงกับบัญชีหรือความมั่นใจต่ำกว่าเกณฑ์บริษัท',
      );
    }
  }

  Future<void> submit(
    Session s,
    Place place,
    Punch punch,
    Uint8List? png,
  ) async {
    if (!place.lat.isFinite ||
        !place.lng.isFinite ||
        place.lat.abs() > 90 ||
        place.lng.abs() > 180 ||
        png == null ||
        png.length < 8 ||
        png.length > 6000000 ||
        ![
          137,
          80,
          78,
          71,
          13,
          10,
          26,
          10,
        ].asMap().entries.every((e) => png[e.key] == e.value)) {
      throw const AppFailure('ข้อมูลลงเวลาไม่ถูกต้อง');
    }
    final request =
        http.MultipartRequest(
            'POST',
            Uri.parse('${s.base}UserVisitProfileImage'),
          )
          ..fields.addAll({
            'comp_code': s.company,
            'api_key': s.markKey,
            'userid': s.employee,
            'status': '1',
            'punch': punch.wire,
            'lat': place.lat.toString(),
            'lng': place.lng.toString(),
          })
          ..files.add(
            http.MultipartFile.fromBytes(
              'profile_image_url',
              png,
              filename: 'capture.png',
              contentType: MediaType('image', 'png'),
            ),
          );
    dynamic reply;
    try {
      reply = await _send(request);
    } catch (_) {
      throw const UnknownOutcome();
    }
    if (reply is Map && truth(reply['result'])) return;
    if (reply is Map && reply['result'].toString().toLowerCase() == 'false') {
      throw const AppFailure('HONO ปฏิเสธการลงเวลา กรุณาตรวจประวัติ');
    }
    throw const UnknownOutcome();
  }
}

// The Android client rounds each operation to IEEE float32 before truncating.
// Double multiplication can incorrectly turn a 58% threshold into 57%.
int companyThresholdPercent(double threshold) {
  final bits = ByteData(4)..setFloat32(0, threshold);
  bits.setFloat32(0, bits.getFloat32(0) * 100);
  return bits.getFloat32(0).truncate();
}
