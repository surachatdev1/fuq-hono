import 'package:flutter/material.dart';
import '../core/models.dart';
import 'design.dart';

// The camera owns the entire surface. Guidance stays in the display layer.
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
    this.previewAspectRatio,
    this.detectedFace,
    this.photoTaken = false,
    this.outcomeUnknown = false,
    this.onRetry,
    this.onBack,
  });
  final int? countdown;
  final String? captureGuidance;
  final double? previewAspectRatio;
  final Rect? detectedFace;
  final Punch punch;
  final Place place;
  final Widget preview;
  final bool matched, busy, found, blink;
  final bool photoTaken, outcomeUnknown;
  final String error, stage;
  final VoidCallback? onRetry, onBack;

  String get _title => outcomeUnknown
      ? 'ยังยืนยันผลการลงเวลาไม่ได้'
      : error.isNotEmpty
      ? 'ยืนยันไม่สำเร็จ'
      : busy
      ? 'กำลังยืนยันตัวตน'
      : matched
      ? 'ใบหน้าตรงกัน'
      : countdown != null
      ? 'เตรียมตัวถ่ายภาพ'
      : photoTaken
      ? 'ถ่ายภาพแล้ว'
      : found
      ? 'กะพริบตา 1 ครั้ง'
      : 'จัดใบหน้าให้อยู่กลางกรอบ';

  String get _instruction => error.isNotEmpty
      ? error
      : busy
      ? stage
      : captureGuidance ??
            (countdown != null ? 'มองกล้องค้างไว้ ถ่ายภาพอัตโนมัติ' : stage);

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: ink,
    child: Stack(
      fit: StackFit.expand,
      children: [
        SizedBox(key: const ValueKey('scan-camera-surface'), child: preview),
        if (error.isEmpty && !photoTaken && !busy)
          IgnorePointer(
            child: _FaceGuide(
              previewAspectRatio: previewAspectRatio,
              detectedFace: detectedFace,
              color: found ? mint : Colors.white70,
            ),
          ),
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xD9080F25),
                  Color(0x00080F25),
                  Color(0x00080F25),
                  Color(0xF2080F25),
                ],
                stops: [0, .22, .50, 1],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'กลับหน้าหลัก',
                      onPressed: busy ? null : onBack,
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ลงเวลา${punch.label}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            place.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'รายละเอียดสถานที่',
                      icon: const Icon(Icons.location_on_outlined, color: mint),
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(place.displayName),
                          content: Text(
                            [
                              if (place.address != null) place.address!,
                              place.coordinates,
                            ].join('\n'),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('ปิด'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Align(
                  alignment: error.isNotEmpty || busy
                      ? Alignment.center
                      : Alignment.bottomCenter,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: Semantics(
                      liveRegion: true,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (photoTaken && error.isEmpty && busy) ...[
                            const Text(
                              'ถ่ายภาพแล้ว',
                              style: TextStyle(color: mint),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if ((countdown ?? 0) > 0 &&
                              !busy &&
                              captureGuidance == null)
                            Text(
                              '$countdown',
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w700,
                                color: mint,
                              ),
                            ),
                          Text(
                            _title,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: error.isNotEmpty ? coral : paper,
                                  shadows: const [
                                    Shadow(blurRadius: 12, color: Colors.black),
                                  ],
                                ),
                          ),
                          if (_instruction.isNotEmpty &&
                              _instruction != _title) ...[
                            const SizedBox(height: 8),
                            Text(
                              _instruction,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: paper,
                                height: 1.6,
                                shadows: [
                                  Shadow(blurRadius: 8, color: Colors.black),
                                ],
                              ),
                            ),
                          ],
                          if (busy) ...[
                            const SizedBox(height: 16),
                            const SizedBox(
                              width: 180,
                              child: LinearProgressIndicator(minHeight: 3),
                            ),
                          ],
                          if (error.isNotEmpty && !outcomeUnknown) ...[
                            const SizedBox(height: 20),
                            PrimaryButton(
                              'ยืนยันและสแกนใหม่',
                              onPressed: onRetry,
                              icon: Icons.refresh_rounded,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        _step(1, 'จัดหน้า', found, !found),
                        _step(2, 'กะพริบตา', blink, found && !blink),
                        _step(3, 'ยืนยัน', matched, busy && !matched),
                      ],
                    ),
                    if (!busy)
                      TextButton(
                        onPressed: onBack,
                        child: Text(
                          outcomeUnknown ? 'ตรวจประวัติลงเวลา' : 'กลับหน้าหลัก',
                        ),
                      )
                    else
                      const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _step(int number, String label, bool done, bool active) => Expanded(
    child: Semantics(
      label:
          'ขั้นตอน $number $label ${done
              ? 'ผ่านแล้ว'
              : error.isNotEmpty
              ? 'หยุดแล้ว'
              : active
              ? 'กำลังทำ'
              : 'รอขั้นตอนก่อนหน้า'}',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            color: done
                ? mint
                : active && error.isEmpty
                ? paper
                : muted,
            size: 16,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              key: ValueKey('scan-step-$number'),
              style: TextStyle(
                fontSize: 12,
                color: done || active ? paper : muted,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _FaceGuide extends StatelessWidget {
  const _FaceGuide({
    required this.previewAspectRatio,
    required this.detectedFace,
    required this.color,
  });
  final double? previewAspectRatio;
  final Rect? detectedFace;
  final Color color;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final ratio = previewAspectRatio;
      final available = constraints.biggest;
      final frame = ratio == null
          ? available
          : applyBoxFit(BoxFit.contain, Size(ratio, 1), available).destination;
      final face = detectedFace;
      if (face != null) {
        final imageRect = Rect.fromLTWH(
          (available.width - frame.width) / 2,
          (available.height - frame.height) / 2,
          frame.width,
          frame.height,
        );
        // The preview is mirrored; detector coordinates describe the source.
        final bounds = Rect.fromLTWH(
          imageRect.left + (1 - face.right) * frame.width,
          imageRect.top + face.top * frame.height,
          face.width * frame.width,
          face.height * frame.height,
        ).intersect(imageRect);
        if (bounds.isEmpty) return const SizedBox.shrink();
        return Stack(
          children: [
            Positioned.fromRect(
              rect: bounds,
              child: DecoratedBox(
                key: const ValueKey('detected-face-guide'),
                decoration: BoxDecoration(
                  border: Border.all(color: color, width: 1.5),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        );
      }
      return Center(
        child: SizedBox(
          key: const ValueKey('face-guide'),
          width: frame.width * .76,
          height: frame.height * .88,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: color, width: 1.5),
              borderRadius: const BorderRadius.all(Radius.elliptical(180, 240)),
            ),
          ),
        ),
      );
    },
  );
}
