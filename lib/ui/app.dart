import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../core/controller.dart';
import '../core/models.dart';
import '../data/hono.dart';
import '../data/maps.dart';
import '../data/open_external_stub.dart'
    if (dart.library.js_interop) '../data/open_external_web.dart';
import '../features/attendance_insights.dart';
import 'artwork_image.dart';
import 'camera.dart';
import 'cinematic.dart';
import 'design.dart';
import 'history_insights.dart';
import 'reminder_preferences.dart';
import 'alarm_prompt.dart';
import 'login_motion_abstract.dart';
import 'early_checkout.dart';
import 'web_permission_setup.dart';
import 'payslip_page.dart';

class NwlApp extends StatelessWidget {
  const NwlApp({super.key, required this.controller, this.home});
  final AppController controller;
  final Widget? home;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'NWL Secret Login',
    navigatorKey: appNavigatorKey,
    builder: (context, child) => AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Stack(
        fit: StackFit.expand,
        children: [
          if (child != null) child,
          if (controller.reminderPrompt) AlarmPrompt(controller: controller),
          if (controller.loginStage != LoginStage.idle)
            AbstractLoginMotionPage(stage: controller.loginStage),
        ],
      ),
    ),
    debugShowCheckedModeBanner: false,
    theme: appTheme(),
    locale: const Locale('th'),
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    supportedLocales: const [Locale('th'), Locale('en')],
    home:
        home ??
        AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            if (!controller.ready) {
              return cinematicEnabled
                  ? const CinematicSplash()
                  : const SplashPage();
            }
            if (controller.session == null && !controller.demo) {
              return LoginPage(controller: controller);
            }
            return HomePage(controller: controller);
          },
        ),
  );
}

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: c.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 32,
                  ),
                  child: Column(
                    children: [
                      SizedBox(height: c.maxHeight * .21),
                      const Brand(large: true),
                      SizedBox(height: c.maxHeight * .14),
                      Text(
                        'พร้อมสำหรับวันทำงานของคุณ',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 32),
                      const SizedBox(
                        width: 220,
                        child: LinearProgressIndicator(
                          minHeight: 3,
                          borderRadius: BorderRadius.all(Radius.circular(3)),
                        ),
                      ),
                      const SizedBox(height: 40),
                      const Text(
                        'A QUIETER WAY TO START',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 2,
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.controller});
  final AppController controller;
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final form = GlobalKey<FormState>();
  late final TextEditingController company, employee, password;
  bool remember = true, hidden = true, _motionPrecached = false;
  bool engaged = false;
  @override
  void initState() {
    super.initState();
    company = TextEditingController(text: widget.controller.company);
    employee = TextEditingController(text: widget.controller.employee);
    password = TextEditingController(text: widget.controller.password);
    remember = widget.controller.remember;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_motionPrecached) {
      _motionPrecached = true;
      for (final asset in [
        'assets/motion/login-hands.png',
        'assets/motion/abstract-glass.webp',
        'assets/motion/palm-rise.webp',
        if (cinematicEnabled) ...[
          '$cinematicArt/energy.webp',
          '$cinematicArt/login.webp',
        ],
      ]) {
        precacheImage(
          artworkImage(asset),
          context,
          onError: (Object error, StackTrace? stack) {},
        );
      }
    }
  }

  @override
  void dispose() {
    company.dispose();
    employee.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> login() async {
    if (!form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final ok = await widget.controller.login(
      company.text,
      employee.text,
      password.text,
      remember,
      skipMotionDelay: cinematicEnabled && reduceCinematicMotion(context),
    );
    if (ok && mounted) password.clear();
  }

  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.sizeOf(context).width < 600 &&
        MediaQuery.sizeOf(context).height < 740;
    final width = MediaQuery.sizeOf(context).width;
    final formGap = cinematicEnabled ? 12.0 : (compact ? 8.0 : 22.0);
    final children = <Widget>[
      if (cinematicEnabled && width >= 880)
        SizedBox(
          height: 138,
          child: AnimatedScale(
            scale: engaged ? 1.035 : 1,
            duration: reduceCinematicMotion(context)
                ? Duration.zero
                : const Duration(milliseconds: 240),
            child: const MascotArt('login'),
          ),
        ),
      if (!cinematicEnabled && width < 1000) ...[
        Row(
          children: [
            const Expanded(child: Brand()),
            if (!compact) const TimeArtwork(size: 64),
          ],
        ),
        SizedBox(height: compact ? 8 : 24),
      ] else if (!cinematicEnabled)
        SizedBox(height: compact ? 8 : 24),
      Text(
        cinematicEnabled ? 'เข้าสู่ระบบ' : 'เริ่มวันทำงานของคุณ',
        textAlign: cinematicEnabled ? TextAlign.center : TextAlign.start,
        style: compact
            ? Theme.of(context).textTheme.titleLarge
            : Theme.of(context).textTheme.headlineLarge,
      ),
      SizedBox(height: cinematicEnabled ? 3 : 10),
      if (!compact || cinematicEnabled)
        Text(
          'เข้าสู่ระบบด้วยบัญชีบริษัท',
          textAlign: cinematicEnabled ? TextAlign.center : TextAlign.start,
          style: const TextStyle(color: muted),
        ),
      SizedBox(height: cinematicEnabled ? 15 : (compact ? 10 : 28)),
      Focus(
        onFocusChange: (value) {
          if (cinematicEnabled) setState(() => engaged = value);
        },
        child: Form(
          key: form,
          child: AutofillGroup(
            child: Column(
              children: [
                TextFormField(
                  controller: company,
                  enabled: !widget.controller.busy,
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'รหัสบริษัท'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'กรอกรหัสบริษัท' : null,
                ),
                SizedBox(height: formGap),
                TextFormField(
                  controller: employee,
                  enabled: !widget.controller.busy,
                  autocorrect: false,
                  autofillHints: const [AutofillHints.username],
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'รหัสพนักงาน'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'กรอกรหัสพนักงาน' : null,
                ),
                SizedBox(height: formGap),
                TextFormField(
                  controller: password,
                  enabled: !widget.controller.busy,
                  obscureText: hidden,
                  autocorrect: false,
                  autofillHints: const [AutofillHints.password],
                  onFieldSubmitted: (_) => login(),
                  decoration: InputDecoration(
                    labelText: 'รหัสผ่าน',
                    suffixIcon: IconButton(
                      tooltip: hidden ? 'แสดงรหัสผ่าน' : 'ซ่อนรหัสผ่าน',
                      onPressed: () => setState(() => hidden = !hidden),
                      icon: NwlIcon(
                        hidden
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 20,
                      ),
                    ),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'กรอกรหัสผ่าน' : null,
                ),
              ],
            ),
          ),
        ),
      ),
      SizedBox(height: cinematicEnabled ? 4 : formGap),
      CheckboxListTile(
        dense: compact || cinematicEnabled,
        visualDensity: compact || cinematicEnabled
            ? VisualDensity.compact
            : VisualDensity.standard,
        value: remember,
        onChanged: widget.controller.busy
            ? null
            : (v) => setState(() => remember = v ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.zero,
        title: const Text('จำข้อมูลเข้าใช้'),
        subtitle: compact
            ? null
            : const Text(
                kIsWeb
                    ? 'จำรหัสบริษัทและพนักงาน · ใช้ตัวจัดการรหัสผ่านของเบราว์เซอร์'
                    : 'เก็บรหัสผ่านในพื้นที่ปลอดภัยของเครื่อง',
                style: TextStyle(color: muted, fontSize: 12),
              ),
      ),
      if (widget.controller.error.isNotEmpty) ...[
        Notice(widget.controller.error, warning: true),
        SizedBox(height: compact ? 4 : 20),
      ],
      SizedBox(height: cinematicEnabled ? 4 : 10),
      PrimaryButton(
        'เข้าสู่ระบบ',
        onPressed: login,
        busy: widget.controller.busy,
      ),
      SizedBox(height: cinematicEnabled || compact ? 4 : 20),
      TextButton(
        onPressed: widget.controller.busy ? null : widget.controller.startDemo,
        child: const Text(
          'ทดลองใช้งานก่อนเข้าสู่ระบบ',
          style: TextStyle(color: muted),
        ),
      ),
      if (!cinematicEnabled && !compact) ...[
        const SizedBox(height: 24),
        const Text(
          'NWL  /  TIME, SIMPLIFIED.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10, letterSpacing: 1.8, color: muted),
        ),
      ],
    ];
    return Scaffold(
      body: SafeArea(
        child: cinematicEnabled
            ? CinematicLoginLayout(engaged: engaged, children: children)
            : LoginBody(children: children),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.controller});
  final AppController controller;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  int _lastReminderFocus = 0;
  bool _webPermissionChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (kIsWeb) {
      widget.controller.addListener(_checkWebPermissionSetup);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _checkWebPermissionSetup(),
      );
    }
  }

  void _checkWebPermissionSetup() {
    final c = widget.controller;
    if (!kIsWeb ||
        _webPermissionChecked ||
        !mounted ||
        c.demo ||
        c.session == null ||
        c.busy ||
        c.loginStage != LoginStage.idle) {
      return;
    }
    _webPermissionChecked = true;
    final session = c.session;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || c.session != session) return;
      try {
        final prefs = await SharedPreferences.getInstance();
        if (prefs.getBool('web_permission_setup_v1') == true ||
            !mounted ||
            c.session != session) {
          return;
        }
      } catch (_) {
        // Storage restrictions must not block the logged-in experience.
      }
      await _openWebPermissionSetup();
    });
  }

  Future<void> _openWebPermissionSetup() async {
    if (!mounted || !kIsWeb || widget.controller.session == null) return;
    final completed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const WebPermissionSetupDialog(),
    );
    if (completed == true) {
      try {
        await (await SharedPreferences.getInstance()).setBool(
          'web_permission_setup_v1',
          true,
        );
      } catch (_) {
        // Browser privacy settings may prevent local preferences.
      }
    }
  }

  @override
  void dispose() {
    if (kIsWeb) widget.controller.removeListener(_checkWebPermissionSetup);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.controller.resumeRefresh();
  }

  int tab = 0;
  bool _openingScan = false;
  Future<void> scan(Punch punch) async {
    final c = widget.controller;
    if (_openingScan || !c.canScanPunch(punch)) return;
    if (HonoApi.dateKey(c.date) != HonoApi.dateKey(bangkokNow())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ลงเวลาได้เฉพาะวันนี้ กรุณาเลือกวันที่ปัจจุบัน'),
        ),
      );
      return;
    }
    _openingScan = true;
    try {
      await c.refresh(includeProcessed: false);
      if (!mounted || !c.canScanPunch(punch)) {
        return;
      }
      final now = bangkokNow();
      if (punch == Punch.checkOut && earlyCheckoutMinutes(now) > 0) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => EarlyCheckoutDialog(now: now),
        );
        if (!mounted || confirmed != true || !c.canScanPunch(punch)) return;
      }
      final place = c.place;
      if (place == null) return;
      final submitted = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => ScanPage(controller: c, punch: punch, place: place),
        ),
      );
      if (!mounted) return;
      setState(() => tab = c.uncertain ? 2 : 0);
      if (cinematicEnabled && submitted == true && !c.demo && !c.uncertain) {
        final flag = punch == Punch.checkIn ? 'I' : 'O';
        final rows = c.logs.where((entry) => entry.flag == flag);
        final rawTime = rows.isEmpty
            ? (punch == Punch.checkIn ? c.state?.inTime : c.state?.outTime)
            : rows.last.time;
        final clock = rawTime == null ? null : historyClock(rawTime, c.date);
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => AttendanceCelebration(
            label: c.receipt,
            time: clock == '—' ? null : clock,
          ),
        );
      }
    } finally {
      _openingScan = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    if (c.reminderFocus != _lastReminderFocus) {
      _lastReminderFocus = c.reminderFocus;
      tab = 0;
    }
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: MediaQuery.sizeOf(context).height < 740 ? 56 : 78,
        title: const Brand(),
        actions: [
          if (kIsWeb)
            IconButton(
              tooltip: 'สิทธิ์กล้องและการใช้งานเว็บ',
              onPressed: c.busy ? null : _openWebPermissionSetup,
              icon: const NwlIcon(Icons.shield_outlined, size: 21),
            ),
          if (kIsWeb && !c.demo)
            if (c.session case final account? when account.payrollEnabled)
              IconButton(
                tooltip: 'สลิปเงินเดือน',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => PayslipPage(
                      company: account.company,
                      employee: account.employee,
                    ),
                  ),
                ),
                icon: const NwlIcon(Icons.receipt_long_outlined, size: 21),
              ),
          IconButton(
            tooltip: 'เตือนลงเวลาและวันทำงาน',
            onPressed: c.busy
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => ReminderPreferencesPage(controller: c),
                    ),
                  ),
            icon: const NwlIcon(Icons.notifications_active_outlined, size: 21),
          ),
          IconButton(
            tooltip: 'ออกจากระบบ',
            onPressed: c.busy ? null : c.logout,
            icon: const NwlIcon(Icons.logout_rounded, size: 21),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final content = tab == 1
              ? PlacesPage(controller: c)
              : tab == 2
              ? HistoryPage(controller: c)
              : TodayPage(
                  controller: c,
                  onPlace: () => setState(() => tab = 1),
                  onScan: scan,
                );
          if (constraints.maxWidth < 840) return content;
          return Row(
            children: [
              NavigationRail(
                extended: constraints.maxWidth >= 1200,
                minExtendedWidth: 230,
                backgroundColor: panel,
                selectedIndex: tab,
                onDestinationSelected: (i) {
                  setState(() => tab = i);
                  if (i == 0) c.changeDate(bangkokNow());
                },
                destinations: const [
                  NavigationRailDestination(
                    icon: NwlIcon(Icons.grid_view_outlined),
                    selectedIcon: NwlIcon(Icons.grid_view_rounded),
                    label: Text('วันนี้ของคุณ'),
                  ),
                  NavigationRailDestination(
                    icon: NwlIcon(Icons.location_on_outlined),
                    selectedIcon: NwlIcon(Icons.location_on),
                    label: Text('สถานที่'),
                  ),
                  NavigationRailDestination(
                    icon: NwlIcon(
                      Icons.history_rounded,
                      key: ValueKey('nav-history'),
                    ),
                    label: Text('ประวัติลงเวลา'),
                  ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: content),
            ],
          );
        },
      ),
      bottomNavigationBar: MediaQuery.sizeOf(context).width >= 840
          ? null
          : NavigationBar(
              height: MediaQuery.sizeOf(context).height < 740 ? 64 : 80,
              selectedIndex: tab,
              onDestinationSelected: (i) {
                setState(() => tab = i);
                if (i == 0) c.changeDate(bangkokNow());
              },
              destinations: const [
                NavigationDestination(
                  icon: NwlIcon(Icons.grid_view_outlined),
                  selectedIcon: NwlIcon(Icons.grid_view_rounded),
                  label: 'วันนี้',
                ),
                NavigationDestination(
                  icon: NwlIcon(Icons.location_on_outlined),
                  selectedIcon: NwlIcon(Icons.location_on),
                  label: 'สถานที่',
                ),
                NavigationDestination(
                  icon: NwlIcon(
                    Icons.history_rounded,
                    key: ValueKey('nav-history'),
                  ),
                  label: 'ประวัติ',
                ),
              ],
            ),
    );
  }
}

