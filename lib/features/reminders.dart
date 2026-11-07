import 'dart:async';
import 'dart:convert';
import 'dart:io';
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
import '../data/wire.dart';
import 'attendance_insights.dart';

DateTime reminderNow() {
  final b=DateTime.now().toUtc().add(const Duration(hours:7));
  return DateTime(b.year,b.month,b.day,b.hour,b.minute,b.second,b.millisecond);
}
const reminderSlots=[(8,20),(8,30),(8,50),(18,0)];
enum ReminderDecision { suppress, missing, unknown }
ReminderDecision reminderDecision({required bool workday,required bool exit,required bool known,required bool hasIn,required bool hasOut}) {
  if(!workday || (exit?hasOut:hasIn))return ReminderDecision.suppress;
  return known?ReminderDecision.missing:ReminderDecision.unknown;
}
DateTime nextReminderInstant(DateTime utcNow,int slot) {
  final wall=utcNow.toUtc().add(const Duration(hours:7)),time=reminderSlots[slot];
  var target=DateTime.utc(wall.year,wall.month,wall.day,time.$1,time.$2).subtract(const Duration(hours:7));
  if(!target.isAfter(utcNow.toUtc()))target=target.add(const Duration(days:1));
  return target;
}
class ReminderPreferences {
  bool enabled=false,notifyUnknown=true;
  String sound='system',customUri='';
  Map<String,dynamic> toJson()=>{'enabled':enabled,'notifyUnknown':notifyUnknown,'sound':sound,'customUri':customUri};
  factory ReminderPreferences.fromJson(Map<String,dynamic> j)=>ReminderPreferences()
    ..enabled=j['enabled']==true..notifyUnknown=j['notifyUnknown']!=false
    ..sound=(j['sound'] as String? ?? 'system')..customUri=(j['customUri'] as String? ?? '');
  ReminderPreferences();
}
String reminderAccount(Session s)=>'${s.company}:${s.employee}';
String snapshotKey(String account,DateTime date)=>'attendance_snapshot:$account:${HonoApi.dateKey(date)}';
Map<String,dynamic> readSessionMap(Session s)=>{'base':s.base,'company':s.company,'php':s.php,'employee':s.employee,'name':s.name,'token':s.token,'markKey':s.markKey};
Session readSession(Map<String,dynamic> j)=>Session(j['base'] as String,j['company'] as String,j['php'] as String,j['employee'] as String,j['name'] as String,j['token'] as String,j['markKey'] as String,'',false);

