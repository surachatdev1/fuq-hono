import 'package:flutter/material.dart';
import '../features/web_permission_access.dart';
import 'design.dart';

/// Explicit first-login setup for browser users on iOS, Android and desktop.
/// Permission prompts must be initiated by a tap; merely opening this dialog
/// never requests the camera, location, microphone or notifications.
class WebPermissionSetupDialog extends StatefulWidget {
  const WebPermissionSetupDialog({super.key});

  @override
  State<WebPermissionSetupDialog> createState() =>
      _WebPermissionSetupDialogState();
}

class _WebPermissionSetupDialogState extends State<WebPermissionSetupDialog> {
  bool checking = false;
  bool cameraGranted = false;
  String cameraMessage = 'แตะปุ่มด้านล่างเพื่อให้เบราว์เซอร์ขอสิทธิ์กล้อง';
  String audioMessage = '';

  Future<void> requestCamera() async {
    if (checking) return;
    setState(() => checking = true);
    String result;
    try {
      result = await requestCameraAccess();
    } catch (_) {
      result = 'error';
    }
    if (!mounted) return;
    setState(() {
      checking = false;
      cameraGranted = result == 'granted';
      cameraMessage = switch (result) {
        'granted' => 'กล้องพร้อมใช้งานแล้ว ✓ สามารถสแกนใบหน้าได้เมื่อเลือกลงเวลา',
        'denied' =>
          'เบราว์เซอร์ไม่อนุญาตกล้อง ให้เปิดสิทธิ์ Camera ในการตั้งค่าเว็บไซต์ของ Safari/Chrome แล้วลองใหม่',
        'missing' => 'ไม่พบกล้องที่ใช้งานได้ กรุณาตรวจกล้องหน้าหรืออุปกรณ์ที่เชื่อมต่อ',
        'unavailable' =>
          'เบราว์เซอร์นี้ไม่รองรับการเปิดกล้อง กรุณาเปิดลิงก์ใน Safari หรือ Chrome โดยตรง',
        _ => 'เปิดกล้องไม่สำเร็จ กรุณาตรวจสิทธิ์เว็บไซต์และลองอีกครั้ง',
      };
    });
  }

  void previewSound() {
    String result;
    try {
      result = testReminderSound();
    } catch (_) {
      result = 'error';
    }
    setState(() {
      audioMessage = result == 'played'
          ? 'ส่งเสียงทดสอบแล้ว หากไม่ได้ยิน ให้ตรวจโหมดเงียบและระดับเสียง'
          : 'เบราว์เซอร์ไม่สามารถเล่นเสียงทดสอบได้';
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
    icon: const Icon(Icons.security_rounded, color: mint, size: 30),
    title: const Text('เตรียมสิทธิ์ก่อนใช้งาน', textAlign: TextAlign.center),
    content: SizedBox(
      width: 410,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'ตั้งค่าเพียงครั้งแรกบนเบราว์เซอร์นี้ เพื่อให้ลงเวลาได้สะดวกบน iPhone, Android และคอมพิวเตอร์',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted, fontSize: 13),
          ),
          const SizedBox(height: 20),
          _PermissionRow(
            icon: Icons.camera_front_rounded,
            title: 'กล้องหน้า',
            subtitle: 'จำเป็นสำหรับการกะพริบตาและยืนยันใบหน้าตอนลงเวลา',
            mandatory: true,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: checking ? null : requestCamera,
            icon: Icon(
              cameraGranted
                  ? Icons.check_circle_rounded
                  : Icons.camera_alt_outlined,
              size: 20,
            ),
            label: Text(
              checking
                  ? 'กำลังตรวจกล้อง…'
                  : cameraGranted
                  ? 'ตรวจกล้องอีกครั้ง'
                  : 'อนุญาตและตรวจกล้อง',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            cameraMessage,
            style: TextStyle(
              fontSize: 12,
              color: cameraGranted ? mint : muted,
            ),
          ),
          const Divider(height: 30),
          const _PermissionRow(
            icon: Icons.notifications_active_outlined,
            title: 'เสียงเตือนการลงเวลา',
            subtitle: 'ทดสอบเสียงได้ ไม่ต้องขอสิทธิ์ไมโครโฟนหรือการแจ้งเตือน',
            mandatory: false,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: previewSound,
              icon: const Icon(Icons.volume_up_outlined, size: 18),
              label: const Text('ทดสอบเสียง'),
            ),
          ),
          if (audioMessage.isNotEmpty)
            Text(audioMessage, style: const TextStyle(fontSize: 12, color: muted)),
          const SizedBox(height: 8),
          const Text(
            'การเตือนบนเว็บทำงานเฉพาะเมื่อเปิดหน้าเว็บอยู่ ไม่ใช่การแจ้งเตือนที่ปลุกเครื่องได้เมื่อปิด Safari/Chrome',
            style: TextStyle(fontSize: 12, color: muted),
          ),
          const SizedBox(height: 10),
          const Text(
            'ไม่ขอตำแหน่ง GPS หรือไมโครโฟน เพราะระบบใช้หมุดสถานที่ที่คุณเลือกเอง',
            style: TextStyle(fontSize: 12, color: muted),
          ),
          const SizedBox(height: 12),
          const Text(
            'หากเคยกดปฏิเสธกล้อง ให้เปิด Safari/Chrome → การตั้งค่าเว็บไซต์ → Camera แล้วอนุญาต หรือเปิดเว็บในเบราว์เซอร์โดยตรงแทนในแอปแชต',
            style: TextStyle(fontSize: 12, color: muted),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, true),
        child: Text(cameraGranted ? 'เสร็จสิ้น' : 'เข้าใช้งานก่อน'),
      ),
    ],
  );
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.mandatory,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final bool mandatory;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: mint, size: 24),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(
                  mandatory ? 'จำเป็น' : 'เลือกได้',
                  style: const TextStyle(fontSize: 11, color: muted),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: muted)),
          ],
        ),
      ),
    ],
  );
}
