import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../core/models.dart';
import '../data/hono.dart';
import 'attendance_insights.dart';

import 'reminder_shared.dart';
export 'reminder_shared.dart';

class ReminderService {
  final plugin = FlutterLocalNotificationsPlugin();
  static const vault = FlutterSecureStorage();
  final settings = ReminderPreferences();
  WorkCalendar calendar = WorkCalendar();
  bool ready = false, exact = false, permissionGranted = false;
  String status = '';
  Session? account;
  void Function(bool exit, String date)? onOpen;
  Future<void>? _initializing;
  Future<void> initialize() =>
      _initializing ??= _initialize().catchError((Object e, StackTrace stack) {
        _initializing = null;
        ready = false;
        Error.throwWithStackTrace(e, stack);
      });
  Future<void> _initialize() async {
    tzdata.initializeTimeZones();
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final saved = prefs.getString('reminder_preferences');
    if (saved != null) {
      final config = ReminderPreferences.fromJson(
        jsonDecode(saved) as Map<String, dynamic>,
      );
      settings.enabled = config.enabled;
      settings.sound = config.sound;
      settings.customUri = config.customUri;
      settings.notifyUnknown = config.notifyUnknown;
      settings.alarmStyle = config.alarmStyle;
    }
    final cal = prefs.getString('work_calendar');
    if (cal != null) {
      calendar = WorkCalendar.fromJson(jsonDecode(cal) as Map<String, dynamic>);
    }
    final identity = prefs.getString('reminder_identity');
    if (identity != null) {
      final j = jsonDecode(identity) as Map<String, dynamic>;
      account = Session(
        '',
        j['company'] as String,
        '',
        j['employee'] as String,
        '',
        '',
        '',
        '',
        false,
      );
    }
    if (account == null) {
      final oldIdentity = (prefs.getString('reminder_active_account') ?? '')
          .split(':');
      if (oldIdentity.length == 2 &&
          oldIdentity.every((part) => part.isNotEmpty)) {
        account = Session(
          '',
          oldIdentity[0],
          '',
          oldIdentity[1],
          '',
          '',
          '',
          '',
          false,
        );
      }
    }
    // Migrate 1.1: alarm checks no longer need or retain a server token/API key.
    try {
      await vault.delete(key: 'attendance_reminder_session');
    } catch (_) {}
    await plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        unawaited(handleOpen(response));
      },
      onDidReceiveBackgroundNotificationResponse: reminderNotificationAction,
    );
    if (Platform.isAndroid) {
      await AndroidAlarmManager.initialize();
      final android = plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      exact = await android?.canScheduleExactNotifications() ?? false;
      permissionGranted = await android?.areNotificationsEnabled() ?? false;
    }
    ready = true;
    if (settings.enabled) {
      await reschedule();
    }
    final launch = await plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true &&
        launch?.notificationResponse != null) {
      await handleOpen(launch!.notificationResponse!);
    }
  }

  Future<void> handleOpen(NotificationResponse response) async {
    if (response.actionId == 'dismiss') {
      await silence();
      return;
    }
    Map<String, dynamic> payload = {};
    try {
      payload = jsonDecode(response.payload ?? '{}') as Map<String, dynamic>;
    } catch (_) {}
    final date = payload['date'] as String? ?? HonoApi.dateKey(reminderNow()),
        exit = payload['exit'] == true;
    if (date != HonoApi.dateKey(reminderNow())) {
      return;
    }
    final who = account == null ? null : reminderAccount(account!);
    if (payload['account'] != null && payload['account'] != who) {
      return;
    }
    final snapshot = await todaySnapshot();
    if (exit ? snapshot.hasOut : snapshot.hasIn) {
      await silence();
      return;
    }
    onOpen?.call(exit, date);
  }

  Future<void> bind(Session session) async {
    await initialize();
    account = session;
    if (settings.enabled) {
      await _retainAccount();
      await reschedule();
    }
  }

  Future<void> _retainAccount() async {
    final s = account;
    if (s == null) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'reminder_identity',
      jsonEncode({'company': s.company, 'employee': s.employee}),
    );
    await prefs.setString('reminder_active_account', reminderAccount(s));
  }

  Future<void> setEnabled(bool value) async {
    await initialize();
    if (value && account == null) {
      throw const AppFailure('เข้าสู่ระบบก่อนเปิดการแจ้งเตือน');
    }
    if (value) {
      if (Platform.isAndroid) {
        final android = plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        permissionGranted =
            await android?.requestNotificationsPermission() ?? false;
        if (!permissionGranted) {
          throw const AppFailure(
            'กรุณาอนุญาตการแจ้งเตือนในการตั้งค่าของเครื่อง',
          );
        }
        exact = await android?.requestExactAlarmsPermission() ?? false;
      } else if (Platform.isIOS) {
        permissionGranted =
            await plugin
                .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin
                >()
                ?.requestPermissions(alert: true, sound: true, badge: false) ??
            false;
        if (!permissionGranted) {
          throw const AppFailure(
            'กรุณาอนุญาตการแจ้งเตือนในการตั้งค่าของเครื่อง',
          );
        }
      }
    }
    settings.enabled = value;
    await persist();
    if (value) {
      await _retainAccount();
      await reschedule();
    } else {
      await cancel();
    }
    status = value
        ? (Platform.isAndroid && !exact
              ? 'เปิดเตือนแบบประมาณเวลา · อนุญาตนาฬิกาปลุกตรงเวลาเพื่อให้แม่นยำ'
              : 'เปิดเตือนจากข้อมูลในเครื่องแล้ว')
        : 'ปิดการแจ้งเตือนแล้ว';
  }

  Future<void> allowFullScreen() async {
    await initialize();
    final allowed =
        await plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestFullScreenIntentPermission() ??
        false;
    status = allowed
        ? 'อนุญาตหน้าปลุกเต็มจอแล้ว'
        : 'ระบบจะใช้แถบแจ้งเตือนเมื่อไม่อนุญาตเต็มจอ';
  }

  Future<void> persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'reminder_preferences',
      jsonEncode(settings.toJson()),
    );
    await prefs.setString('work_calendar', jsonEncode(calendar.toJson()));
  }

  Future<void> configure() async {
    await persist();
    if (ready && settings.enabled) {
      await reschedule();
    }
  }

  Future<void> clearAccount() async {
    try {
      await initialize();
    } catch (_) {}
    account = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('reminder_active_account');
    await prefs.remove('reminder_identity');
    try {
      await cancel();
    } finally {
      await vault.delete(key: 'attendance_reminder_session');
    }
  }

  NotificationDetails details({bool alarm = false}) {
    final ringing = alarm && settings.alarmStyle, sound = settings.sound;
    AndroidNotificationSound? androidSound;
    if (sound == 'soft' || sound == 'chime') {
      androidSound = RawResourceAndroidNotificationSound('nwl_$sound');
    }
    if (sound == 'custom' && settings.customUri.isNotEmpty) {
      androidSound = UriAndroidNotificationSound(settings.customUri);
    }
    if (sound == 'system' && ringing) {
      androidSound = const UriAndroidNotificationSound(
        'content://settings/system/alarm_alert',
      );
    }
    final uriHash = settings.customUri.codeUnits.fold<int>(
      0,
      (a, b) => (a * 31 + b) & 0x7fffffff,
    );
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'nwl_local_v2_${ringing ? 'alarm' : 'notice'}_${sound}_$uriHash',
        ringing ? 'นาฬิกาปลุกลงเวลา' : 'เตือนลงเวลา',
        channelDescription: 'อ่านข้อมูลเข้าออกที่บันทึกในเครื่องก่อนเตือน',
        importance: Importance.max,
        priority: Priority.max,
        category: ringing
            ? AndroidNotificationCategory.alarm
            : AndroidNotificationCategory.reminder,
        audioAttributesUsage: ringing
            ? AudioAttributesUsage.alarm
            : AudioAttributesUsage.notification,
        playSound: sound != 'silent',
        sound: androidSound,
        visibility: NotificationVisibility.private,
        fullScreenIntent: ringing,
        ongoing: ringing,
        autoCancel: !ringing,
        timeoutAfter: ringing ? 60000 : null,
        additionalFlags: ringing ? Int32List.fromList([4]) : null,
        actions: alarm
            ? const [
                AndroidNotificationAction(
                  'open',
                  'เปิดหน้าลงเวลา',
                  showsUserInterface: true,
                ),
                AndroidNotificationAction(
                  'dismiss',
                  'หยุดเสียง',
                  cancelNotification: true,
                ),
              ]
            : null,
      ),
      iOS: DarwinNotificationDetails(
        presentSound: sound != 'silent',
        sound: sound == 'soft' || sound == 'chime' ? 'nwl_$sound.wav' : null,
      ),
    );
  }

  Future<void> preview() async {
    await initialize();
    if (Platform.isAndroid) {
      await plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    } else if (Platform.isIOS) {
      await plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, sound: true, badge: false);
    }
    await plugin.show(
      7999,
      'ทดลองนาฬิกาปลุก',
      'หยุดเสียงได้จากการแจ้งเตือน · จำกัดเสียง 60 วินาที',
      details(alarm: true),
      payload: jsonEncode({
        'date': HonoApi.dateKey(reminderNow()),
        'exit': false,
      }),
    );
  }

  Future<void> chooseDeviceSound() async {
    final result = await const MethodChannel(
      'nwl/reminder_settings',
    ).invokeMethod<String>('pickSound', settings.customUri);
    if (result == null) {
      return;
    }
    settings.sound = result.isEmpty ? 'silent' : 'custom';
    settings.customUri = result;
    await configure();
  }

  Future<LocalAttendance> todaySnapshot() async {
    if (account == null) {
      return const LocalAttendance();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return readLocal(prefs, reminderAccount(account!), reminderNow());
  }

  Future<void> recordSnapshot(
    Session s,
    DateTime date,
    List<AttendanceEntry> logs,
  ) async {
    if (!ready ||
        account == null ||
        reminderAccount(account!) != reminderAccount(s)) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final prior = readLocal(prefs, reminderAccount(s), date);
    await prefs.setString(
      snapshotKey(reminderAccount(s), date),
      jsonEncode({
        'in': prior.hasIn || logs.any((l) => l.flag.toUpperCase() == 'I'),
        'out': prior.hasOut || logs.any((l) => l.flag.toUpperCase() == 'O'),
        'sync': DateTime.now().toUtc().toIso8601String(),
      }),
    );
    // Re-arm tomorrow's morning slots immediately after confirmed IN; keep today's OUT.
    if (HonoApi.dateKey(date) == HonoApi.dateKey(reminderNow())) {
      if (prior.hasIn || logs.any((l) => l.flag.toUpperCase() == 'I')) {
        for (final id in [7010, 7011, 7012]) {
          await plugin.cancel(id);
        }
      }
      if (prior.hasOut || logs.any((l) => l.flag.toUpperCase() == 'O')) {
        await plugin.cancel(7013);
      }
    }
    if (settings.enabled) {
      await reschedule();
    }
  }

  Future<void> confirmed(Session s, Punch punch) async {
    await recordSnapshot(s, reminderNow(), [
      AttendanceEntry(punch.wire, 'confirmed', 1),
    ]);
  }

  Future<void> silence() async {
    if (!ready) {
      return;
    }
    for (final id in [7010, 7011, 7012, 7013, 7999]) {
      await plugin.cancel(id);
    }
  }

  Future<void> cancel() async {
    if (!ready) {
      return;
    }
    await plugin.cancelAll();
    if (Platform.isAndroid) {
      for (var slot = 0; slot < 4; slot++) {
        await AndroidAlarmManager.cancel(7010 + slot);
      }
    }
  }

  Future<void> reschedule() async {
    if (!ready || !settings.enabled) {
      return;
    }
    if (Platform.isAndroid) {
      for (var slot = 0; slot < 4; slot++) {
        await AndroidAlarmManager.cancel(7010 + slot);
      }
    } else {
      await plugin.cancelAll();
    }
    if (account == null) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final who = reminderAccount(account!), now = reminderNow();
    if (Platform.isAndroid) {
      final snapshots = {
        for (var d = 0; d < 370; d++)
          HonoApi.dateKey(DateTime(now.year, now.month, now.day + d)):
              readLocal(prefs, who, DateTime(now.year, now.month, now.day + d)),
      };
      for (var slot = 0; slot < 4; slot++) {
        await scheduleAndroidSlot(slot, exact, calendar, snapshots);
      }
      return;
    }
    if (!Platform.isIOS) {
      return;
    }
    final location = tz.getLocation('Asia/Bangkok');
    for (var day = 0; day < 14; day++) {
      final date = DateTime(now.year, now.month, now.day + day);
      if (!calendar.isWorkday(date)) {
        continue;
      }
      final snapshot = readLocal(prefs, who, date);
      for (var slot = 0; slot < 4; slot++) {
        if (slot == 3 ? snapshot.hasOut : snapshot.hasIn) {
          continue;
        }
        final time = reminderSlots[slot],
            at = tz.TZDateTime(
              location,
              date.year,
              date.month,
              date.day,
              time.$1,
              time.$2,
            );
        if (!at.isAfter(tz.TZDateTime.now(location))) {
          continue;
        }
        await plugin.zonedSchedule(
          7100 + day * 4 + slot,
          slot == 3 ? 'ถึงเวลาออกงาน' : 'ถึงเวลาเข้างาน',
          'ตรวจข้อมูลในเครื่องแล้ว ยังไม่พบรายการ · เปิดแอปเพื่อตรวจและสแกน',
          at,
          details(),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: jsonEncode({
            'account': who,
            'date': HonoApi.dateKey(date),
            'exit': slot == 3,
          }),
        );
      }
    }
    status = 'ตั้งเตือนล่วงหน้า 14 วัน · เปิดแอปเพื่ออัปเดตข้อมูลในเครื่อง';
  }
}

