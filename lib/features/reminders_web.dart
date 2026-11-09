import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/models.dart';
import '../data/hono.dart';
import 'attendance_insights.dart';
import 'reminder_shared.dart';
export 'reminder_shared.dart';

@JS('nwlSound')
external void _sound(String kind);
@JS('nwlSilence')
external void _silence();

// Browsers do not provide exact, closed-app alarms. These are page-open reminders.
class ReminderService {
  ReminderPreferences settings = ReminderPreferences();
  WorkCalendar calendar = WorkCalendar();
  bool ready = false, exact = false, permissionGranted = false;
  String status = 'เว็บเตือนได้ขณะเปิดหน้านี้อยู่เท่านั้น';
  Session? account;
  void Function(bool exit, String date)? onOpen;
  Timer? _timer;
  final Set<String> _fired = {};
  Future<void> initialize() async {
    if (ready) return;
    final p = await SharedPreferences.getInstance();
    settings = ReminderPreferences.fromJson(
      jsonDecode(p.getString('reminder_preferences') ?? '{}')
          as Map<String, dynamic>,
    );
    calendar = WorkCalendar.fromJson(
      jsonDecode(p.getString('work_calendar') ?? '{}') as Map<String, dynamic>,
    );
    ready = true;
    _timer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => unawaited(_tick()),
    );
  }

  Future<void> _tick() async {
    if (!settings.enabled || account == null) return;
    final now = reminderNow();
    if (!calendar.isWorkday(now)) return;
    final prefs = await SharedPreferences.getInstance();
    final snapshot = LocalAttendance.fromJson(
      jsonDecode(
            prefs.getString(snapshotKey(reminderAccount(account!), now)) ??
                '{}',
          )
          as Map<String, dynamic>,
    );
    for (var slot = 0; slot < reminderSlots.length; slot++) {
      final t = reminderSlots[slot],
          key = '${reminderAccount(account!)}:${HonoApi.dateKey(now)}:$slot';
      if (now.hour != t.$1 || now.minute != t.$2 || _fired.contains(key)) {
        continue;
      }
      _fired.add(key);
      if ((slot == 3 ? snapshot.hasOut : snapshot.hasIn) ||
          (!snapshot.synced && !settings.notifyUnknown)) {
        continue;
      }
      if (settings.sound != 'silent') _sound(settings.sound);
      onOpen?.call(slot == 3, HonoApi.dateKey(now));
    }
  }

  Future<void> bind(Session s) async {
    await initialize();
    account = s;
  }

  Future<void> clearAccount() async {
    account = null;
    await silence();
  }

  Future<void> setEnabled(bool value) async {
    await initialize();
    if (value && account == null) {
      throw const AppFailure('เข้าสู่ระบบก่อนเปิดการเตือน');
    }
    settings.enabled = value;
    // User gesture unlocks browser audio; no notification permission is implied.
    if (value && settings.sound != 'silent') _sound(settings.sound);
    await persist();
    status = value
        ? 'เปิดเตือนขณะหน้าเว็บเปิดอยู่แล้ว · ไม่รับประกันเมื่อพักแท็บหรือปิดเว็บ'
        : 'ปิดการเตือนแล้ว';
  }

  Future<void> persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('reminder_preferences', jsonEncode(settings.toJson()));
    await p.setString('work_calendar', jsonEncode(calendar.toJson()));
  }

  Future<void> configure() => persist();
  Future<void> reschedule() async {
    if (ready && _timer?.isActive != true) {
      _timer = Timer.periodic(
        const Duration(seconds: 15),
        (_) => unawaited(_tick()),
      );
    }
  }

  Future<void> preview() async {
    _sound(settings.sound);
    status = 'ทดลองเสียง · เบราว์เซอร์อาจจำกัดเสียง';
  }

  Future<void> silence() async {
    _silence();
  }

  Future<void> cancel() async {
    await silence();
  }

  Future<void> allowFullScreen() async {}
  Future<void> chooseDeviceSound() async {}
  Future<LocalAttendance> todaySnapshot() async {
    if (account == null) return const LocalAttendance();
    final p = await SharedPreferences.getInstance();
    return LocalAttendance.fromJson(
      jsonDecode(
            p.getString(
                  snapshotKey(reminderAccount(account!), reminderNow()),
                ) ??
                '{}',
          )
          as Map<String, dynamic>,
    );
  }

  Future<void> recordSnapshot(
    Session s,
    DateTime date,
    List<AttendanceEntry> logs,
  ) async {
    if (account == null || reminderAccount(s) != reminderAccount(account!)) {
      return;
    }
    final p = await SharedPreferences.getInstance(),
        key = snapshotKey(reminderAccount(s), date);
    final prior = LocalAttendance.fromJson(
      jsonDecode(p.getString(key) ?? '{}') as Map<String, dynamic>,
    );
    await p.setString(
      key,
      jsonEncode({
        'in': prior.hasIn || logs.any((r) => r.flag == 'I'),
        'out': prior.hasOut || logs.any((r) => r.flag == 'O'),
        'sync': DateTime.now().toUtc().toIso8601String(),
      }),
    );
    await silence();
  }

  Future<void> confirmed(Session s, Punch punch) => recordSnapshot(
    s,
    reminderNow(),
    [AttendanceEntry(punch.wire, 'confirmed', 1)],
  );
}
