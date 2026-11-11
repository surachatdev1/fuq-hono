import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../core/controller.dart';
import '../core/models.dart';
import '../data/hono.dart';
import '../data/maps.dart';
import '../features/attendance_insights.dart';
import '../features/web_permission_access.dart';
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
    if (_openingScan || !c.canScan) return;
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
      await c.refresh();
      if (!mounted ||
          !c.canScan ||
          !(c.state?.allows(punch, c.logs) ?? c.demo)) {
        return;
      }
      final now = bangkokNow();
      if (punch == Punch.checkOut && earlyCheckoutMinutes(now) > 0) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => EarlyCheckoutDialog(now: now),
        );
        if (!mounted || confirmed != true || !c.canScan) return;
      }
      final submitted = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) =>
              ScanPage(controller: c, punch: punch, place: c.place!),
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

class TodayPage extends StatefulWidget {
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
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  Punch selectedPunch = Punch.checkIn;
  AppController get controller => widget.controller;
  VoidCallback get onPlace => widget.onPlace;
  void Function(Punch) get onScan => widget.onScan;
  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.sizeOf(context).width < 600 &&
        MediaQuery.sizeOf(context).height < 740;
    final c = controller;
    final actions = c.actions;
    String time(String flag, String fallback) {
      final rows = c.logs.where((r) => r.flag == flag).toList();
      final raw = rows.isEmpty ? fallback : rows.last.time;
      final clock = punchClock(raw, c.date);
      return clock == null
          ? '—:—'
          : '${clock.hour.toString().padLeft(2, '0')}:${clock.minute.toString().padLeft(2, '0')}';
    }