class TodayPage extends StatelessWidget {
  const TodayPage({
    super.key,
    required this.controller,
    required this.onPlace,
    required this.onScan,
  });
  final AppController controller;
  final VoidCallback onPlace;
  final void Function(Punch) onScan;
  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.sizeOf(context).width < 600 &&
        MediaQuery.sizeOf(context).height < 740;
    final c = controller;
    String time(String flag, String fallback) {
      final rows = c.logs.where((r) => r.flag == flag).toList();
      final raw = rows.isEmpty ? fallback : rows.last.time;
      final clock = punchClock(raw, c.date);
      return clock == null
          ? '--:--'
          : '${clock.hour.toString().padLeft(2, '0')}:${clock.minute.toString().padLeft(2, '0')}';
    }

    if (cinematicEnabled) {
      return RefreshIndicator(
        onRefresh: c.refresh,
        child: cinematicToday(context, c, time),
      );
    }
    return RefreshIndicator(
      onRefresh: c.refresh,
      child: PageBody(
        maxWidth: 960,
        children: [
          if (!compact)
            Text(
              c.demo ? 'โหมดทดลอง' : 'สวัสดี',
              style: const TextStyle(color: muted),
            ),
          SizedBox(height: compact ? 0 : 4),
          Text(
            c.name,
            style: compact
                ? Theme.of(context).textTheme.titleMedium
                : Theme.of(context).textTheme.titleLarge,
          ),
          SizedBox(height: compact ? 0 : 5),
          if (!c.demo && !compact)
            Text(
              '${c.company.toUpperCase()}  ·  ${c.session?.employee ?? ''}',
              style: const TextStyle(color: muted, fontSize: 12),
            ),
          SizedBox(height: compact ? 8 : 28),
          MotionReveal(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        compact ? thaiDate(c.date) : 'วันนี้ของคุณ',
                        style: compact
                            ? Theme.of(context).textTheme.bodyMedium
                            : Theme.of(context).textTheme.headlineLarge,
                      ),
                      if (!compact) const SizedBox(height: 6),
                      if (!compact)
                        Text(
                          thaiDate(c.date),
                          style: const TextStyle(color: muted),
                        ),
                    ],
                  ),
                ),
                if (!compact) const TimeArtwork(size: 64),
              ],
            ),
          ),
          SizedBox(height: compact ? 8 : 24),
          attendanceCard(c, time, compact: compact),
          ...attendanceDetails(c, gap: compact ? 8 : 16),
          const SizedBox(height: 8),
          Text(
            c.demo
                ? 'โหมดทดลอง · ไม่ส่งรายการจริง'
                : 'ใบหน้าตรงกันแล้ว ส่งเวลาอัตโนมัติ',
            textAlign: TextAlign.center,
            style: const TextStyle(color: muted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget cinematicToday(
    BuildContext context,
    AppController c,
    String Function(String, String) time,
  ) => LayoutBuilder(
    builder: (context, viewport) {
      final wide = viewport.maxWidth >= 850;
      final compact = viewport.maxWidth < 600;
      final gap = compact ? 8.0 : 16.0;
      final ready = c.canScan;
      final status = Row(
        children: [
          Icon(Icons.circle, size: 8, color: ready ? electricLime : lavender),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              c.demo
                  ? 'โหมดทดลอง · ไม่ส่งรายการจริง'
                  : c.loading
                  ? 'กำลังโหลดสถานะลงเวลา'
                  : ready
                  ? 'พร้อมบันทึกเวลาทำงาน'
                  : 'ตรวจสถานะลงเวลาของคุณ',
              style: const TextStyle(color: muted, fontSize: 12),
            ),
          ),
        ],
      );
      return PageBody(
        maxWidth: 960,
        children: [
          Row(
            children: [
              if (wide) ...[
                const SizedBox(
                  width: 70,
                  height: 70,
                  child: MascotArt('login'),
                ),
                const SizedBox(width: 15),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (viewport.maxHeight >= 640 || wide)
                      const Text('สวัสดี', style: TextStyle(color: muted)),
                    Text(
                      c.name,
                      style: wide
                          ? Theme.of(context).textTheme.headlineMedium
                          : Theme.of(context).textTheme.titleLarge,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (!c.demo && wide)
                      Text(
                        '${c.company.toUpperCase()} · ${c.session?.employee ?? ''}',
                        style: const TextStyle(color: muted, fontSize: 12),
                      ),
                  ],
                ),
              ),
              if (!wide)
                const SizedBox(
                  width: 66,
                  height: 60,
                  child: MascotArt('dashboard'),
                ),
            ],
          ),
          SizedBox(height: gap),
          if (wide)
            DashboardBanner(
              title: 'วันนี้ของคุณ',
              subtitle: thaiDate(c.date),
              clock: const TodayClock(compact: false),
            )
          else ...[
            Text(thaiDate(c.date), style: const TextStyle(color: muted)),
            const TodayClock(compact: true),
          ],
          SizedBox(height: gap),
          status,
          SizedBox(height: gap),
          attendanceCard(c, time, compact: compact),
          ...attendanceDetails(c, gap: gap),
        ],
      );
    },
  );

  Widget attendanceCard(
    AppController c,
    String Function(String, String) time, {
    required bool compact,
  }) {
    final gutter = compact ? 8.0 : 16.0;
    final canCheckIn = c.canScanPunch(Punch.checkIn);
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 20),
      decoration: BoxDecoration(
        color: panel,
        border: Border.all(color: cinematicLine),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'สรุปเวลาของวันนี้',
            style: TextStyle(color: muted, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: gutter),
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: TimeColumn(
                    Punch.checkIn,
                    time('I', c.state?.inTime ?? ''),
                  ),
                ),
                VerticalDivider(width: gutter, thickness: 1),
                Expanded(
                  child: TimeColumn(
                    Punch.checkOut,
                    time('O', c.state?.outTime ?? ''),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: gutter),
          if (c.uncertain)
            PrimaryButton(
              'ตรวจประวัติก่อนเริ่มใหม่',
              onPressed: !c.loading && c.error.isEmpty && c.state != null
                  ? c.acknowledgeUnknown
                  : null,
              icon: Icons.history_rounded,
            )
          else if (c.place == null)
            PrimaryButton(
              'เลือกสถานที่',
              onPressed: onPlace,
              icon: Icons.add_location_alt_outlined,
            )
          else
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: attendanceButton(
                      Punch.checkIn,
                      enabled: canCheckIn,
                      primary: true,
                      recorded: c.checkedIn,
                    ),
                  ),
                  SizedBox(width: gutter),
                  Expanded(
                    child: attendanceButton(
                      Punch.checkOut,
                      enabled: c.canScanPunch(Punch.checkOut),
                      primary: !canCheckIn,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> attendanceDetails(AppController c, {required double gap}) => [
    if (c.place case final place?) ...[
      SizedBox(height: gap),
      Material(
        color: panel,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: onPlace,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          leading: const NwlIcon(Icons.location_on_outlined, color: mint),
          title: const Text(
            'สถานที่ที่เลือก',
            style: TextStyle(color: muted, fontSize: 12),
          ),
          subtitle: Text.rich(
            TextSpan(
              text: place.displayName,
              style: const TextStyle(color: paper, fontWeight: FontWeight.w600),
              children: [
                if (place.address case final address?)
                  TextSpan(
                    text: '\n$address',
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
              ],
            ),
          ),
          trailing: const NwlIcon(Icons.chevron_right_rounded),
        ),
      ),
    ],
    if (c.loading) ...[SizedBox(height: gap), const LinearProgressIndicator()],
    if (c.stateError.isNotEmpty) ...[
      SizedBox(height: gap),
      Notice(c.stateError, warning: true),
    ],
    if (c.error.isNotEmpty) ...[
      SizedBox(height: gap),
      Notice(c.error, warning: true),
      TextButton(onPressed: c.refresh, child: const Text('โหลดสถานะใหม่')),
    ],
    if (c.receipt.isNotEmpty) ...[
      SizedBox(height: gap),
      Notice(c.receipt, warning: c.uncertain),
    ],
    if (!c.demo && !c.loading && c.state != null && !c.state!.face) ...[
      SizedBox(height: gap),
      const Notice(
        'บริษัทไม่เปิดวิธียืนยันใบหน้าที่รองรับ กรุณาใช้ HONO เดิม',
        warning: true,
      ),
    ],
  ];

  Widget attendanceButton(
    Punch punch, {
    required bool enabled,
    required bool primary,
    bool recorded = false,
  }) {
    final foreground = enabled && primary
        ? ink
        : enabled
        ? paper
        : muted;
    return FilledButton.icon(
      style:
          FilledButton.styleFrom(
            foregroundColor: foreground,
            backgroundColor: primary ? mint : const Color(0xFF263651),
            disabledForegroundColor: muted,
            disabledBackgroundColor: recorded
                ? const Color(0xFF293D3E)
                : const Color(0xFF202C44),
            minimumSize: const Size(0, 48),
            visualDensity: VisualDensity.standard,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ).copyWith(
            side: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.focused)
                  ? BorderSide(color: primary ? ink : mint, width: 2)
                  : BorderSide.none,
            ),
          ),
      onPressed: enabled ? () => onScan(punch) : null,
      icon: NwlIcon(
        recorded
            ? Icons.check_circle_outline_rounded
            : punch == Punch.checkIn
            ? Icons.login_rounded
            : Icons.logout_rounded,
        color: recorded ? mint : foreground,
        size: 18,
      ),
      label: Text(
        recorded ? 'เข้างานแล้ว' : 'สแกน${punch.label}',
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class TimeColumn extends StatelessWidget {
  const TimeColumn(this.punch, this.time, {super.key});
  final Punch punch;
  final String time;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          NwlIcon(
            punch == Punch.checkIn ? Icons.login_rounded : Icons.logout_rounded,
            size: 16,
            color: punch == Punch.checkIn ? mint : lavender,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              punch.label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: muted, fontSize: 13),
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      Text(
        time,
        textAlign: TextAlign.center,
        semanticsLabel: time == '--:--' ? 'ยังไม่มีเวลา${punch.label}' : null,
        style: TextStyle(
          fontFamily: 'NotoSans',
          fontSize: 28,
          height: 1.2,
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
          letterSpacing: 0,
        ),
      ),
    ],
  );
}

class PlacesPage extends StatefulWidget {
  const PlacesPage({super.key, required this.controller});
  final AppController controller;
  @override
  State<PlacesPage> createState() => _PlacesPageState();
}

class _PlacesPageState extends State<PlacesPage> {
  AppController get controller => widget.controller;
  @override
  void initState() {
    super.initState();
    controller.loadPlaceAddresses();
    controller.loadPlaceSubdistricts();
  }

  @override
  Widget build(BuildContext context) => PageBody(
    children: [
      if (cinematicEnabled)
        CinematicSurface(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'สถานที่ของคุณ',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              const SizedBox(
                width: 120,
                height: 100,
                child: MascotArt('location'),
              ),
            ],
          ),
        )
      else
        Text(
          'สถานที่ของคุณ',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      if (controller.session != null && !controller.demo) ...[
        const SizedBox(height: 12),
        _HonoWorkLocations(controller: controller),
        const SizedBox(height: 20),
      ],
      const SizedBox(height: 8),
      Text('หมุดของฉัน', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 12),
      for (var i = 0; i < controller.places.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: panel,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              contentPadding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
              leading: NwlIcon(
                !controller.hasSelectedHonoPlace && controller.selected == i
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: mint,
              ),
              title: Text(controller.places[i].displayName),
              subtitle: Text(
                controller.places[i].address ??
                    controller.addressFor(
                      controller.places[i].lat,
                      controller.places[i].lng,
                    ) ??
                    controller.places[i].coordinates,
                style: const TextStyle(color: muted, fontSize: 12),
              ),
              onTap: controller.savingHonoPlaces
                  ? null
                  : () async {
                      try {
                        await controller.selectPlace(i);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(friendly(e))));
                        }
                      }
                    },
              trailing: controller.places[i].isDefaultOffice
                  ? const Padding(
                      padding: EdgeInsets.only(right: 10),
                      child: Text(
                        'ค่าเริ่มต้น',
                        style: TextStyle(color: muted),
                      ),
                    )
                  : IconButton(
                      tooltip: 'ลบสถานที่',
                      icon: const NwlIcon(Icons.delete_outline_rounded),
                      onPressed: () async {
                        final yes = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('ลบสถานที่นี้?'),
                            content: Text(controller.places[i].displayName),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('ยกเลิก'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('ลบ'),
                              ),
                            ],
                          ),
                        );
                        if (yes == true) {
                          try {
                            await controller.deletePlace(i);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(friendly(e))),
                              );
                            }
                          }
                        }
                      },
                    ),
            ),
          ),
        ),
      if (controller.places.isEmpty) ...[
        const SizedBox(height: 26),
        const NwlIcon(Icons.add_location_alt_outlined, size: 48, color: muted),
        const SizedBox(height: 16),
        const Text('ยังไม่มีสถานที่ที่บันทึก', textAlign: TextAlign.center),
        const SizedBox(height: 34),
      ],
      PrimaryButton(
        'เพิ่มสถานที่',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => AddPlacePage(controller: controller),
          ),
        ),
        icon: Icons.add_rounded,
      ),
      const SizedBox(height: 12),
      const Text(
        'ข้อมูลเขตและอำเภอ: GeoThai, OCHA COD-AB และกรมแผนที่ทหาร',
        style: TextStyle(color: muted, fontSize: 11),
      ),
    ],
  );
}

