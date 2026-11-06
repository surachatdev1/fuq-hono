import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image/image.dart' as img;
import '../data/hono.dart';
import '../data/wire.dart';
import 'models.dart';

DateTime bangkokNow() => DateTime.now().toUtc().add(const Duration(hours: 7));
String friendly(Object e) =>
    e is AppFailure ? e.message : 'ดำเนินการไม่สำเร็จ กรุณาลองใหม่';

class AppController extends ChangeNotifier {
  AppController({HonoApi? api, FlutterSecureStorage? vault})
    : _api = api,
      _vault = vault ?? const FlutterSecureStorage();
  HonoApi? _api;
  final FlutterSecureStorage _vault;
  Session? session;
  bool ready = false,
      busy = false,
      loading = false,
      demo = false,
      uncertain = false;
  bool remember = true, foreground = true;
  int foregroundEpoch = 0;
  void setForeground(bool active) {
    if (!active) foregroundEpoch++;
    foreground = active;
  }

  String company = 'psd',
      employee = '',
      password = '',
      error = '',
      receipt = '';
  List<Place> places = [];
  int selected = 0;
  DateTime date = bangkokNow();
  List<AttendanceEntry> logs = [];
  AttendanceState? state;
  Place? get place =>
      places.isEmpty ? null : places[selected.clamp(0, places.length - 1)];
  String get name => demo ? 'พนักงานตัวอย่าง' : session?.name ?? '';
  Set<Punch> get actions => demo
      ? Punch.values.toSet()
      : state == null
      ? {}
      : Punch.values.where((p) => state!.allows(p, logs)).toSet();
  bool get canScan =>
      !busy &&
      !loading &&
      error.isEmpty &&
      !uncertain &&
      place != null &&
      actions.isNotEmpty &&
      (demo || state?.face == true);
  Future<void> init() async {
    try {
      final material =
          jsonDecode(
                await rootBundle.loadString('assets/hono_client_protocol.json'),
              )
              as Map<String, dynamic>;
      _api ??= HonoApi(WireCodec(material));
      final creds = await _vault.read(key: 'credentials');
      if (creds != null) {
        final j = jsonDecode(creds) as Map<String, dynamic>;
        company = j['company'] as String;
        employee = j['employee'] as String;
        password = j['password'] as String;
      }
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('places');
      if (saved != null) {
        places = (jsonDecode(saved) as List)
            .map((j) => Place.fromJson(j as Map<String, dynamic>))
            .toList();
      }
      selected = (prefs.getInt('selected') ?? 0).clamp(
        0,
        max(0, places.length - 1),
      );
    } catch (_) {
      error = 'โหลดข้อมูลที่จำไว้ไม่สำเร็จ สามารถกรอกบัญชีใหม่ได้';
    }
    ready = true;
    notifyListeners();
  }

