import 'dart:io';
import 'package:flutter/material.dart';
import '../core/controller.dart';
import '../data/hono.dart';
import 'design.dart';
import 'history_insights.dart';

class ReminderPreferencesPage extends StatefulWidget {
  const ReminderPreferencesPage({super.key, required this.controller});
  final AppController controller;
  @override
  State<ReminderPreferencesPage> createState() =>
      _ReminderPreferencesPageState();
}

class _ReminderPreferencesPageState extends State<ReminderPreferencesPage> {
  bool busy = false;
  String message = '';
  AppController get c => widget.controller;
  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      message = '';
    });
    try {
      await action();
      if (mounted) setState(() => message = c.reminders.status);
    } catch (e) {
      if (mounted) setState(() => message = friendly(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> addException(bool work) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: bangkokNow(),
      firstDate: DateTime(2020),
      lastDate: DateTime(bangkokNow().year + 3),
    );
    if (picked == null) return;
    await run(() async {
      final key = HonoApi.dateKey(picked);
      if (work) {
        c.calendar.holidays.remove(key);
        c.calendar.extraWorkdays.add(key);
      } else {
        c.calendar.extraWorkdays.remove(key);
        c.calendar.holidays.add(key);
      }
      await c.saveCalendar();
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = c.reminders;
    final exceptions = {
      for (final k in c.calendar.holidays) k: false,
      for (final k in c.calendar.extraWorkdays) k: true,
    }.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return Scaffold(
      appBar: AppBar(title: const Text('เตือนลงเวลาและวันทำงาน')),
      body: SafeArea(
        child: PageBody(
          children: [
            Text(
              'ไม่พลาดเวลาสำคัญ',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            const Text(
              'เข้า 08:20 · 08:30 · 08:50\nออก 18:00 · เขตเวลาไทย',
              style: TextStyle(color: muted, height: 1.8),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('เปิดเตือนลงเวลา'),
              subtitle: Text(
                c.session == null
                    ? 'เข้าสู่ระบบก่อนเปิดการเตือน'
                    : 'หยุดเตือนเข้าเมื่อพบเวลาเข้า และหยุดเตือนออกเมื่อพบเวลาออก',
              ),
              value: r.settings.enabled,
              onChanged: busy || c.session == null
                  ? null
                  : (v) => run(() async {
                      await r.bind(c.session!);
                      await r.setEnabled(v);
                    }),
            ),
            SwitchListTile(contentPadding:EdgeInsets.zero,value:r.settings.alarmStyle,
              title:const Text('ปลุกแบบนาฬิกาปลุก'),subtitle:const Text('Android มีปุ่มหยุดเสียง จำกัด 60 วินาที · เต็มจอตามสิทธิ์ที่ระบบอนุญาต'),
              onChanged:busy?null:(v)=>run(()async{r.settings.alarmStyle=v;await c.reminderSettingsChanged();})),
            if(Platform.isAndroid)TextButton.icon(onPressed:busy?null:()=>run(r.allowFullScreen),icon:const Icon(Icons.fullscreen),label:const Text('อนุญาตหน้าปลุกเต็มจอ')),
            const SizedBox(height: 12),
            Notice(
              Platform.isAndroid
                  ? 'ก่อนปลุกจะตรวจข้อมูลในเครื่อง ไม่เรียก API หากลงเวลาจากแอปอื่นให้เปิดแอปนี้เพื่อซิงก์ · การปิดบังคับแอปหรือประหยัดแบตเตอรี่อาจทำให้ไม่เตือน'
                  : 'iOS ใช้ข้อมูลซิงก์ล่าสุด ตั้งล่วงหน้า 14 วัน เปิดแอปเพื่ออัปเดตและหยุดเตือนเมื่อมีรายการจากแอปอื่น',
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: ValueKey(r.settings.sound),
              initialValue: r.settings.sound,
              decoration: const InputDecoration(labelText: 'เสียงเตือน'),
              items: [
                const DropdownMenuItem(
                  value: 'system',
                  child: Text('เสียงระบบ'),
                ),
                const DropdownMenuItem(value: 'soft', child: Text('นุ่มนวล')),
                const DropdownMenuItem(value: 'chime', child: Text('ชัดเจน')),
                const DropdownMenuItem(value: 'silent', child: Text('เงียบ')),
                if (r.settings.sound == 'custom')
                  const DropdownMenuItem(
                    value: 'custom',
                    child: Text('เสียงที่เลือกจากเครื่อง'),
                  ),
              ],
              onChanged: busy
                  ? null
                  : (v) => run(() async {
                      r.settings.sound = v ?? 'system';
                      await c.reminderSettingsChanged();
                    }),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: busy ? null : () => run(r.preview),
                  icon: const Icon(Icons.volume_up_outlined),
                  label: const Text('ทดลองเสียง'),
                ),
                if (Platform.isAndroid)
                  TextButton.icon(
                    onPressed: busy ? null : () => run(r.chooseDeviceSound),
                    icon: const Icon(Icons.library_music_outlined),
                    label: const Text('เลือกเสียงในเครื่อง'),
                  ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: r.settings.notifyUnknown,
              title: const Text('เตือนเมื่อยังไม่มีข้อมูลวันนี้ในเครื่อง'),
              subtitle: const Text(
                'เตือนให้ตรวจสอบ โดยไม่ยืนยันว่าคุณยังไม่ลงเวลา',
              ),
              onChanged: busy
                  ? null
                  : (v) => run(() async {
                      r.settings.notifyUnknown = v;
                      await c.reminderSettingsChanged();
                    }),
            ),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 12),
              Notice(message),
            ],
            if (busy) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            const Divider(),
            Text(
              'ปฏิทินวันทำงาน',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            const Text(
              'ตั้งให้ตรงปฏิทินของบริษัท วันหยุดด้านล่างเป็นข้อมูลที่คุณกำหนดในแอป ยังไม่ได้ซิงก์ปฏิทินวันหยุดจาก HONO',
              style: TextStyle(color: muted),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var day = 1; day <= 7; day++)
                  FilterChip(
                    label: Text(['จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส', 'อา'][day - 1]),
                    selected: c.calendar.weekdays.contains(day),
                    onSelected: busy
                        ? null
                        : (value) => run(() async {
                            if (value) {
                              c.calendar.weekdays.add(day);
                            } else {
                              c.calendar.weekdays.remove(day);
                            }
                            await c.saveCalendar();
                          }),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: busy ? null : () => addException(false),
                  icon: const Icon(Icons.event_busy_outlined),
                  label: const Text('เพิ่มวันหยุด'),
                ),
                OutlinedButton.icon(
                  onPressed: busy ? null : () => addException(true),
                  icon: const Icon(Icons.event_available_outlined),
                  label: const Text('เพิ่มวันทำงานพิเศษ'),
                ),
              ],
            ),
            for (final e in exceptions)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(insightDate(DateTime.parse(e.key))),
                subtitle: Text(e.value ? 'วันทำงานพิเศษ' : 'วันหยุด'),
                trailing: IconButton(
                  tooltip: 'ลบวันที่กำหนด',
                  onPressed: busy
                      ? null
                      : () => run(() async {
                          c.calendar.holidays.remove(e.key);
                          c.calendar.extraWorkdays.remove(e.key);
                          await c.saveCalendar();
                        }),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