class _HonoWorkLocations extends StatefulWidget {
  const _HonoWorkLocations({required this.controller});

  final AppController controller;

  @override
  State<_HonoWorkLocations> createState() => _HonoWorkLocationsState();
}

class _HonoWorkLocationsState extends State<_HonoWorkLocations> {
  static const pageSize = 20;
  AppController get controller => widget.controller;
  String query = '';
  int visibleCount = pageSize;

  bool _matches(Place place) =>
      query.isEmpty ||
      place.displayName.toLowerCase().contains(query) ||
      place.coordinates.contains(query) ||
      (place.address?.toLowerCase().contains(query) ?? false);

  String _areaDetails(Place place, String note) {
    final address = place.address;
    final namePrefix = '${place.displayName} ';
    return [
      if (address != null)
        address.startsWith(namePrefix)
            ? address.substring(namePrefix.length)
            : address,
      if (place.displayName.contains(place.coordinates))
        note
      else
        '${place.coordinates} · $note',
    ].join('\n');
  }

  void _openMap(Place place) {
    openExternal(
      Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': '${place.lat},${place.lng}',
      }),
    );
  }

  Future<void> _namePlace(Place place) async {
    var label = place.displayName;
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ตั้งชื่อสถานที่'),
        content: TextFormField(
          initialValue: label,
          autofocus: true,
          maxLength: 100,
          decoration: const InputDecoration(labelText: 'ชื่ออาคารหรือสาขา'),
          onChanged: (value) => label = value,
          onFieldSubmitted: (value) {
            if (value.trim().isNotEmpty) Navigator.pop(dialogContext, value);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () {
              if (label.trim().isNotEmpty) Navigator.pop(dialogContext, label);
            },
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
    if (name != null && mounted) {
      await _save(context, () => controller.nameHonoPlace(place, name));
    }
  }

  Widget _areaMenu(Place place, {required bool available, Place? saved}) =>
      PopupMenuButton<String>(
        tooltip: 'ตัวเลือกสถานที่',
        onSelected: (action) {
          switch (action) {
            case 'map':
              _openMap(place);
            case 'name':
              _namePlace(place);
            case 'remove':
              _save(context, () => controller.removeSavedHonoPlace(saved!));
          }
        },
        itemBuilder: (_) => [
          if (kIsWeb)
            const PopupMenuItem(
              value: 'map',
              child: Text('เปิดใน Google Maps'),
            ),
          if (available)
            const PopupMenuItem(value: 'name', child: Text('ตั้งชื่อสถานที่')),
          if (saved != null)
            PopupMenuItem(
              value: 'remove',
              enabled: !controller.savingHonoPlaces,
              child: const Text('นำออกจากพื้นที่ที่บันทึก'),
            ),
        ],
      );

  Future<void> _save(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendly(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final live = controller.workLocations;
    final locations = live ?? controller.cachedWorkLocations;
    final selected = controller.place;
    final selectedIndex = selected?.fromHono == true
        ? controller.honoOptionIndex(selected!)
        : -1;
    final status = live == null
        ? controller.loading
              ? 'กำลังโหลดพื้นที่ลงเวลาจาก HONO…'
              : 'ยังอ่านข้อมูลพื้นที่ลงเวลาของบัญชีนี้ไม่ได้'
        : 'HONO ไม่ได้ระบุพื้นที่ลงเวลาสำหรับบัญชีนี้';
    final choices = locations?.indexed.where((option) {
      final (_, area) = option;
      return !controller.isHonoPlaceSaved(area) &&
          (query.isEmpty || _matches(controller.honoPlaceFor(area)));
    }).toList();
    final saved = controller.savedHonoPlaces
        .where(
          (pin) => query.isEmpty || _matches(controller.describeHonoPlace(pin)),
        )
        .toList();
    final showSearch =
        (locations?.isNotEmpty ?? false) ||
        controller.savedHonoPlaces.isNotEmpty ||
        query.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'พื้นที่ลงเวลาจาก HONO',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          const Text(
            'รายการพื้นที่ของบัญชีนี้บันทึกในเบราว์เซอร์โดยอัตโนมัติ',
            style: TextStyle(color: muted),
          ),
          if (showSearch) ...[
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                labelText: 'ค้นหาสถานที่',
                hintText: 'ชื่อ ตำบล อำเภอ จังหวัด หรือพิกัด',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() {
                query = value.trim().toLowerCase();
                visibleCount = pageSize;
              }),
            ),
            const SizedBox(height: 8),
            Text(
              query.isEmpty
                  ? '${locations?.length ?? 0} รายการจาก HONO'
                  : 'พบ ${(choices?.length ?? 0) + saved.length} รายการ',
              style: const TextStyle(color: muted),
            ),
          ],
          if (live == null && locations != null)
            const Notice(
              'รายการที่บันทึกไว้ · ต้องโหลดข้อมูลล่าสุดจาก HONO ก่อนเลือกลงเวลา',
              warning: true,
            ),
          if (controller.hasSelectedHonoPlace &&
              live != null &&
              selected == null)
            const Notice(
              'พื้นที่ที่เลือกไม่อยู่ในรายการล่าสุด กรุณาเลือกสถานที่ใหม่',
              warning: true,
            ),
          if (saved.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'พื้นที่ HONO ที่บันทึกไว้',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (final place in saved.take(visibleCount))
              _savedTile(context, place, selectedIndex),
          ],
          if (choices == null || locations!.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(status, style: const TextStyle(color: muted)),
            )
          else if (choices.isEmpty && live != null && query.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'บันทึกครบทุกพื้นที่แล้ว',
                style: TextStyle(color: muted),
              ),
            )
          else
            for (final (index, area) in choices.take(visibleCount))
              _locationTile(context, index, area, selectedIndex, live != null),
          if ((choices?.length ?? 0) > visibleCount ||
              saved.length > visibleCount)
            TextButton(
              onPressed: () => setState(() => visibleCount += pageSize),
              child: const Text('แสดงพื้นที่เพิ่มเติม'),
            ),
        ],
      ),
    );
  }

  Widget _savedTile(BuildContext context, Place saved, int selectedIndex) {
    final index = controller.honoOptionIndex(saved);
    final area = index < 0 ? null : controller.workLocations![index];
    final place = controller.describeHonoPlace(saved);
    final note = area == null
        ? controller.workLocations == null
              ? 'รอตรวจข้อมูลจาก HONO'
              : 'ไม่อยู่ในรายการล่าสุดของ HONO'
        : 'รัศมี ${area.radiusMeters} เมตร';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      selected: index >= 0 && index == selectedIndex,
      leading: NwlIcon(
        index < 0
            ? Icons.location_off_outlined
            : index == selectedIndex
            ? Icons.radio_button_checked
            : Icons.radio_button_off,
        color: index < 0 ? muted : mint,
      ),
      title: Text(place.displayName),
      subtitle: Text(_areaDetails(place, note)),
      onTap: index < 0 || controller.savingHonoPlaces
          ? null
          : () => _save(context, () => controller.selectHonoPlace(index)),
      trailing: _areaMenu(
        place,
        available: index >= 0 && !controller.savingHonoPlaces,
        saved: saved,
      ),
    );
  }

  Widget _locationTile(
    BuildContext context,
    int index,
    WorkLocation area,
    int selectedIndex,
    bool available,
  ) {
    final place = controller.honoPlaceFor(area);
    final choose = !available || controller.savingHonoPlaces
        ? null
        : () => _save(context, () => controller.selectHonoPlace(index));
    return ListTile(
      contentPadding: EdgeInsets.zero,
      selected: index == selectedIndex,
      leading: NwlIcon(
        index == selectedIndex
            ? Icons.radio_button_checked
            : Icons.radio_button_off,
        color: available ? mint : muted,
      ),
      title: Text(place.displayName),
      subtitle: Text(_areaDetails(place, 'รัศมี ${area.radiusMeters} เมตร')),
      onTap: choose,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (available)
            TextButton(onPressed: choose, child: const Text('เลือกและบันทึก')),
          if (kIsWeb || choose != null)
            _areaMenu(place, available: choose != null),
        ],
      ),
    );
  }
}

