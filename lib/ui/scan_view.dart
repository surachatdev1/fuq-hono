import 'package:flutter/material.dart';
import '../core/models.dart';
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
    this.onRetry,
    this.onBack,
  });
  final Punch punch;
  final Place place;
  final Widget preview;
  final bool matched, busy, found, blink;
  final String error, stage;
  final VoidCallback? onRetry, onBack;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: panel,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    const Icon(
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
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'หมุดที่เลือก · ${place.lat.toStringAsFixed(6)}, ${place.lng.toStringAsFixed(6)}',
                            style: const TextStyle(fontSize: 11, color: muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                height: (c.maxHeight * .51).clamp(200, 370),
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
                    Center(
                      child: FractionallySizedBox(
                        widthFactor: .76,
                        heightFactor: .88,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: error.isNotEmpty ? amber : mint,
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
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 22,
                runSpacing: 10,
                children: [
                  _proof('พบใบหน้า', found),
                  _proof('กะพริบตา', blink),
                ],
              ),
              const SizedBox(height: 20),
              Icon(
                error.isNotEmpty
                    ? Icons.info_outline_rounded
                    : matched
                    ? Icons.check_circle_outline_rounded
                    : Icons.face_retouching_natural,
                color: error.isNotEmpty ? amber : mint,
                size: 32,
              ),
              const SizedBox(height: 10),
              Text(
                error.isNotEmpty
                    ? 'ยืนยันไม่สำเร็จ'
                    : matched
                    ? 'ใบหน้าตรงกัน'
                    : 'มองกล้อง แล้วกะพริบตา',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: error.isNotEmpty ? amber : paper,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                error.isNotEmpty ? error : stage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: muted, fontSize: 14, height: 1.6),
              ),
              const SizedBox(height: 20),
              if (busy) ...[
                const LinearProgressIndicator(
                  minHeight: 4,
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
                const SizedBox(height: 12),
                const Text(
                  'ไม่ต้องกดยืนยันซ้ำ',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ],
              if (error.isNotEmpty)
                PrimaryButton(
                  'ยืนยันและสแกนใหม่',
                  onPressed: onRetry,
                  icon: Icons.refresh_rounded,
                ),
              if (!busy)
                TextButton(
                  onPressed: onBack,
                  child: const Text('กลับหน้าหลัก'),
                ),
            ],
          ),
        ),
      ),
    ),
  );
  Widget _proof(String label, bool done) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        done
            ? Icons.check_circle_outline_rounded
            : Icons.radio_button_unchecked,
        size: 16,
        color: done ? mint : muted,
      ),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(fontSize: 12, color: done ? paper : muted)),
    ],
  );
}
