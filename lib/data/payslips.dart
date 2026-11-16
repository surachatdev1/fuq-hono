import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../core/models.dart';

typedef PayslipOption = ({String id, String label});
typedef PayslipOptions = ({List<PayslipOption> items, String? selected});
typedef PayslipLine = ({String label, String? amount});

class Payslip {
  Payslip(Map<String, dynamic> data)
    : period = data['period']['label'] as String,
      gross = data['summary']['gross'] as String,
      withheld = data['summary']['deductions'] as String,
      net = data['summary']['net'] as String,
      earnings = _lines(data['earnings']),
      deductions = _lines(data['deductions']),
      reimbursements = _lines(data['reimbursements']),
      arrears = _lines(data['arrears']);

  final String period, gross, withheld, net;
  final List<PayslipLine> earnings, deductions, reimbursements, arrears;

  static List<PayslipLine> _lines(dynamic items) => [
    for (final item in items as List)
      (label: item['label'] as String, amount: item['amount'] as String?),
  ];
}

class PayslipAccessDenied extends AppFailure {
  const PayslipAccessDenied(super.message);
}

class PayslipsApi {
  PayslipsApi({required this.company, required this.employee});
  final String company, employee;
  final _client = http.Client();

  void close() => _client.close();

  Future<PayslipOptions> options({String? year}) async {
    final data = await _json(year == null ? 'years' : 'periods', year: year);
    final items = [
      for (final item in data['options'] as List)
        (id: item['id'] as String, label: item['label'] as String),
    ];
    final selected = data['selected'];
    return (
      items: items,
      selected: items.any((item) => item.id == selected)
          ? selected as String
          : items.length == 1
          ? items.single.id
          : null,
    );
  }

  Future<Payslip> detail(String year, String period) async =>
      Payslip(await _json('detail', year: year, period: period));

  Future<Uint8List> pdf(String year, String period) async {
    final res = await _request('pdf', year: year, period: period);
    if (res.headers['content-type']?.split(';').first != 'application/pdf') {
      throw const AppFailure('ไฟล์สลิปจาก HONO ไม่ถูกต้อง');
    }
    return res.bodyBytes;
  }

  Future<Map<String, dynamic>> _json(
    String action, {
    String? year,
    String? period,
  }) async =>
      jsonDecode((await _request(action, year: year, period: period)).body)
          as Map<String, dynamic>;

  Future<http.Response> _request(
    String action, {
    String? year,
    String? period,
  }) async {
    final response = await _client
        .post(
          Uri.base.resolve('/api/payslips'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'action': action,
            'company': company,
            'employee': employee,
            if (year != null) 'year': year,
            if (period != null) 'period': period,
          }),
        )
        .timeout(const Duration(seconds: 55));
    if (response.statusCode != 200) {
      dynamic failure;
      try {
        failure = jsonDecode(response.body);
      } on FormatException {
        throw const AppFailure('อ่านสลิปจาก HONO ไม่สำเร็จ กรุณาลองใหม่');
      }
      final rawMessage = failure is Map ? failure['message'] : null;
      final message = rawMessage is String
          ? rawMessage
          : 'อ่านสลิปจาก HONO ไม่สำเร็จ';
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw PayslipAccessDenied(message);
      }
      throw AppFailure(message);
    }
    return response;
  }
}
