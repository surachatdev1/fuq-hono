import 'dart:async';

import 'package:flutter/material.dart';

import '../core/models.dart';
import '../data/payslip_download_stub.dart'
    if (dart.library.js_interop) '../data/payslip_download_web.dart';
import '../data/payslips.dart';
import 'design.dart';

class PayslipPage extends StatefulWidget {
  const PayslipPage({super.key, required this.company, required this.employee});
  final String company, employee;

  @override
  State<PayslipPage> createState() => _PayslipPageState();
}

class _PayslipPageState extends State<PayslipPage> {
  late final _api = PayslipsApi(
    company: widget.company,
    employee: widget.employee,
  );
  List<PayslipOption> _years = [], _periods = [];
  String? _year, _period, _error;
  bool _loading = false;
  bool _yearsLoaded = false;
  Payslip? _slip;

  @override
  void initState() {
    super.initState();
    unawaited(_loadYears());
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        setState(() {
          if (error is PayslipAccessDenied) _slip = null;
          _error = error is AppFailure
              ? error.message
              : 'อ่านสลิปจาก HONO ไม่สำเร็จ กรุณาลองใหม่';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadYears() => _run(() async {
    final years = await _api.options();
    if (!mounted) return;
    setState(() {
      _years = years.items;
      _yearsLoaded = true;
    });
    if (years.selected case final year?) await _loadPeriods(year);
  });

  Future<void> _loadPeriods(String year) async {
    setState(() {
      _year = year;
      _period = null;
      _periods = [];
      _slip = null;
    });
    final periods = await _api.options(year: year);
    if (mounted) {
      setState(() {
        _periods = periods.items;
        _period = periods.selected;
      });
    }
  }

  Future<void> _showSlip(String year, String period) => _run(() async {
    setState(() => _slip = null);
    final slip = await _api.detail(year, period);
    if (mounted) setState(() => _slip = slip);
  });

  Future<void> _download(String year, String period) => _run(() async {
    final bytes = await _api.pdf(year, period);
    try {
      if (mounted) downloadPayslip(bytes);
    } finally {
      bytes.fillRange(0, bytes.length, 0);
    }
  });

  @override
  Widget build(BuildContext context) {
    final year = _year, period = _period, slip = _slip;
    return Scaffold(
      appBar: AppBar(title: const Text('สลิปเงินเดือน')),
      body: SafeArea(
        child: PageBody(
          children: [
            if (_loading) const LinearProgressIndicator(),
            if (_error case final error?) ...[
              Notice(error, warning: true),
              const SizedBox(height: 12),
            ],
            if (!_yearsLoaded && !_loading)
              PrimaryButton('โหลดงวดจาก HONO', onPressed: _loadYears),
            if (_yearsLoaded && _years.isEmpty)
              const Text('HONO ยังไม่มีงวดเงินเดือนสำหรับบัญชีนี้'),
            if (_years.isNotEmpty) ...[
              _picker(
                'ปีเงินเดือน',
                year,
                _years,
                (value) => _run(() => _loadPeriods(value)),
              ),
              const SizedBox(height: 14),
            ],
            if (_periods.isNotEmpty) ...[
              _picker('งวดจ่าย', period, _periods, (value) {
                setState(() {
                  _period = value;
                  _slip = null;
                  _error = null;
                });
              }),
              const SizedBox(height: 14),
            ],
            if (year != null && _periods.isEmpty && !_loading)
              if (_error == null)
                const Text('HONO ยังไม่มีงวดจ่ายในปีนี้')
              else
                TextButton(
                  onPressed: () => _run(() => _loadPeriods(year)),
                  child: const Text('ลองโหลดงวดอีกครั้ง'),
                ),
            if (year != null && period != null)
              PrimaryButton(
                'ดูสลิป',
                onPressed: _loading ? null : () => _showSlip(year, period),
                icon: Icons.receipt_long_outlined,
              ),
            if (slip != null && year != null && period != null) ...[
              const SizedBox(height: 20),
              _group(context, slip.period, [
                (label: 'รายรับรวม', amount: slip.gross),
                (label: 'รายการหักรวม', amount: slip.withheld),
                (label: 'ยอดสุทธิ', amount: slip.net),
              ]),
              _group(context, 'รายรับ', slip.earnings),
              _group(context, 'รายการหัก', slip.deductions),
              _group(context, 'เบิกคืน', slip.reimbursements),
              _group(context, 'รายการย้อนหลัง', slip.arrears),
              OutlinedButton.icon(
                onPressed: _loading ? null : () => _download(year, period),
                icon: const NwlIcon(Icons.download_outlined),
                label: const Text('ดาวน์โหลด PDF ต้นฉบับจาก HONO'),
              ),
              const SizedBox(height: 8),
              const Text(
                'หาก PDF ขอรหัสเปิดไฟล์ ให้ตรวจข้อความแจ้งรหัสสลิปหรือสอบถามฝ่ายบุคคล PSD',
                style: TextStyle(color: muted),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _picker(
    String label,
    String? selected,
    List<PayslipOption> options,
    ValueChanged<String> onChanged,
  ) => DropdownButtonFormField<String>(
    key: ValueKey((label, selected, _year)),
    initialValue: selected,
    decoration: InputDecoration(labelText: label),
    isExpanded: true,
    items: [
      for (final option in options)
        DropdownMenuItem(
          value: option.id,
          child: Text(option.label, overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: _loading
        ? null
        : (value) {
            if (value != null) onChanged(value);
          },
  );

  Widget _group(BuildContext context, String title, List<PayslipLine> lines) {
    if (lines.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(line.label)),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        line.amount ?? '—',
                        textAlign: TextAlign.end,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
