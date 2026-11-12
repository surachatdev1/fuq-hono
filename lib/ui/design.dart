import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'app_icons.dart';
import 'art_motion.dart';
export 'app_icons.dart';
export 'art_motion.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();

const cinematicEnabled = kIsWeb && bool.fromEnvironment('NWL_CINEMATIC');
const midnight = Color(0xFF080F25);
const cinematicPanel = Color(0xFF131F3A);
const electricLime = Color(0xFFE1FA93);
const cobalt = Color(0xFF305CF5);
const coral = Color(0xFFFF8974);
const cinematicLine = Color(0xFF344464);
const cinematicArt = 'assets/cinematic';

bool reduceCinematicMotion(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context) ||
    MediaQuery.accessibleNavigationOf(context);

const ink = cinematicEnabled ? midnight : Color(0xFF070F24),
    panel = cinematicEnabled ? cinematicPanel : Color(0xFF111C34),
    mint = cinematicEnabled ? electricLime : Color(0xFFE0FFB4),
    lavender = Color(0xFF8BA2FF),
    muted = Color(0xFFA5B2CA),
    paper = Color(0xFFF4F7FF),
    amber = Color(0xFFFFC477);
ThemeData appTheme() => ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: ink,
  fontFamily: 'NotoSansThai',
  fontFamilyFallback: const ['NotoSans'],
  colorScheme: const ColorScheme.dark(
    primary: mint,
    onPrimary: ink,
    surface: panel,
    onSurface: paper,
    secondary: lavender,
    error: cinematicEnabled ? coral : Color(0xFFFF8378),
    outline: Color(0xFF2B3B59),
    surfaceContainerHighest: Color(0xFF1B2B48),
  ),
  textTheme: const TextTheme(
    headlineLarge: TextStyle(
      fontSize: 30,
      height: 1.35,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    ),
    headlineMedium: TextStyle(
      fontSize: 26,
      height: 1.4,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
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
    fillColor: cinematicEnabled ? const Color(0xFF111B34) : panel,
    labelStyle: const TextStyle(color: muted),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF2B3B59)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF2B3B59)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: mint, width: 1.5),
    ),
  ),
  navigationBarTheme: const NavigationBarThemeData(
    backgroundColor: panel,
    elevation: 0,
    surfaceTintColor: Colors.transparent,
    indicatorColor: Color(0xFF293D3E),
    iconTheme: WidgetStateProperty.fromMap({
      WidgetState.selected: IconThemeData(color: mint, size: 22),
      WidgetState.any: IconThemeData(color: muted, size: 22),
    }),
  ),
  navigationRailTheme: const NavigationRailThemeData(
    backgroundColor: panel,
    selectedIconTheme: IconThemeData(color: mint, size: 22),
    unselectedIconTheme: IconThemeData(color: muted, size: 22),
    indicatorColor: Color(0xFF293D3E),
  ),
  segmentedButtonTheme: SegmentedButtonThemeData(
    style: ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? const Color(0xFF293D3E)
            : Colors.transparent,
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? mint : muted,
      ),
      side: WidgetStateProperty.all(const BorderSide(color: Color(0xFF2B3B59))),
    ),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: panel,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      elevation: 0,
      shadowColor: Colors.transparent,
    ),
  ),
  cardTheme: const CardThemeData(
    color: panel,
    elevation: 0,
    surfaceTintColor: Colors.transparent,
    margin: EdgeInsets.zero,
  ),
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: panel,
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
    linearTrackColor: Color(0xFF263651),
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: panel,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  ),
  dividerTheme: const DividerThemeData(color: Color(0xFF2B3B59), space: 32),
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
            fontStyle: cinematicEnabled ? FontStyle.italic : FontStyle.normal,
            fontWeight: FontWeight.w700,
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
      elevation: 0,
      minimumSize: const Size(double.infinity, cinematicEnabled ? 50 : 58),
      padding: const EdgeInsets.symmetric(
        horizontal: cinematicEnabled ? 18 : 22,
        vertical: cinematicEnabled ? 11 : 16,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cinematicEnabled ? 16 : 12),
      ),
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
          NwlIcon(
            icon,
            size: 23,
            color: onPressed == null ? muted.withValues(alpha: .45) : ink,
          ),
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
      borderRadius: BorderRadius.circular(12),
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
    padding: EdgeInsets.fromLTRB(
      MediaQuery.sizeOf(context).width < 380 ? 20 : 24,
      MediaQuery.sizeOf(context).height < 740 ? 8 : 24,
      MediaQuery.sizeOf(context).width < 380 ? 20 : 24,
      MediaQuery.sizeOf(context).height < 740 ? 8 : 32,
    ),
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
      final compact =
          c.maxWidth < 600 && MediaQuery.sizeOf(context).height < 740;
      final form = Center(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.all(compact ? 12 : 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            padding: EdgeInsets.all(
              compact
                  ? 12
                  : c.maxWidth < 600
                  ? 24
                  : 32,
            ),
            decoration: BoxDecoration(
              color: panel,
              border: Border.all(color: const Color(0xFF2B3B59)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      );
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
                        const SizedBox(height: 40),
                        Center(
                          child: TimeArtwork(
                            size: (area.maxHeight * .28).clamp(160, 220),
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
                          'TIME, SIMPLIFIED.',
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
          Expanded(child: form),
        ],
      );
    },
  );
}
