import 'package:flutter/material.dart';

const ink = Color(0xFF0D1420),
    panel = Color(0xFF172130),
    mint = Color(0xFF79E6C5),
    lavender = Color(0xFFC5B7F6),
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
    filled: false,
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
    indicatorColor: Color(0xFF49435B),
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
  Widget build(BuildContext context) {
    final logo = Image.asset(
      'assets/brand.png',
      width: large ? 116 : 42,
      height: large ? 116 : 42,
      fit: BoxFit.contain,
    );
    if (large) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          logo,
          const SizedBox(height: 24),
          const Text(
            'NWL',
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Secret Login',
            style: TextStyle(fontSize: 17, letterSpacing: 3, color: muted),
          ),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        logo,
        const SizedBox(width: 12),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'NWL',
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
            Text(
              'Secret Login',
              style: TextStyle(
                fontSize: 12,
                color: muted,
                letterSpacing: .5,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ],
    );
  }
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
          Icon(icon, size: 23),
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
        Icon(
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
  const PageBody({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    ),
  );
}
