import 'dart:async';
import 'package:flutter/material.dart';
import '../core/models.dart';
import 'design.dart';
import 'login_motion_abstract.dart';
export 'login_motion_abstract.dart';

/// Approved production motion; retained name for existing callers.
typedef LoginMotionPage = AbstractLoginMotionPage;

/// A review-only route. It never creates a session or sends an attendance request.
class LoginMotionPreview extends StatefulWidget {
  const LoginMotionPreview({super.key});
  @override
  State<LoginMotionPreview> createState() => _LoginMotionPreviewState();
}

class _LoginMotionPreviewState extends State<LoginMotionPreview> {
  LoginStage stage = LoginStage.connecting;
  final timers = <Timer>[];
  @override
  void initState() {
    super.initState();
    play();
  }

  void stop() {
    for (final timer in timers) {
      timer.cancel();
    }
    timers.clear();
  }

  void play() {
    stop();
    stage = LoginStage.connecting;
    timers.add(
      Timer(const Duration(milliseconds: 3500), () {
        if (mounted) setState(() => stage = LoginStage.contact);
      }),
    );
    timers.add(
      Timer(const Duration(milliseconds: 4000), () {
        if (mounted) setState(() => stage = LoginStage.connected);
      }),
    );
  }

  void select(LoginStage next) {
    stop();
    setState(() => stage = next);
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          Material(
            color: ink,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    'ตัวอย่างเท่านั้น ไม่ได้เข้าสู่ระบบ',
                    style: TextStyle(fontSize: 10, color: muted),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(play);
                    },
                    child: const Text('เล่นอีกครั้ง'),
                  ),
                  TextButton(
                    onPressed: () => select(LoginStage.connecting),
                    child: const Text('กำลังเชื่อมต่อ'),
                  ),
                  TextButton(
                    onPressed: () => select(LoginStage.connected),
                    child: const Text('สำเร็จ'),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: AbstractLoginMotionPage(stage: stage, modal: false)),
        ],
      ),
    ),
  );
}
