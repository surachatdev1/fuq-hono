import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../core/models.dart';

// Pure work for the native capture isolate. Web keeps its checked JPEG bytes.
({Uint8List jpeg, Uint8List png}) prepareNativeCapture(Uint8List capture) {
  final decoded = img.decodeImage(capture);
  if (decoded == null) throw const AppFailure('อ่านภาพกล้องไม่สำเร็จ');
  final upright = img.bakeOrientation(decoded);
  final longest = upright.width > upright.height
      ? upright.width
      : upright.height;
  final resized = longest <= 1280
      ? upright
      : img.copyResize(
          upright,
          width: (upright.width * 1280 / longest).round(),
          height: (upright.height * 1280 / longest).round(),
          interpolation: img.Interpolation.average,
        );
  Uint8List? jpeg;
  for (final quality in [92, 85, 76]) {
    final candidate = img.encodeJpg(resized, quality: quality);
    if (candidate.length <= 1500000) {
      jpeg = candidate;
      break;
    }
    candidate.fillRange(0, candidate.length, 0);
  }
  if (jpeg == null) throw const AppFailure('ภาพใหญ่เกินกำหนด กรุณาสแกนใหม่');
  final checked = img.decodeJpg(jpeg);
  if (checked == null) throw const AppFailure('เตรียมภาพลงเวลาไม่สำเร็จ');
  return (jpeg: jpeg, png: img.encodePng(checked, level: 3));
}
