import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/controller.dart';
import 'ui/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor:Colors.transparent,statusBarIconBrightness:Brightness.light,systemNavigationBarColor:Color(0xFF0D1420)));
  final controller=AppController();
  runApp(NwlApp(controller:controller));
  controller.init();
}
