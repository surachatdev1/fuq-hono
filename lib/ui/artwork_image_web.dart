import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:web/web.dart' as web;

final _softwareRendering = _needsRasterImages();

bool _needsRasterImages() {
  if (!const bool.fromEnvironment('NWL_CINEMATIC')) return false;
  final canvas = web.document.createElement('canvas') as web.HTMLCanvasElement;
  try {
    return canvas.getContext('webgl2') == null &&
        canvas.getContext('webgl') == null;
  } catch (_) {
    return true;
  }
}

AssetImage artworkImage(String asset) =>
    _softwareRendering ? _RasterArtwork(asset) : AssetImage(asset);

/// A software CanvasKit surface needs pixels rather than a lazy GPU texture.
class _RasterArtwork extends AssetImage {
  const _RasterArtwork(super.assetName);

  @override
  ImageStreamCompleter loadImage(
    AssetBundleImageKey key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(_decodeRaster(key));

  Future<ImageInfo> _decodeRaster(AssetBundleImageKey key) async {
    final image = web.document.createElement('img') as web.HTMLImageElement;
    image.src = Uri.parse(
      web.document.baseURI,
    ).resolve('assets/${Uri.encodeFull(key.name)}').toString();
    await image.decode().toDart;
    final width = image.naturalWidth;
    final height = image.naturalHeight;
    final canvas = web.document.createElement('canvas') as web.HTMLCanvasElement
      ..width = width
      ..height = height;
    final context = canvas.getContext('2d') as web.CanvasRenderingContext2D;
    context.drawImage(image, 0, 0);
    final pixels = context.getImageData(0, 0, width, height).data.toDart;
    canvas
      ..width = 0
      ..height = 0;
    // Canvas exposes straight alpha. CanvasKit's RGBA pixel format expects premultiplied alpha.
    for (var i = 0; i < pixels.length; i += 4) {
      final alpha = pixels[i + 3];
      if (alpha == 255) continue;
      pixels[i] = (pixels[i] * alpha + 127) ~/ 255;
      pixels[i + 1] = (pixels[i + 1] * alpha + 127) ~/ 255;
      pixels[i + 2] = (pixels[i + 2] * alpha + 127) ~/ 255;
    }
    final decoded = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      Uint8List.view(pixels.buffer, pixels.offsetInBytes, pixels.lengthInBytes),
      width,
      height,
      ui.PixelFormat.rgba8888,
      decoded.complete,
      rowBytes: width * 4,
    );
    return ImageInfo(image: await decoded.future, scale: key.scale);
  }
}
