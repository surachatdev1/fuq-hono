import 'package:flutter/material.dart';
import 'app_icons.dart';
import 'art_motion.dart';
export 'app_icons.dart';
export 'art_motion.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();

const ink = Color(0xFF050C1F),
    panel = Color(0xFF111C31),
    mint = Color(0xFFE0FFB4),
    lavender = Color(0xFFBAC6FF),
    muted = Color(0xFFA9B7CC),
    paper = Color(0xFFF4F7FC),
    amber = Color(0xFFFFCA78);
ThemeData appTheme() => ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: ink,
  fontFamily: 'NotoSansThai',
  fontFamilyFallback: const ['NotoSans'],
  colorScheme: const ColorScheme.dark(
    primary: mint,
    onPrimary: ink,
    surface: ink,
    onSurface: paper,
    secondary: lavender,
    error: amber,
  ),
  textTheme: const TextTheme(
    headlineLarge: TextStyle(
      fontSize: 34,
      height: 1.35,
      fontWeight: FontWeight.w600,
      letterSpacing: -.8,
    ),
    headlineMedium: TextStyle(
      fontSize: 28,
      height: 1.4,
      fontWeight: FontWeight.w600,
      letterSpacing: -.4,
    ),
    titleLarge: TextStyle(
      fontSize: 22,
      height: 1.45,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: TextStyle(
      fontSize: 17,
      height: 1.5,
      fontWeight: FontWeight.w500,
    ),
    bodyLarge: TextStyle(fontSize: 16, height: 1.65),
    bodyMedium: TextStyle(fontSize: 14, height: 1.6),
    bodySmall: TextStyle(fontSize: 12, height: 1.6, color: muted),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: panel,
    labelStyle: const TextStyle(color: muted),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFF53647B)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFF53647B)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: mint, width: 1.5),
    ),
  ),
  navigationBarTheme: const NavigationBarThemeData(
    backgroundColor: ink,
    indicatorColor: Color(0xFF263C36),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: ink,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
  ),
  iconTheme: const IconThemeData(size: 22, color: muted),
  iconButtonTheme: IconButtonThemeData(
    style: IconButton.styleFrom(
      foregroundColor: muted,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
    ),
  ),
  progressIndicatorTheme: const ProgressIndicatorThemeData(
    color: mint,
    linearTrackColor: Color(0xFF25354C),
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: panel,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
  ),
  dividerTheme: const DividerThemeData(color: Color(0xFF2B3748), space: 32),
  snackBarTheme: const SnackBarThemeData(
    backgroundColor: panel,
    contentTextStyle: TextStyle(color: paper),
  ),
);

class Brand extends StatelessWidget {
  const Brand({super.key, this.large = false});
  final bool large;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'NWL Secret Login',
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: large
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          'nwl',
          style: TextStyle(
            fontFamily: 'NotoSans',
            fontSize: large ? 66 : 34,
            height: 1.05,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.8,
            color: mint,
          ),
        ),
        SizedBox(height: large ? 12 : 3),
        Text(
          'Secret Login',
          style: TextStyle(
            fontFamily: 'NotoSans',
            fontSize: large ? 14 : 10,
            letterSpacing: large ? 3.5 : 1.6,
            color: muted,
          ),
        ),
      ],
    ),
  );
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton(
    this.label, {
    super.key,
    this.onPressed,
    this.busy = false,
    this.icon = Icons.arrow_forward_rounded,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData icon;
  @override
  Widget build(BuildContext context) => FilledButton(
    style: FilledButton.styleFrom(
      minimumSize: const Size(double.infinity, 64),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    onPressed: busy ? null : onPressed,
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 12),
        if (busy)
          const SizedBox.square(
            dimension: 21,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          NwlIcon(icon, size: 23),
      ],
    ),
  );
}

class Notice extends StatelessWidget {
  const Notice(this.text, {super.key, this.warning = false});
  final String text;
  final bool warning;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: panel,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NwlIcon(
          warning
              ? Icons.info_outline_rounded
              : Icons.check_circle_outline_rounded,
          color: warning ? amber : mint,
          size: 21,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: warning ? amber : paper,
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ),
      ],
    ),
  );
}

class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children, this.maxWidth = 760});
  final double maxWidth;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
    child: Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    ),
  );
}

class LoginBody extends StatelessWidget {
  const LoginBody({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final form = PageBody(maxWidth: 480, children: children);
      if (c.maxWidth < 1000) return form;
      return Row(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, area) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: area.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.all(48),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Brand(),
                        const SizedBox(height: 24),
                        Center(
                          child: TimeArtwork(
                            size: (area.maxHeight * .28).clamp(150, 240),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'เริ่มวันอย่างเรียบง่าย',
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'เวลาเข้างาน ประวัติ และวันทำงานของคุณ\nรวมไว้ในพื้นที่ที่สบายตา',
                          style: TextStyle(color: muted, height: 1.8),
                        ),
                        const SizedBox(height: 28),
                        const Text(
                          'EVERYDAY, CONSIDERED.',
                          style: TextStyle(
                            color: mint,
                            fontSize: 10,
                            letterSpacing: 2.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: form),
        ],
      );
    },
  );
}

class DayBody extends StatelessWidget {
  const DayBody({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      // Split at the workflow legend so the status and next action sit side by side.
      final split = children.indexWhere((w) => w is Wrap);
      if (c.maxWidth < 1000 || split < 0) return PageBody(children: children);
      return SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1160),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children.take(split).toList(),
                  ),
                ),
                const SizedBox(width: 40),
                Expanded(
                  flex: 5,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: panel,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'พร้อมสำหรับก้าวถัดไป',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 24),
                        ...children.skip(split),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
