import 'package:flutter/material.dart';
import '../core/controller.dart';
import '../features/attendance_insights.dart';
import 'design.dart';

const thaiMonths=['ม.ค.','ก.พ.','มี.ค.','เม.ย.','พ.ค.','มิ.ย.','ก.ค.','ส.ค.','ก.ย.','ต.ค.','พ.ย.','ธ.ค.'];
String insightDate(DateTime d) => '${d.day} ${thaiMonths[d.month-1]} ${d.year + 543}';
String historyClock(String raw,DateTime date) {
  final parsed=punchClock(raw,date);
  return parsed==null?'—':'${parsed.hour.toString().padLeft(2,'0')}:${parsed.minute.toString().padLeft(2,'0')}';
}

class HistoryInsightsPage extends StatefulWidget {
  const HistoryInsightsPage({super.key, required this.controller});
  final AppController controller;
  @override
  State<HistoryInsightsPage> createState() => _HistoryInsightsPageState();
}

class _HistoryInsightsPageState extends State<HistoryInsightsPage> {
  bool month = false;
  AppController get c => widget.controller;
  Future<void> pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: c.date,
      firstDate: DateTime(2020),
      lastDate: bangkokNow(),
      helpText: month
          ? 'เลือกวันในเดือนที่ต้องการสรุป'
          : 'เลือกวันที่ดูประวัติ',
    );
    if (selected == null) return;
    await c.changeDate(selected);
    if (month) await c.loadMonthlyReport();
  }

  Future<void> moveMonth(int delta) async {
    final target = DateTime(c.date.year, c.date.month + delta, 1),
        now = bangkokNow();
    if (target.isBefore(DateTime(2020)) ||
        target.isAfter(DateTime(now.year, now.month, 1))) {
      return;
    }
    await c.changeDate(target);
    await c.loadMonthlyReport();
  }

  @override
  Widget build(BuildContext context) {
    final report = c.lateReport;
    return PageBody(
      children: [
        Text(
          'ประวัติและการมาสาย',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
              value: false,
              label: Text('รายวัน'),
              icon: Icon(Icons.today_outlined),
            ),
            ButtonSegment(
              value: true,
              label: Text('สรุปรายเดือน'),
              icon: Icon(Icons.insights_outlined),
            ),
          ],
          selected: {month},
          onSelectionChanged: (s) {
            setState(() => month = s.single);
            if (month && c.lateReport == null) c.loadMonthlyReport();
          },
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            if (month)
              IconButton(
                tooltip: 'เดือนก่อน',
                onPressed: () => moveMonth(-1),
                icon: const Icon(Icons.chevron_left),
              ),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: pickDate,
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(
                  month
                      ? '${c.date.month}/${c.date.year + 543}'
                      : insightDate(c.date),
                ),
              ),
            ),
            if (month)
              IconButton(
                tooltip: 'เดือนถัดไป',
                onPressed:
                    DateTime(
                      c.date.year,
                      c.date.month + 1,
                    ).isAfter(DateTime(bangkokNow().year, bangkokNow().month))
                    ? null
                    : () => moveMonth(1),
                icon: const Icon(Icons.chevron_right),
              ),
          ],
        ),
        TextButton.icon(
          onPressed: month
              ? (c.reportLoading ? null : c.loadMonthlyReport)
              : (c.loading ? null : c.refresh),
          icon: const Icon(Icons.refresh_rounded),
          label: Text(
            month ? 'โหลดปฏิทินหลังประมวลผล' : 'โหลดประวัติล่าสุด',
          ),
        ),
        if (month) ...[
          const Notice(
            'ใช้เวลาเข้าในปฏิทิน HONO หลังประมวลผล · เกิน 09:00 · เศษนาทีปัดขึ้น\nยอดรวมรายเดือนเกิน 30 นาที จะแสดงให้ตรวจสอบ',
          ),
          const SizedBox(height: 16),
          if (c.reportLoading) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 12),
            Text(
              'กำลังอ่านประวัติ ${c.reportProgress} วัน',
              textAlign: TextAlign.center,
            ),
          ],
          if (c.reportError.isNotEmpty) ...[
            Notice(c.reportError, warning: true),
            const SizedBox(height: 16),
          ],
          if (report != null) ...[
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: panel,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'สายรวมจากเวลาหลังประมวลผล',
                    style: TextStyle(color: muted),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${report.minutes} นาที',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: report.exceedsWarning ? amber : mint,
                    ),
                  ),
                  Text(
                    '${report.lateDays} วัน · เดือน ${report.month.month}/${report.month.year + 543}',
                    style: const TextStyle(color: muted),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    report.exceedsWarning
                        ? 'ยอดรวมเกิน 30 นาทีแล้ว ควรตรวจรายละเอียด'
                        : report.unknownDays > 0 || report.missingDays > 0
                        ? 'ข้อมูลยังไม่ครบ จึงยังยืนยันยอดรวมทั้งเดือนไม่ได้'
                        : report.minutes == 30
                        ? 'ครบ 30 นาที ยังไม่เกินเกณฑ์'
                        : 'ยอดที่ตรวจได้ยังไม่เกิน 30 นาที',
                    style: TextStyle(
                      color:
                          report.exceedsWarning ||
                              report.unknownDays > 0 ||
                              report.missingDays > 0
                          ? amber
                          : paper,
                    ),
                  ),
                ],
              ),
            ),
            if (report.missingDays > 0) ...[
              const SizedBox(height: 16),
              Notice(
                'มี ${report.missingDays} วันยังไม่มีเวลาเข้า จึงยังคำนวณสายของวันเหล่านั้นไม่ได้',
                warning: true,
              ),
            ],
            const SizedBox(height: 14),
            ...report.days.reversed.map((d) => _day(d)),
          ],
        ] else ...[
          if (!c.calendar.isWorkday(c.date)) ...[
            const Notice('วันหยุดตามปฏิทินที่ซิงก์ไว้หรือกำหนดในแอป'),
            const SizedBox(height: 16),
          ],
          if (c.loading || c.processedLoading) const LinearProgressIndicator(),
          if(c.processedDay!=null)...[
            const SizedBox(height:16),Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(color:mint.withValues(alpha:.07),borderRadius:BorderRadius.circular(22),border:Border.all(color:mint.withValues(alpha:.25))),
              child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                const Text('ปฏิทินหลังประมวลผล',style:TextStyle(color:mint,fontWeight:FontWeight.w600)),const SizedBox(height:10),
                Text(c.processedDay!.holiday?'วันหยุด':'${c.processedDay!.inTime.isEmpty?'—':c.processedDay!.inTime}  →  ${c.processedDay!.outTime.isEmpty?'—':c.processedDay!.outTime}',
                  style:const TextStyle(fontFamily:'NotoSans',fontSize:28,fontWeight:FontWeight.w500)),
                Text(c.processedDay!.status,style:const TextStyle(color:muted)),
                if(c.processedDay!.pending)const Text('มีรายการรออนุมัติ · ยังไม่สรุปสาย',style:TextStyle(color:amber)),
                const SizedBox(height:8),const Text('สรุปสายใช้ข้อมูลชุดนี้ ส่วนรายการด้านล่างเป็นเวลาตอกจริง',style:TextStyle(color:muted,fontSize:12)),
              ])),const SizedBox(height:16)],
          if(c.processedError.isNotEmpty)...[const SizedBox(height:12),Notice('${c.processedError} · ไม่ใช้เวลาตอกจริงคำนวณสาย',warning:true),const SizedBox(height:12)],
          if (c.historyError.isNotEmpty) ...[
            Notice(c.historyError, warning: true),
            const SizedBox(height: 12),
          ],
          if (c.uncertain) ...[
            Notice(c.receipt, warning: true),
            const SizedBox(height: 12),
            PrimaryButton(
              'ตรวจแล้ว เริ่มสแกนใหม่ได้',
              onPressed:
                  !c.loading &&
                      c.historyError.isEmpty &&
                      c.stateError.isEmpty &&
                      c.state != null
                  ? c.acknowledgeUnknown
                  : null,
            ),
            const Text(
              'เลือกวันนี้และโหลดประวัติให้สำเร็จก่อนเริ่มใหม่',
              style: TextStyle(color: muted, fontSize: 12),
            ),
          ],
          if (c.logs.isEmpty && !c.loading) ...[
            const SizedBox(height: 32),
            const Icon(Icons.history_rounded, size: 44, color: muted),
            const SizedBox(height: 18),
            Text(
              c.historyError.isNotEmpty
                  ? 'ยังอ่านประวัติของวันที่เลือกไม่สำเร็จ'
                  : c.demo
                  ? 'โหมดทดลอง · ไม่มีรายการจริง'
                  : 'ไม่มีรายการในวันที่เลือก',
              textAlign: TextAlign.center,
              style: const TextStyle(color: muted),
            ),
          ],
          const SizedBox(height:12),
          ...c.logs.map((e)=>Padding(padding:const EdgeInsets.only(bottom:12),child:Container(
            padding:const EdgeInsets.all(20),decoration:BoxDecoration(color:panel,borderRadius:BorderRadius.circular(22),border:Border.all(color:muted.withValues(alpha:.12))),
            child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Row(children:[Container(padding:const EdgeInsets.all(9),decoration:BoxDecoration(color:(e.flag=='I'?mint:lavender).withValues(alpha:.12),borderRadius:BorderRadius.circular(12)),
                child:Icon(e.flag=='I'?Icons.login_rounded:Icons.logout_rounded,color:e.flag=='I'?mint:lavender,size:20)),
                const SizedBox(width:12),Expanded(child:Text(e.flag=='I'?'เข้างาน':e.flag=='O'?'ออกงาน':e.flag,style:Theme.of(context).textTheme.titleMedium)),
                const Text('เวลาตอกจริง',style:TextStyle(color:muted,fontSize:11))]),
              const SizedBox(height:16),Text(historyClock(e.time,c.date),style:const TextStyle(fontFamily:'NotoSans',fontSize:38,fontWeight:FontWeight.w500,letterSpacing:-1)),
              Text(insightDate(c.date),style:const TextStyle(color:muted)),
              Theme(data:Theme.of(context).copyWith(dividerColor:Colors.transparent),child:ExpansionTile(tilePadding:EdgeInsets.zero,childrenPadding:const EdgeInsets.only(bottom:8),
                dense:true,title:const Text('ดูเวลาต้นฉบับ',style:TextStyle(color:muted,fontSize:12)),
                children:[Align(alignment:Alignment.centerLeft,child:SelectableText(e.time,style:const TextStyle(color:muted,fontSize:12)))])),
            ])))),
        ],
      ],
    );
  }

  Widget _day(LateDay d) {
    final (label, color) = switch (d.kind) {
      DayAttendance.late => ('สาย ${d.minutes} นาที', amber),
      DayAttendance.onTime => ('ตรงเวลา', mint),
      DayAttendance.holiday => ('วันหยุดตามปฏิทิน', muted),
      DayAttendance.noIn => ('ยังไม่มีเวลาเข้า', muted),
      DayAttendance.pending => ('ยังไม่ถึงกำหนด', muted),
      DayAttendance.unknown => ('ข้อมูลยังไม่ครบ', amber),
    };
    final time = d.firstIn;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: Icon(
        d.kind == DayAttendance.late
            ? Icons.schedule
            : Icons.event_available_outlined,
        color: color,
      ),
      title: Text(insightDate(d.date)),
      subtitle: Text(
        time == null
            ? label
            : 'เข้าหลังประมวลผล ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} · $label',
        style: TextStyle(color: color),
      ),
    );
  }
}