    if (cinematicEnabled) {
      return RefreshIndicator(
        onRefresh: c.refresh,
        child: cinematicToday(context, c, actions, time),
      );
    }
    return RefreshIndicator(
      onRefresh: c.refresh,
      child: DayBody(
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
          Container(
            padding: EdgeInsets.all(compact ? 12 : 24),
            decoration: BoxDecoration(
              color: panel,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2B3B59)),
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: TimeColumn(
                      'เข้างาน',
                      time('I', c.state?.inTime ?? ''),
                    ),
                  ),
                  const VerticalDivider(width: 32, color: Color(0xFF2B3B59)),
                  Expanded(
                    child: TimeColumn(
                      'ออกงาน',
                      time('O', c.state?.outTime ?? ''),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: compact ? 4 : 10),
          if (!compact) const Divider(),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onPlace,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: mint.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const NwlIcon(
                      Icons.location_on_outlined,
                      color: mint,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'สถานที่ที่เลือก',
                          style: TextStyle(fontSize: 12, color: muted),
                        ),
                        Text(
                          c.place?.name ?? 'เพิ่มสถานที่ของคุณ',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        if (!compact)
                          const Text(
                            'หมุดที่เลือก · Google Maps',
                            style: TextStyle(fontSize: 12, color: muted),
                          ),
                      ],
                    ),
                  ),
                  const Text('เปลี่ยน', style: TextStyle(color: mint)),
                ],
              ),
            ),
          ),
          if (!compact) const Divider(),
          if (!compact)
            const Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'เลือกสถานที่',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
                NwlIcon(Icons.chevron_right_rounded, size: 16, color: muted),
                Text(
                  'สแกนใบหน้า',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
                NwlIcon(Icons.chevron_right_rounded, size: 16, color: muted),
                Text('ลงเวลา', style: TextStyle(fontSize: 12, color: muted)),
              ],
            ),
          SizedBox(height: compact ? 8 : 24),
          if (c.loading) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 20),
          ],
          if (c.stateError.isNotEmpty) ...[
            Notice(c.stateError, warning: true),
            const SizedBox(height: 12),
          ],
          if (c.error.isNotEmpty) ...[
            Notice(c.error, warning: true),
            TextButton(
              onPressed: c.refresh,
              child: const Text('โหลดสถานะใหม่'),
            ),
          ],
          if (c.receipt.isNotEmpty) ...[
            Notice(c.receipt, warning: c.uncertain),
            SizedBox(height: compact ? 8 : 16),
          ],
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
          else if (actions.isNotEmpty) ...[
            if (actions.length > 1) ...[
              SegmentedButton<Punch>(
                showSelectedIcon: false,
                segments: actions
                    .map((p) => ButtonSegment(value: p, label: Text(p.label)))
                    .toList(),
                selected: {
                  actions.contains(selectedPunch)
                      ? selectedPunch
                      : actions.first,
                },
                onSelectionChanged: (choice) =>
                    setState(() => selectedPunch = choice.single),
              ),
              SizedBox(height: compact ? 8 : 16),
            ],
            PrimaryButton(
              'สแกน${(actions.contains(selectedPunch) ? selectedPunch : actions.first).label}',
              onPressed: c.canScan
                  ? () => onScan(
                      actions.contains(selectedPunch)
                          ? selectedPunch
                          : actions.first,
                    )
                  : null,
            ),
          ],
          if (!c.demo && !c.loading && c.state != null && !c.state!.face)
            const Notice(
              'บริษัทไม่เปิดวิธียืนยันใบหน้าที่รองรับ กรุณาใช้ HONO เดิม',
              warning: true,
            ),
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
    Set<Punch> actions,
    String Function(String, String) time,
  ) => LayoutBuilder(
    builder: (context, viewport) {
      final wide = viewport.maxWidth >= 850;
      final compact = viewport.maxHeight < 640;
      final current = actions.contains(selectedPunch)
          ? selectedPunch
          : actions.firstOrNull;
      final controls = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          else if (current != null) ...[
            if (actions.length > 1) ...[
              SegmentedButton<Punch>(
                showSelectedIcon: false,
                segments: [
                  for (final action in actions)
                    ButtonSegment(value: action, label: Text(action.label)),
                ],
                selected: {current},
                onSelectionChanged: (choice) =>
                    setState(() => selectedPunch = choice.single),
              ),
              const SizedBox(height: 8),
            ],
            PrimaryButton(
              'สแกน${current.label}',
              onPressed: c.canScan ? () => onScan(current) : null,
              icon: Icons.face_retouching_natural,
            ),
          ],
        ],
      );
      final summary = CinematicSurface(
        padding: EdgeInsets.all(compact ? 13 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('สรุปเวลาของวันนี้', style: TextStyle(color: muted)),
            const SizedBox(height: 6),
            IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: TimeColumn(
                      'เข้างาน',
                      time('I', c.state?.inTime ?? ''),
                    ),
                  ),
                  const VerticalDivider(width: 28),
                  Expanded(
                    child: TimeColumn(
                      'ออกงาน',
                      time('O', c.state?.outTime ?? ''),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
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
        maxWidth: 1060,
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
                    if (!compact || wide)
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
          SizedBox(height: wide ? 18 : 6),
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
          const SizedBox(height: 9),
          status,
          SizedBox(height: wide ? 18 : 9),
          if (wide)
            Row(
              children: [
                Expanded(flex: 3, child: summary),
                const SizedBox(width: 20),
                Expanded(flex: 2, child: controls),
              ],
            )
          else ...[
            summary,
            const SizedBox(height: 8),
            controls,
          ],
          SizedBox(height: wide ? 19 : 6),
          Material(
            color: panel,
            borderRadius: BorderRadius.circular(16),
            child: ListTile(
              onTap: onPlace,
              leading: const NwlIcon(Icons.location_on_outlined, color: mint),
              title: const Text(
                'สถานที่ที่เลือก',
                style: TextStyle(color: muted, fontSize: 12),
              ),
              subtitle: Text(
                c.place?.name ?? 'เพิ่มสถานที่ของคุณ',
                style: const TextStyle(
                  color: paper,
                  fontWeight: FontWeight.bold,
                ),
              ),
              trailing: const NwlIcon(Icons.chevron_right_rounded),
            ),
          ),
          if (c.loading) const LinearProgressIndicator(),
          if (c.stateError.isNotEmpty) Notice(c.stateError, warning: true),
          if (c.error.isNotEmpty) ...[
            Notice(c.error, warning: true),
            TextButton(
              onPressed: c.refresh,
              child: const Text('โหลดสถานะใหม่'),
            ),
          ],
          if (c.receipt.isNotEmpty) Notice(c.receipt, warning: c.uncertain),
          if (!c.demo && !c.loading && c.state != null && !c.state!.face)
            const Notice(
              'บริษัทไม่เปิดวิธียืนยันใบหน้าที่รองรับ กรุณาใช้ HONO เดิม',
              warning: true,
            ),
        ],
      );
    },
  );
}

class TimeColumn extends StatelessWidget {
  const TimeColumn(this.label, this.time, {super.key});
  final String label, time;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          NwlIcon(
            label == 'เข้างาน' ? Icons.login_rounded : Icons.logout_rounded,
            size: 16,
            color: label == 'เข้างาน' ? mint : lavender,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(color: muted, fontSize: 13),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Text(
        time,
        style: TextStyle(
          fontSize: time.length > 8 ? 17 : 29,
          height: 1.35,
          fontWeight: FontWeight.w500,
          letterSpacing: 0,
        ),
      ),
    ],
  );
}

