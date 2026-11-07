import 'dart:async';
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
import '../features/attendance_insights.dart';
import '../features/reminders.dart';

DateTime bangkokNow() => reminderNow();
String friendly(Object e) =>
    e is AppFailure ? e.message : 'ดำเนินการไม่สำเร็จ กรุณาลองใหม่';

class AppController extends ChangeNotifier {
  AppController({HonoApi? api, FlutterSecureStorage? vault})
    : _api = api,
      _vault = vault ?? const FlutterSecureStorage();
  HonoApi? _api;
  final FlutterSecureStorage _vault;
  Session? session;
  final reminders = ReminderService();
  WorkCalendar get calendar => reminders.calendar;
  String historyError = '', stateError = '', reportError = '';
  DateTime? loadedHistoryDate;
  int _historyEpoch = 0,
      _reportEpoch = 0,
      reportProgress = 0,
      reminderFocus = 0;
  bool reportLoading = false, _alive = true;
  LateReport? lateReport;
  ProcessedAttendanceDay? processedDay;
  String processedError='';
  bool processedLoading=false;
  bool ready = false,
      busy = false,
      loading = false,
      demo = false,
      uncertain = false;
  bool remember = true, foreground = true;
  bool reminderPrompt=false, reminderExit=false;
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
      historyError.isEmpty &&
      stateError.isEmpty &&
      HonoApi.dateKey(date) == HonoApi.dateKey(bangkokNow()) &&
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
    reminders.onOpen = (exit, dateKey) {
      if(!_alive)return;
      reminderExit=exit;reminderPrompt=true;reminderFocus++;
      notifyListeners();
    };
    unawaited(
      reminders
          .initialize()
          .then((_) {
            if (_alive) notifyListeners();
          })
          .catchError((Object e) {
            reminders.status =
                'ยังเตรียมการแจ้งเตือนไม่สำเร็จ เปิดหน้าตั้งค่าเพื่อลองใหม่';
            if (_alive) notifyListeners();
          }),
    );
  }

  void dismissReminder() {
    reminderPrompt=false;unawaited(reminders.silence());notifyListeners();
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
      try {
        await reminders.bind(active);
      } catch (_) {
        reminders.status = 'เข้าสู่ระบบแล้ว แต่ยังตั้งการเตือนไม่สำเร็จ';
      }
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
    _historyEpoch++;
    _reportEpoch++;
    loading = false;
    reportLoading = false;
    lateReport = null;
    loadedHistoryDate = null;
    historyError = '';
    stateError = '';
    try {
      await reminders.clearAccount();
    } catch (_) {}
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
    if (busy || demo || session == null) return;
    final active = session!,
        requested = DateTime(date.year, date.month, date.day),
        ticket = ++_historyEpoch;
    loading = true;
    error = '';
    historyError = '';
    stateError = '';
    logs = [];
    state = null;
    processedDay=null;processedError='';processedLoading=false;
    loadedHistoryDate = null;
    notifyListeners();
    bool current() =>
        _alive &&
        session == active &&
        ticket == _historyEpoch &&
        HonoApi.dateKey(date) == HonoApi.dateKey(requested);
    try {
      final entries = await _api!.history(active, requested);
      if (!current()) return;
      logs = entries;
      loadedHistoryDate = requested;
      unawaited(
        reminders
            .recordSnapshot(active, requested, entries)
            .catchError((Object _) {}),
      );
      if (HonoApi.dateKey(requested) == HonoApi.dateKey(bangkokNow())) {
        try {
          final status = await _api!.state(active);
          if (current()) state = status;
        } catch (e) {
          if (current()) stateError = friendly(e);
        }
      }
    } catch (e) {
      if (current()) {
        historyError = friendly(e);
        error = historyError;
      }
    } finally {
      if (current()) {
        loading = false;
        notifyListeners();
        await _loadProcessedDate(active,requested,ticket);
      }
    }
  }

  Future<void> _cacheProcessedCalendar(Session active,List<ProcessedAttendanceDay> records) async {
    for(final r in records){calendar.serverWorkdays[HonoApi.dateKey(r.date)]=!r.holiday;}
    if(reminders.ready){
      await reminders.configure();
      for(final r in records.where((r)=>HonoApi.dateKey(r.date)==HonoApi.dateKey(bangkokNow())&&!r.pending)){
        await reminders.recordSnapshot(active,r.date,[
          if(punchClock(r.inTime,r.date)!=null)AttendanceEntry('I',r.inTime,1),
          if(punchClock(r.outTime,r.date)!=null)AttendanceEntry('O',r.outTime,1)]);
      }
    }
  }
  Future<void> _loadProcessedDate(Session active,DateTime requested,int ticket) async {
    bool current()=>_alive&&session==active&&ticket==_historyEpoch;
    if(!current())return;
    processedLoading=true;processedError='';processedDay=null;notifyListeners();
    try {
      final records=await _api!.processedMonth(active,requested);
      if(!current())return;
      processedDay=records.where((r)=>HonoApi.dateKey(r.date)==HonoApi.dateKey(requested)).firstOrNull;
      if(processedDay==null){processedError='ยังไม่มีข้อมูลหลังประมวลผลของวันที่เลือก';}
      await _cacheProcessedCalendar(active,records);
    }catch(e){if(current())processedError=friendly(e);}
    finally{if(current()){processedLoading=false;notifyListeners();}}
  }

  Future<void> changeDate(DateTime d) async {
    date = DateTime(d.year, d.month, d.day);
    _historyEpoch++;
    _reportEpoch++;
    logs = [];
    state = null;
    processedDay=null;processedError='';processedLoading=false;
    loadedHistoryDate = null;
    historyError = '';
    stateError = '';
    error = '';
    loading = false;
    lateReport = null;
    reportError = '';
    reportLoading = false;
    notifyListeners();
    await refresh();
  }

  Future<void> loadMonthlyReport() async {
    if(reportLoading||session==null||demo)return;
    final active=session!,month=DateTime(date.year,date.month),now=bangkokNow(),ticket=++_reportEpoch;
    reportLoading=true;reportProgress=0;reportError='';lateReport=null;notifyListeners();
    bool current()=>_alive&&session==active&&ticket==_reportEpoch;
    try {
      final records=await _api!.processedMonth(active,month);
      if(!current())return;
      await _cacheProcessedCalendar(active,records);
      if(!current())return;
      final byDate={for(final r in records)HonoApi.dateKey(r.date):r};
      final last=DateTime(month.year,month.month+1,0).day;
      final days=[for(var d=1;d<=last;d++)DateTime(month.year,month.month,d)]
        .where((d)=>!d.isAfter(DateTime(now.year,now.month,now.day))).toList();
      lateReport=LateReport(month,[for(final day in days)summarizeProcessedDay(day,byDate[HonoApi.dateKey(day)],calendar,now)]);
      reportProgress=days.length;
      if(lateReport!.unknownDays>0){reportError='มี ${lateReport!.unknownDays} วันที่ข้อมูลหลังประมวลผลยังไม่ครบหรือรออนุมัติ';}
    }catch(e){if(current()){reportError='อ่านเวลาหลังประมวลผลไม่สำเร็จ: ${friendly(e)} · ไม่ใช้เวลาตอกจริงแทน';}}
    finally{if(current()){reportLoading=false;notifyListeners();}}
  }

  Future<void> saveCalendar() async {
    _reportEpoch++;
    lateReport = null;
    reportLoading = false;
    reportError = '';
    await reminders.configure();
    notifyListeners();
  }

  Future<void> reminderSettingsChanged() async {
    await reminders.configure();
    notifyListeners();
  }

  Future<void> resumeRefresh() async {
    if (session == null) return;
    if (HonoApi.dateKey(date) == HonoApi.dateKey(bangkokNow())) {
      await refresh();
    } else {
      final active = session!;
      try {
        final entries = await _api!.history(active, bangkokNow());
        if (session == active) {
          await reminders.recordSnapshot(active, bangkokNow(), entries);
        }
      } catch (_) {}
    }
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
    if (!loading &&
        !busy &&
        historyError.isEmpty &&
        stateError.isEmpty &&
        state != null &&
        loadedHistoryDate != null &&
        HonoApi.dateKey(loadedHistoryDate!) == HonoApi.dateKey(bangkokNow()) &&
        HonoApi.dateKey(date) == HonoApi.dateKey(bangkokNow())) {
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
      try {
        await reminders.confirmed(active, punch);
      } catch (_) {}
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
    _alive = false;
    _historyEpoch++;
    _reportEpoch++;
    _api?.close();
    super.dispose();
  }
}
