import 'package:flutter/material.dart';
import 'design.dart';

// Bangkok wall time, matching the existing 18:00 checkout reminder.
// HONO's outTime is a punch time, not a scheduled shift end.
int earlyCheckoutMinutes(DateTime now) {
  final end = DateTime(now.year, now.month, now.day, 18);
  if (!now.isBefore(end)) return 0;
  return (end.difference(now).inMilliseconds / 60000).ceil();
}

class EarlyCheckoutDialog extends StatelessWidget {
  const EarlyCheckoutDialog({super.key, required this.now});
  final DateTime now;
  @override
  Widget build(BuildContext context) {
    final clock =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    return AlertDialog(
      scrollable: true,
      icon: const NwlIcon(Icons.schedule_rounded, color: amber, size: 32),
      title: const Text('ออกก่อนเวลาเลิกงาน?'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ตอนนี้ $clock น. · เวลาเลิกงานที่ใช้เตือน 18:00 น.'),
            const SizedBox(height: 12),
            Text(
              'เร็วกว่าเวลาเลิกงาน ${earlyCheckoutMinutes(now)} นาที',
              style: const TextStyle(color: amber, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            const Text(
              'หากดำเนินการต่อ เมื่อสแกนใบหน้าผ่าน ระบบจะส่งลงเวลาออกให้อัตโนมัติ',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('ยังไม่ออก'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('ยืนยันและสแกนหน้า'),
        ),
      ],
    );
  }
}