class AddPlacePage extends StatefulWidget {
  const AddPlacePage({super.key, required this.controller});
  final AppController controller;
  @override
  State<AddPlacePage> createState() => _AddPlacePageState();
}

class _AddPlacePageState extends State<AddPlacePage> {
  final name = TextEditingController(), link = TextEditingController();
  MapPin? pin;
  String? address;
  String? suggestedName;
  String error = '';
  bool busy = false, confirmed = false;
  @override
  void dispose() {
    name.dispose();
    link.dispose();
    super.dispose();
  }

  Future<void> resolve() async {
    setState(() {
      busy = true;
      error = '';
      pin = null;
      address = null;
      confirmed = false;
    });
    try {
      final p = await Maps().resolve(link.text);
      if (widget.controller.addressFor(p.lat, p.lng) == null) {
        await widget.controller.loadPlaceAddresses();
      }
      if (mounted) {
        setState(() {
          pin = p;
          address = widget.controller.addressFor(p.lat, p.lng);
          if (name.text.trim().isEmpty) {
            suggestedName =
                p.name ??
                (p.lat == Place.thaiCcTower.lat &&
                        p.lng == Place.thaiCcTower.lng
                    ? Place.thaiCcTower.displayName
                    : null);
            name.text = suggestedName ?? '';
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = friendly(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    if (pin == null || (pin!.viewport && !confirmed)) {
      return;
    }
    setState(() => busy = true);
    try {
      await widget.controller.savePlace(
        Place(
          name.text.trim().isEmpty ? 'หมุดที่บันทึก' : name.text.trim(),
          pin!.lat,
          pin!.lng,
          link.text.trim(),
          address: address,
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = friendly(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 740;
    return Scaffold(
      appBar: AppBar(title: const Text('เพิ่มสถานที่')),
      body: SafeArea(
        child: PageBody(
          children: [
            Text(
              'หมุดที่ใช่สำหรับคุณ',
              style: compact
                  ? Theme.of(context).textTheme.titleLarge
                  : Theme.of(context).textTheme.headlineMedium,
            ),
            SizedBox(height: compact ? 8 : 12),
            const Text(
              'วางลิงก์ที่แชร์จาก Google Maps หรือละติจูด, ลองจิจูด',
              style: TextStyle(color: muted),
            ),
            SizedBox(height: compact ? 8 : 28),
            TextField(
              controller: name,
              enabled: !busy,
              decoration: const InputDecoration(
                labelText: 'ชื่อสถานที่ (ไม่บังคับ)',
              ),
            ),
            SizedBox(height: compact ? 8 : 20),
            TextField(
              controller: link,
              enabled: !busy,
              maxLines: compact ? 1 : 3,
              onChanged: (_) => setState(() {
                if (name.text == suggestedName) name.clear();
                suggestedName = null;
                pin = null;
                address = null;
                confirmed = false;
              }),
              decoration: const InputDecoration(
                labelText: 'ลิงก์ Google Maps หรือพิกัด',
              ),
            ),
            SizedBox(height: compact ? 8 : 20),
            OutlinedButton.icon(
              onPressed: busy ? null : resolve,
              icon: const NwlIcon(Icons.link_rounded),
              label: Text(busy ? 'กำลังอ่านหมุด…' : 'อ่านพิกัดจากลิงก์'),
            ),
            if (error.isNotEmpty) ...[
              SizedBox(height: compact ? 8 : 20),
              Notice(error, warning: true),
            ],
            if (pin != null) ...[
              SizedBox(height: compact ? 8 : 24),
              if (address case final label?)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(label, textAlign: TextAlign.center),
                ),
              if (compact)
                Text(
                  'พิกัด: ${pin!.lat.toStringAsFixed(6)}, ${pin!.lng.toStringAsFixed(6)}',
                )
              else
                Notice(
                  '${pin!.lat.toStringAsFixed(6)}, ${pin!.lng.toStringAsFixed(6)}',
                ),
              if (pin!.viewport)
                CheckboxListTile(
                  dense: compact,
                  contentPadding: EdgeInsets.zero,
                  value: confirmed,
                  onChanged: (v) => setState(() => confirmed = v ?? false),
                  title: Text(
                    compact
                        ? 'ยืนยันจุดกลางแผนที่ (อาจไม่ใช่หมุด)'
                        : 'ยืนยันใช้จุดกลางแผนที่นี้',
                  ),
                  subtitle: compact
                      ? null
                      : const Text(
                          'ลิงก์นี้เป็นจุดกลางหน้าจอ อาจไม่ใช่หมุดสถานที่',
                        ),
                ),
            ],
            SizedBox(height: compact ? 8 : 28),
            PrimaryButton(
              'บันทึกสถานที่',
              busy: busy,
              onPressed: pin != null && (!pin!.viewport || confirmed)
                  ? save
                  : null,
              icon: Icons.check_rounded,
            ),
          ],
        ),
      ),
    );
  }
}

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key, required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    final history = HistoryInsightsPage(controller: controller);
    if (!cinematicEnabled || MediaQuery.sizeOf(context).width < 1200) {
      return history;
    }
    return Stack(
      children: [
        Positioned.fill(child: history),
        const Positioned(
          bottom: 12,
          right: 10,
          width: 110,
          height: 110,
          child: IgnorePointer(child: MascotArt('cat')),
        ),
      ],
    );
  }
}

String thaiDate(DateTime date) {
  const months = [
    'ม.ค.',
    'ก.พ.',
    'มี.ค.',
    'เม.ย.',
    'พ.ค.',
    'มิ.ย.',
    'ก.ค.',
    'ส.ค.',
    'ก.ย.',
    'ต.ค.',
    'พ.ย.',
    'ธ.ค.',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year + 543}';
}