class ReminderService {
  final plugin=FlutterLocalNotificationsPlugin();
  static const vault=FlutterSecureStorage();
  final settings=ReminderPreferences();
  WorkCalendar calendar=WorkCalendar();
  bool ready=false,exact=false,permissionGranted=false;
  String status='';
  Session? account;
  VoidCallback? onOpen;
  Future<void>? _initializing;
  Future<void> initialize() => _initializing ??= _initialize().catchError((Object e,StackTrace stack) {
    _initializing=null;ready=false;Error.throwWithStackTrace(e,stack);
  });
  Future<void> _initialize() async {
    tzdata.initializeTimeZones();
    final prefs=await SharedPreferences.getInstance();await prefs.reload();
    final saved=prefs.getString('reminder_preferences');
    if(saved!=null) {
      final config=ReminderPreferences.fromJson(jsonDecode(saved) as Map<String,dynamic>);
      settings.enabled=config.enabled;settings.sound=config.sound;settings.customUri=config.customUri;settings.notifyUnknown=config.notifyUnknown;
    }
    final cal=prefs.getString('work_calendar');
    if(cal!=null)calendar=WorkCalendar.fromJson(jsonDecode(cal) as Map<String,dynamic>);
    await plugin.initialize(const InitializationSettings(
      android:AndroidInitializationSettings('ic_notification'),
      iOS:DarwinInitializationSettings(requestAlertPermission:false,requestSoundPermission:false,requestBadgePermission:false)),
      onDidReceiveNotificationResponse:(_)=>onOpen?.call());
    if(Platform.isAndroid) {
      await AndroidAlarmManager.initialize();
      final android=plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      exact=await android?.canScheduleExactNotifications() ?? false;
      permissionGranted=await android?.areNotificationsEnabled() ?? false;
    }
    ready=true;
    final launch=await plugin.getNotificationAppLaunchDetails();
    if(launch?.didNotificationLaunchApp==true)onOpen?.call();
    if(settings.enabled) {
      final raw=await vault.read(key:'attendance_reminder_session');
      if(raw!=null)account=readSession(jsonDecode(raw) as Map<String,dynamic>);
      await reschedule();
    }
  }
  Future<void> bind(Session session) async {
    await initialize();
    account=session;
    if(!settings.enabled){return;}
    await _retainAccount();
    await reschedule();
  }
  Future<void> _retainAccount() async {
    final s=account;if(s==null){return;}
    await vault.write(key:'attendance_reminder_session',value:jsonEncode(readSessionMap(s)));
    final prefs=await SharedPreferences.getInstance();await prefs.setString('reminder_active_account',reminderAccount(s));
  }
  Future<void> setEnabled(bool value) async {
    await initialize();
    if(value && account==null)throw const AppFailure('เข้าสู่ระบบก่อนเปิดการแจ้งเตือน');
    if(value) {
      if(Platform.isAndroid) {
        final android=plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        permissionGranted=await android?.requestNotificationsPermission() ?? false;
        if(!permissionGranted)throw const AppFailure('กรุณาอนุญาตการแจ้งเตือนในการตั้งค่าของเครื่อง');
        exact=await android?.requestExactAlarmsPermission() ?? false;
      } else if(Platform.isIOS) {
        permissionGranted=await plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert:true,sound:true,badge:false) ?? false;
        if(!permissionGranted)throw const AppFailure('กรุณาอนุญาตการแจ้งเตือนในการตั้งค่าของเครื่อง');
      }
    }
    settings.enabled=value;
    await persist();
    if(value) {await _retainAccount();await reschedule();}
    else {await cancel();await vault.delete(key:'attendance_reminder_session');}
    status=value?(Platform.isAndroid && !exact?'เตือนแบบประมาณเวลา · ยังไม่ได้อนุญาตนาฬิกาปลุกตรงเวลา':'เปิดเตือน 08:20 · 08:30 · 08:50 · 18:00 แล้ว'):'ปิดการแจ้งเตือนแล้ว';
  }
  Future<void> persist() async {
    final prefs=await SharedPreferences.getInstance();
    await prefs.setString('reminder_preferences',jsonEncode(settings.toJson()));
    await prefs.setString('work_calendar',jsonEncode(calendar.toJson()));
  }
  Future<void> configure() async {await persist();if(ready && settings.enabled)await reschedule();}
  Future<void> clearAccount() async {
    try {await initialize();} catch (_) { }
    account=null;
    final prefs=await SharedPreferences.getInstance();await prefs.remove('reminder_active_account');
    try {await cancel();} finally {await vault.delete(key:'attendance_reminder_session');}
  }
  NotificationDetails details() {
    final sound=settings.sound;
    AndroidNotificationSound? androidSound;
    if(sound=='soft'||sound=='chime')androidSound=RawResourceAndroidNotificationSound('nwl_$sound');
    if(sound=='custom' && settings.customUri.isNotEmpty)androidSound=UriAndroidNotificationSound(settings.customUri);
    final uriHash=settings.customUri.codeUnits.fold<int>(0,(a,b)=>(a*31+b)&0x7fffffff);
    return NotificationDetails(
      android:AndroidNotificationDetails('nwl_attendance_${sound}_$uriHash','เตือนลงเวลางาน',
        channelDescription:'ตรวจประวัติและเตือนการลงเวลา',importance:Importance.high,priority:Priority.high,
        playSound:sound!='silent',sound:androidSound,visibility:NotificationVisibility.private),
      iOS:DarwinNotificationDetails(presentSound:sound!='silent',sound:sound=='soft'||sound=='chime'?'nwl_$sound.wav':null));
  }
  Future<void> preview() async {
    await initialize();
    if(Platform.isAndroid) {
      await plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    } else if(Platform.isIOS) {
      await plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert:true,sound:true,badge:false);
    }
    await plugin.show(7999,'ทดลองเสียงเตือน','นี่คือเสียงที่เลือกสำหรับเตือนลงเวลางาน',details());
  }
  Future<void> chooseDeviceSound() async {
    final result=await const MethodChannel('nwl/reminder_settings').invokeMethod<String>('pickSound',settings.customUri);
    if(result==null){return;}
    settings.sound=result.isEmpty?'silent':'custom';settings.customUri=result;await configure();
  }
  Future<void> recordSnapshot(Session s,DateTime date,List<AttendanceEntry> logs) async {
    if(!ready || account==null || reminderAccount(account!)!=reminderAccount(s)){return;}
    final prefs=await SharedPreferences.getInstance();
    final key=snapshotKey(reminderAccount(s),date);
    final old=prefs.getString(key);
    final prior=old==null?<String,dynamic>{}:jsonDecode(old) as Map<String,dynamic>;
    await prefs.setString(key,jsonEncode({
      'in':prior['in']==true || logs.any((l)=>l.flag.toUpperCase()=='I'),
      'out':prior['out']==true || logs.any((l)=>l.flag.toUpperCase()=='O'),
      'sync':DateTime.now().toUtc().toIso8601String()}));
    if(Platform.isIOS && settings.enabled)await reschedule();
  }
  Future<void> confirmed(Session s,Punch punch) async {
    await recordSnapshot(s,reminderNow(),[AttendanceEntry(punch.wire,'confirmed',1)]);
  }
  Future<void> cancel() async {
    if(!ready){return;}
    await plugin.cancelAll();
    if(Platform.isAndroid){for(var slot=0;slot<4;slot++){await AndroidAlarmManager.cancel(7010+slot);}}
  }
  Future<void> reschedule() async {
    if(!ready || !settings.enabled){return;}
    await cancel();
    if(account==null){return;}
    if(Platform.isAndroid) {
      for(var slot=0;slot<4;slot++){await scheduleAndroidSlot(slot,exact);}
      return;
    }
    if(!Platform.isIOS){return;}
    final prefs=await SharedPreferences.getInstance();
    final now=reminderNow(),location=tz.getLocation('Asia/Bangkok'),who=reminderAccount(account!);
    for(var day=0;day<14;day++) {
      final date=DateTime(now.year,now.month,now.day+day);
      if(!calendar.isWorkday(date)){continue;}
      final cached=prefs.getString(snapshotKey(who,date));
      final snapshot=cached==null?<String,dynamic>{}:jsonDecode(cached) as Map<String,dynamic>;
      for(var slot=0;slot<4;slot++) {
        if(slot==3?snapshot['out']==true:snapshot['in']==true){continue;}
        final time=reminderSlots[slot],at=tz.TZDateTime(location,date.year,date.month,date.day,time.$1,time.$2);
        if(!at.isAfter(tz.TZDateTime.now(location))){continue;}
        await plugin.zonedSchedule(7100+day*4+slot,slot==3?'เตือนเวลาออกงาน':'เตือนเวลาเข้างาน',
          'ถึงเวลาแล้ว เปิดแอปตรวจประวัติและสแกนใบหน้า',at,details(),
          androidScheduleMode:AndroidScheduleMode.inexactAllowWhileIdle,payload:'attendance');
      }
    }
    status='ตั้งเตือนล่วงหน้า 14 วันแล้ว · เปิดแอปเพื่ออัปเดตประวัติและปฏิทิน';
  }
}
Future<void> scheduleAndroidSlot(int slot,bool exact) async {
  await AndroidAlarmManager.oneShotAt(nextReminderInstant(DateTime.now().toUtc(),slot).toLocal(),7010+slot,attendanceAlarm,
    exact:exact,wakeup:true,allowWhileIdle:true,rescheduleOnReboot:true);
}
@pragma('vm:entry-point')
Future<void> attendanceAlarm(int id) async {
  WidgetsFlutterBinding.ensureInitialized();DartPluginRegistrant.ensureInitialized();
  final slot=id-7010;if(slot<0||slot>3){return;}
  final service=ReminderService();
  try {
    await service.initialize();
    if(!service.settings.enabled || service.account==null){return;}
    await scheduleAndroidSlot(slot,service.exact);
    final now=reminderNow(),clock=reminderSlots[slot];
    final delay=now.difference(DateTime(now.year,now.month,now.day,clock.$1,clock.$2));
    if(delay.isNegative || delay>const Duration(minutes:15) || !service.calendar.isWorkday(now)){return;}
    final s=service.account!,who=reminderAccount(s);
    final prefs=await SharedPreferences.getInstance();await prefs.reload();
    final cached=prefs.getString(snapshotKey(who,now));
    final snapshot=cached==null?<String,dynamic>{}:jsonDecode(cached) as Map<String,dynamic>;
    bool hasIn=snapshot['in']==true,hasOut=snapshot['out']==true,known=false;
    HonoApi? api;
    try {
      final material=jsonDecode(await rootBundle.loadString('assets/hono_client_protocol.json')) as Map<String,dynamic>;
      api=HonoApi(WireCodec(material));
      final entries=await api.history(s,now).timeout(const Duration(seconds:25));
      known=true;
      hasIn=hasIn||entries.any((l)=>l.flag.toUpperCase()=='I');hasOut=hasOut||entries.any((l)=>l.flag.toUpperCase()=='O');
      await service.recordSnapshot(s,now,entries);
    } catch (_) { /* Unknown is displayed as unknown, never as a missing punch. */ }
    finally {api?.close();}
    await prefs.reload();
    if(prefs.getString('reminder_active_account')!=who){return;}
    final latest=ReminderPreferences.fromJson(jsonDecode(prefs.getString('reminder_preferences')??'{}') as Map<String,dynamic>);
    if(!latest.enabled){return;}
    final decision=reminderDecision(workday:true,exit:slot==3,known:known,hasIn:hasIn,hasOut:hasOut);
    if(decision==ReminderDecision.suppress || (decision==ReminderDecision.unknown&&!latest.notifyUnknown)){return;}
    await service.plugin.show(id,slot==3?'เตือนเวลาออกงาน':'เตือนเวลาเข้างาน',
      decision==ReminderDecision.unknown?'ยังตรวจ HONO ล่าสุดไม่ได้ เปิดแอปเพื่อตรวจสถานะ':
      slot==3?'ยังไม่พบเวลาออกงานวันนี้ เปิดแอปเพื่อสแกนใบหน้า':'ยังไม่พบเวลาเข้างานวันนี้ เปิดแอปเพื่อสแกนใบหน้า',
      service.details(),payload:'attendance');
  } catch (_) { /* OS permission/session failures must not crash a background isolate. */ }
}