LocalAttendance readLocal(SharedPreferences prefs, String who, DateTime date) {
  final raw = prefs.getString(snapshotKey(who, date));
  if (raw == null) {
    return const LocalAttendance();
  }
  try {
    return LocalAttendance.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  } catch (_) {
    return const LocalAttendance();
  }
}

Future<void> scheduleAndroidSlot(
  int slot,
  bool exact,
  WorkCalendar calendar,
  Map<String, LocalAttendance> snapshots,
) async {
  final target = nextLocalReminderInstant(
    DateTime.now().toUtc(),
    slot,
    calendar,
    snapshots,
  );
  if (target == null) {
    return;
  }
  await AndroidAlarmManager.oneShotAt(
    target.toLocal(),
    7010 + slot,
    attendanceAlarm,
    exact: exact,
    wakeup: true,
    allowWhileIdle: true,
    rescheduleOnReboot: true,
  );
}

@pragma('vm:entry-point')
void reminderNotificationAction(NotificationResponse response) {
  /* The native dismiss action cancels the notification and its sound. */
}
@pragma('vm:entry-point')
Future<void> attendanceAlarm(int id) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  final slot = id - 7010;
  if (slot < 0 || slot > 3) {
    return;
  }
  final service = ReminderService();
  try {
    await service.initialize();
    if (!service.settings.enabled || service.account == null) {
      return;
    }
    final now = reminderNow(), clock = reminderSlots[slot];
    final delay = now.difference(
      DateTime(now.year, now.month, now.day, clock.$1, clock.$2),
    );
    if (delay.isNegative || delay > const Duration(minutes: 15)) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final who = reminderAccount(service.account!);
    if (prefs.getString('reminder_active_account') != who) {
      return;
    }
    final latest = ReminderPreferences.fromJson(
      jsonDecode(prefs.getString('reminder_preferences') ?? '{}')
          as Map<String, dynamic>,
    );
    final calendar = WorkCalendar.fromJson(
      jsonDecode(prefs.getString('work_calendar') ?? '{}')
          as Map<String, dynamic>,
    );
    final snapshot = readLocal(prefs, who, now);
    if (!latest.enabled ||
        !calendar.isWorkday(now) ||
        (slot == 3 ? snapshot.hasOut : snapshot.hasIn)) {
      return;
    }
    if (!snapshot.synced && !latest.notifyUnknown) {
      return;
    }
    await service.plugin.show(
      id,
      slot == 3 ? 'ถึงเวลาออกงาน' : 'ถึงเวลาเข้างาน',
      snapshot.synced
          ? 'ยังไม่พบรายการในข้อมูลของเครื่อง · เปิดแอปเพื่อตรวจและสแกน'
          : 'ถึงเวลาแล้ว · เปิดแอปเพื่อตรวจสถานะและสแกน',
      service.details(alarm: true),
      payload: jsonEncode({
        'account': who,
        'date': HonoApi.dateKey(now),
        'exit': slot == 3,
      }),
    );
  } catch (_) {
    /* OS restrictions must not crash a background callback. */
  }
}
