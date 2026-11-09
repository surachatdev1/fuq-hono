import 'dart:async';
import 'package:flutter/material.dart';
import '../core/controller.dart';
import 'design.dart';

class AlarmPrompt extends StatelessWidget {
  const AlarmPrompt({super.key, required this.controller, this.clockTime});
  final AppController controller;
  final DateTime? clockTime;
  @override
  Widget build(BuildContext context) {
    final now = clockTime ?? bangkokNow(), exit = controller.reminderExit;
    final clock =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                children: [
                  const Brand(),
                  const SizedBox(height: 44),
                  Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: mint.withValues(alpha: .10),
                      border: Border.all(color: mint.withValues(alpha: .25)),
                    ),
                    child: const Icon(
                      Icons.alarm_rounded,
                      size: 54,
                      color: mint,
                    ),
                  ),
                  const SizedBox(height: 26),
                  Text(
                    clock,
                    style: const TextStyle(
                      fontFamily: 'NotoSans',
                      fontSize: 72,
                      fontWeight: FontWeight.w300,
                      letterSpacing: -3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    exit ? 'ถึงเวลาออกงานแล้ว' : 'พร้อมเริ่มวันทำงาน',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'ตรวจข้อมูลวันนี้ในเครื่องแล้ว\nเปิดหน้าลงเวลาเพื่อตรวจสถานะล่าสุดและสแกนใบหน้า',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: muted, height: 1.8),
                  ),
                  const SizedBox(height: 36),
                  SizedBox(
                    width: double.infinity,
                    child: PrimaryButton(
                      controller.session == null
                          ? 'เข้าสู่ระบบเพื่อลงเวลา'
                          : 'เปิดหน้าลงเวลา',
                      onPressed: () {
                        appNavigatorKey.currentState?.popUntil(
                          (route) => route.isFirst,
                        );
                        controller.dismissReminder();
                        unawaited(controller.changeDate(bangkokNow()));
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: controller.dismissReminder,
                    child: const Text(
                      'ปิดการปลุก',
                      style: TextStyle(color: muted),
                    ),
                  ),
                  const SizedBox(height: 26),
                  const Text(
                    'การปิดเสียงไม่ถือว่าได้ลงเวลาแล้ว',
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