class PlacesPage extends StatelessWidget {
  const PlacesPage({super.key, required this.controller});
  final AppController controller;
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
      const SizedBox(height: 8),
      const Text(
        'บันทึกหมุดจาก Google Maps เพื่อเลือกใช้ครั้งถัดไป',
        style: TextStyle(color: muted),
      ),
      const SizedBox(height: 24),
      for (var i = 0; i < controller.places.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: panel,
            borderRadius: BorderRadius.circular(12),
            child: ListTile(
              contentPadding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
              leading: NwlIcon(
                controller.selected == i
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: mint,
              ),
              title: Text(controller.places[i].name),
              subtitle: Text(
                '${controller.places[i].lat.toStringAsFixed(6)}, ${controller.places[i].lng.toStringAsFixed(6)}',
                style: const TextStyle(color: muted, fontSize: 12),
              ),
              onTap: () async {
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
                            content: Text(controller.places[i].name),
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
    ],
  );
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
  String error = '';
  bool busy = false, confirmed = false, devicePin = false;
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
      confirmed = false;
      devicePin = false;
    });
    try {
      final p = await Maps().resolve(link.text);
      if (mounted) setState(() => pin = p);
    } catch (e) {
      if (mounted) setState(() => error = friendly(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> locate() async {
    setState(() {
      busy = true;
      error = '';
      pin = null;
      confirmed = false;
      devicePin = false;
    });
    try {
      final coordinates = await requestDeviceCoordinates();
      final resolved = await Maps().resolve(coordinates);
      if (!mounted) return;
      setState(() {
        link.text = coordinates;
        pin = resolved;
        devicePin = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        error =
            'อ่านตำแหน่งไม่ได้ ตรวจสิทธิ์ของเบราว์เซอร์ หรือเลือกหมุดจาก Google Maps';
      });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    if (pin == null ||
        name.text.trim().isEmpty ||
        ((pin!.viewport || devicePin) && !confirmed)) {
      return;
    }
    setState(() => busy = true);
    try {
      await widget.controller.savePlace(
        Place(name.text.trim(), pin!.lat, pin!.lng, link.text.trim()),
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
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'ชื่อสถานที่'),
            ),
            SizedBox(height: compact ? 8 : 20),
            TextField(
              controller: link,
              enabled: !busy,
              maxLines: compact ? 1 : 3,
              onChanged: (_) => setState(() {
                pin = null;
                confirmed = false;
                devicePin = false;
              }),
              decoration: const InputDecoration(
                labelText: 'ลิงก์ Google Maps หรือพิกัด',
              ),
            ),
            SizedBox(height: compact ? 8 : 20),
            OutlinedButton.icon(
              onPressed: busy || devicePin ? null : resolve,
              icon: const NwlIcon(Icons.link_rounded),
              label: Text(busy ? 'กำลังอ่านหมุด…' : 'อ่านพิกัดจากลิงก์'),
            ),
            if (cinematicEnabled)
              TextButton.icon(
                onPressed: busy ? null : locate,
                icon: const NwlIcon(Icons.location_on_outlined),
                label: const Text('ใช้ตำแหน่งปัจจุบัน'),
              ),
            if (error.isNotEmpty) ...[
              SizedBox(height: compact ? 8 : 20),
              Notice(error, warning: true),
            ],
            if (pin != null) ...[
              SizedBox(height: compact ? 8 : 24),
              if (compact)
                Text(
                  'พิกัด: ${pin!.lat.toStringAsFixed(6)}, ${pin!.lng.toStringAsFixed(6)}',
                )
              else
                Notice(
                  '${pin!.lat.toStringAsFixed(6)}, ${pin!.lng.toStringAsFixed(6)}',
                ),
              if (pin!.viewport || devicePin)
                CheckboxListTile(
                  dense: compact,
                  contentPadding: EdgeInsets.zero,
                  value: confirmed,
                  onChanged: (v) => setState(() => confirmed = v ?? false),
                  title: Text(
                    devicePin
                        ? 'ยืนยันใช้พิกัดนี้เป็นหมุดที่บันทึก'
                        : compact
                        ? 'ยืนยันจุดกลางแผนที่ (อาจไม่ใช่หมุด)'
                        : 'ยืนยันใช้จุดกลางแผนที่นี้',
                  ),
                  subtitle: compact || devicePin
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
              onPressed:
                  pin != null &&
                      name.text.trim().isNotEmpty &&
                      (!(pin!.viewport || devicePin) || confirmed)
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
