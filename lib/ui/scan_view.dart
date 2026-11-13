import 'package:flutter/material.dart';
import '../core/models.dart';
import 'cinematic.dart';
import 'design.dart';

// Pure Flutter presentation used both by the live camera and rendered UI tests.
class ScanView extends StatelessWidget {
  const ScanView({
    super.key,
    required this.punch,
    required this.place,
    required this.preview,
    this.matched = false,
    this.busy = false,
    this.found = false,
    this.blink = false,
    this.error = '',
    this.stage = '',
    this.countdown,
    this.captureGuidance,
    this.photoTaken = false,
    this.outcomeUnknown = false,
    this.onRetry,
    this.onBack,
  });
  final int? countdown;
  final String? captureGuidance;
  final Punch punch;
  final Place place;
  final Widget preview;
  final bool matched, busy, found, blink;
  final bool photoTaken, outcomeUnknown;
  final String error, stage;
  final VoidCallback? onRetry, onBack;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final compact = c.maxHeight < 650;
      final errorColor = cinematicEnabled ? coral : amber;
      final showCaptureStatus = photoTaken && error.isEmpty;
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          compact ? 16 : 24,
          8,
          compact ? 16 : 24,
          compact ? 8 : 24,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(compact ? 8 : 16),
                  decoration: BoxDecoration(
                    color: panel,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      const NwlIcon(
                        Icons.location_on_outlined,
                        color: mint,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              place.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${place.fromHono ? 'พื้นที่ที่ HONO กำหนด' : 'หมุดที่เลือก'}'
                              ' · ${place.lat.toStringAsFixed(6)}, ${place.lng.toStringAsFixed(6)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: compact ? 8 : 16),
                Container(
                  height: compact
                      ? (c.maxHeight -
                                (error.isNotEmpty
                                    ? 380
                                    : busy
                                    ? 320
                                    : 300))
                            .clamp(100, 370)
                      : (c.maxHeight * .51).clamp(200, 370),
                  width: double.infinity,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: panel,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      preview,
                      if ((countdown ?? 0) > 0 && captureGuidance == null)
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$countdown',
                              style: const TextStyle(
                                fontSize: 56,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      if (showCaptureStatus)
                        ColoredBox(
                          color: panel,
                          child: Center(
                            child: Semantics(
                              liveRegion: true,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const NwlIcon(
                                    Icons.camera_alt_outlined,
                                    color: mint,
                                    size: 24,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'ถ่ายภาพแล้ว',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        Center(
                          child: FractionallySizedBox(
                            widthFactor: .76,
                            heightFactor: .88,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: error.isNotEmpty ? errorColor : mint,
                                  width: 2,
                                ),
                                borderRadius: const BorderRadius.all(
                                  Radius.elliptical(180, 240),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: compact ? 8 : 20),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          _step(1, 'จัดใบหน้าให้อยู่ในกรอบ', found, !found),
                          const SizedBox(height: 4),
                          _step(2, 'กะพริบตา 1 ครั้ง', blink, found && !blink),
                          if (cinematicEnabled) ...[
                            const SizedBox(height: 4),
                            _step(3, 'ยืนยันตัวตน', matched, busy && !matched),
                          ],
                        ],
                      ),
                    ),
                    if (cinematicEnabled && c.maxWidth >= 350) ...[
                      const SizedBox(width: 8),
                      SizedBox(
                        width: compact ? 52 : 85,
                        height: compact ? 64 : 90,
                        child: const MascotArt('scan'),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: compact ? 8 : 20),
                if (!compact)
                  AnimatedSwitcher(
                    duration: reduceCinematicMotion(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 420),
                    child: NwlIcon(
                      error.isNotEmpty
                          ? Icons.info_outline_rounded
                          : matched
                          ? Icons.check_circle_outline_rounded
                          : Icons.face_retouching_natural,
                      key: ValueKey(
                        error.isNotEmpty
                            ? 'scan-error'
                            : matched
                            ? 'scan-match'
                            : 'scan-ready',
                      ),
                      color: error.isNotEmpty ? errorColor : mint,
                      size: 36,
                    ),
                  ),
                const SizedBox(height: 10),
                Text(
                  outcomeUnknown
                      ? 'ยังยืนยันผลการลงเวลาไม่ได้'
                      : error.isNotEmpty
                      ? 'ยืนยันไม่สำเร็จ'
                      : matched
                      ? 'ใบหน้าตรงกัน'
                      : countdown != null
                      ? 'เตรียมตัวถ่ายภาพ'
                      : busy
                      ? 'กำลังยืนยันตัวตน'
                      : photoTaken
                      ? 'สแกนเสร็จแล้ว'
                      : found
                      ? 'ขั้นตอน 2 · กะพริบตา'
                      : 'ขั้นตอน 1 · จัดใบหน้า',
                  textAlign: TextAlign.center,
                  style:
                      (compact
                              ? Theme.of(context).textTheme.titleMedium
                              : Theme.of(context).textTheme.titleLarge)
                          ?.copyWith(
                            color: error.isNotEmpty ? errorColor : paper,
                          ),
                ),
                const SizedBox(height: 10),
                Text(
                  error.isNotEmpty
                      ? error
                      : countdown != null
                      ? captureGuidance ??
                            'มองกล้องค้างไว้ ถ่ายอัตโนมัติหลังนับถอยหลัง'
                      : stage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: muted,
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
                SizedBox(height: compact ? 8 : 20),
                if (busy) ...[
                  const LinearProgressIndicator(
                    minHeight: 4,
                    borderRadius: BorderRadius.all(Radius.circular(4)),
                  ),
                  const SizedBox(height: 12),
                  if (!compact)
                    const Text(
                      'ไม่ต้องกดยืนยันซ้ำ',
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                ],
                if (error.isNotEmpty && !outcomeUnknown)
                  PrimaryButton(
                    'ยืนยันและสแกนใหม่',
                    onPressed: onRetry,
                    icon: Icons.refresh_rounded,
                  ),
                if (!busy)
                  TextButton(
                    onPressed: onBack,
                    child: Text(
                      outcomeUnknown ? 'ตรวจประวัติลงเวลา' : 'กลับหน้าหลัก',
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
  Widget _step(int number, String label, bool done, bool current) {
    final stopped = cinematicEnabled && error.isNotEmpty;
    final active = current && !stopped;
    return Semantics(
      label:
          'ขั้นตอน $number $label ${done
              ? 'ผ่านแล้ว'
              : active
              ? 'กำลังทำ'
              : stopped
              ? 'หยุดแล้ว'
              : 'รอขั้นตอนก่อนหน้า'}',
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: done ? mint : panel,
              shape: BoxShape.circle,
              border: Border.all(color: done || active ? mint : muted),
            ),
            child: Center(
              child: done
                  ? const NwlIcon(Icons.check_rounded, color: ink, size: 20)
                  : Text(
                      '$number',
                      style: TextStyle(
                        color: active ? paper : muted,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: done || active ? paper : muted,
              ),
            ),
          ),
          Text(
            done
                ? 'ผ่านแล้ว'
                : active
                ? 'กำลังทำ'
                : stopped
                ? 'หยุด'
                : 'รอก่อน',
            key: ValueKey('scan-step-$number'),
            style: TextStyle(fontSize: 12, color: done ? mint : muted),
          ),
        ],
      ),
    );
  }
}
