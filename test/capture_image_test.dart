import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nwl_secret_login/data/capture_image.dart';
import 'package:nwl_secret_login/core/models.dart';

void main() {
  test(
    'native capture respects EXIF orientation and limits the longest edge',
    () {
      final source = img.Image(width: 1600, height: 900);
      img.fill(source, color: img.ColorRgb8(100, 130, 170));
      source.exif.imageIfd.orientation = 6;
      final input = img.encodeJpg(source, quality: 95);
      final output = prepareNativeCapture(input);
      final jpeg = img.decodeJpg(output.jpeg)!;
      expect((jpeg.width, jpeg.height), (720, 1280));
      final png = img.decodePng(output.png)!;
      expect((png.width, png.height), (jpeg.width, jpeg.height));
      expect(
        png.getBytes(order: img.ChannelOrder.rgb),
        jpeg.getBytes(order: img.ChannelOrder.rgb),
      );
      expect(output.jpeg.length, lessThanOrEqualTo(1500000));
    },
  );

  test(
    'native capture preserves detail better than the former quality 20 encode',
    () {
      final source = img.Image(width: 128, height: 160);
      for (var y = 0; y < source.height; y++) {
        for (var x = 0; x < source.width; x++) {
          source.setPixelRgb(
            x,
            y,
            (x * 9 + y * 3) % 256,
            (x * 4 + y * 7) % 256,
            (x * 5 + y * 2) % 256,
          );
        }
      }
      final input = img.encodeJpg(source, quality: 98);
      final reference = img.decodeJpg(input)!;
      final output = prepareNativeCapture(input);
      final current = img.decodeJpg(output.jpeg)!;
      final previous = img.decodeJpg(img.encodeJpg(reference, quality: 20))!;
      double error(img.Image image) {
        final a = reference.getBytes(order: img.ChannelOrder.rgb);
        final b = image.getBytes(order: img.ChannelOrder.rgb);
        var total = 0.0;
        for (var i = 0; i < a.length; i++) {
          total += (a[i] - b[i]) * (a[i] - b[i]);
        }
        return total / a.length;
      }

      expect((current.width, current.height), (128, 160));
      expect(error(current), lessThan(error(previous)));
    },
  );

  test('invalid capture fails before verification', () {
    expect(
      () => prepareNativeCapture(Uint8List.fromList([1, 2, 3])),
      throwsA(isA<AppFailure>()),
    );
  });
}