  Future<String> _deviceId() async {
    var id = await _vault.read(key: 'installation');
    if (id == null) {
      id = List.generate(
        16,
        (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      await _vault.write(key: 'installation', value: id);
    }
    return id;
  }

  Future<bool> login(String comp, String user, String pass, bool save) async {
    if (busy) return false;
    busy = true;
    error = '';
    notifyListeners();
    try {
      final active = await _api!.login(
        comp.trim(),
        user.trim(),
        pass,
        await _deviceId(),
      );
      session = active;
      demo = false;
      company = comp.trim();
      employee = user.trim();
      password = '';
      remember = save;
      try {
        if (save) {
          await _vault.write(
            key: 'credentials',
            value: jsonEncode({
              'company': company,
              'employee': employee,
              'password': pass,
            }),
          );
        } else {
          await _vault.delete(key: 'credentials');
        }
      } catch (_) {
        receipt = 'เข้าสู่ระบบแล้ว แต่บันทึกบัญชีในเครื่องไม่สำเร็จ';
      }
      busy = false;
      notifyListeners();
      await refresh();
      return true;
    } catch (e) {
      error = friendly(e);
      busy = false;
      notifyListeners();
      return false;
    }
  }

  void startDemo() {
    demo = true;
    error = '';
    logs = [];
    receipt = '';
    notifyListeners();
  }

  Future<void> logout() async {
    if (busy) return;
    session = null;
    demo = false;
    logs = [];
    state = null;
    uncertain = false;
    receipt = '';
    error = '';
    password = '';
    notifyListeners();
  }

  Future<void> forget() async {
    await _vault.delete(key: 'credentials');
    password = '';
    notifyListeners();
  }

  Future<void> refresh() async {
    if (loading || busy || demo || session == null) return;
    final active = session!;
    loading = true;
    error = '';
    notifyListeners();
    try {
      final entries = await _api!.history(active, date);
      final status = await _api!.state(active);
      if (session == active) {
        logs = entries;
        state = status;
      }
    } catch (e) {
      error = friendly(e);
      state = null;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> changeDate(DateTime d) async {
    date = d;
    await refresh();
  }

  Future<void> savePlace(Place p) async {
    final old = List<Place>.of(places);
    final index = selected;
    places = [...places, p];
    selected = places.length - 1;
    try {
      await _persistPlaces();
    } catch (_) {
      places = old;
      selected = index;
      rethrow;
    }
    notifyListeners();
  }

  Future<void> selectPlace(int i) async {
    final old = selected;
    selected = i;
    try {
      await _persistPlaces();
    } catch (_) {
      selected = old;
      rethrow;
    }
    notifyListeners();
  }

  Future<void> deletePlace(int i) async {
    final old = List<Place>.of(places);
    final index = selected;
    final chosen = place;
    places.removeAt(i);
    selected = places.indexOf(chosen ?? const Place('', 0, 0, ''));
    if (selected < 0) selected = 0;
    try {
      await _persistPlaces();
    } catch (_) {
      places = old;
      selected = index;
      rethrow;
    }
    notifyListeners();
  }

  Future<void> _persistPlaces() async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(
          'places',
          jsonEncode(places.map((p) => p.toJson()).toList()),
        ) ||
        !await prefs.setInt('selected', selected)) {
      throw const AppFailure('บันทึกสถานที่ในเครื่องไม่สำเร็จ');
    }
  }

  void acknowledgeUnknown() {
    if (!loading && !busy && error.isEmpty && state != null) {
      uncertain = false;
      receipt = 'ตรวจประวัติแล้ว หากต้องการลงใหม่ให้เริ่มสแกนอีกครั้ง';
      notifyListeners();
    }
  }

  Future<void> submitFresh(
    Uint8List capture,
    DateTime captured,
    Punch punch,
    Place frozen,
    void Function(String, bool) stage,
  ) async {
    if (busy || session == null || uncertain || !canScan || !foreground) {
      throw const AppFailure('กรุณาตรวจสถานะล่าสุดก่อนสแกน');
    }
    final active = session!;
    final known = logs.length;
    final captureEpoch = foregroundEpoch;
    busy = true;
    notifyListeners();
    Uint8List? jpeg, png;
    try {
      stage('เตรียมการยืนยันตัวตน', false);
      final enrollment = await _api!.enrollment(active);
      if (DateTime.now().difference(captured) > const Duration(minutes: 1)) {
        throw const AppFailure('ภาพเก่าเกินไป กรุณาสแกนใหม่');
      }
      final decoded = img.decodeImage(capture);
      if (decoded == null) throw const AppFailure('อ่านภาพกล้องไม่สำเร็จ');
      final baked = img.bakeOrientation(decoded);
      final resized = baked.width > 1280
          ? img.copyResize(baked, width: 1280)
          : baked;
      jpeg = img.encodeJpg(resized, quality: 20);
      final upload = img.decodeJpg(jpeg);
      if (upload == null) throw const AppFailure('เตรียมภาพลงเวลาไม่สำเร็จ');
      png = img.encodePng(upload);
      stage('กำลังตรวจภาพสดและเทียบใบหน้า', false);
      await _api!.verify(enrollment, jpeg);
      stage('ใบหน้าตรงกัน · ตรวจสถานะล่าสุด', true);
      final freshState = await _api!.state(active);
      final freshLogs = await _api!.history(active, bangkokNow());
      if (!foreground || foregroundEpoch != captureEpoch || session != active) {
        throw const AppFailure('ออกจากหน้าสแกนแล้ว กรุณาสแกนใหม่');
      }
      if (!freshState.face ||
          !freshState.allows(punch, freshLogs) ||
          freshLogs.length > known) {
        throw const AppFailure(
          'สถานะลงเวลาเปลี่ยนแล้ว กลับไปตรวจประวัติก่อนส่ง',
        );
      }
      stage('กำลังบันทึกเวลา${punch.label}…', true);
      await _api!.submit(active, frozen, punch, png);
      receipt = 'HONO ยืนยันการบันทึกเวลา${punch.label}แล้ว';
    } on UnknownOutcome {
      uncertain = true;
      receipt = const UnknownOutcome().message;
      rethrow;
    } finally {
      capture.fillRange(0, capture.length, 0);
      jpeg?.fillRange(0, jpeg.length, 0);
      png?.fillRange(0, png.length, 0);
      busy = false;
      notifyListeners();
      await refresh();
    }
  }

  @override
  void dispose() {
    _api?.close();
    super.dispose();
  }
}
