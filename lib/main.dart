import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'core/controller.dart';
import 'ui/app.dart';
import 'ui/login_motion.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF070F24),
    ),
  );
  final controller = AppController();
  runApp(
    NwlApp(
      controller: controller,
      home: kIsWeb && Uri.base.queryParameters['preview'] == 'login-motion'
          ? const LoginMotionPreview()
          : null,
    ),
  );
  controller.init();
}
