import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class ImageCompressor {
  /// Compresses the given [bytes] and encodes them into WebP format.
  /// Resizes the image to fit within [maxWidth] and [maxHeight] while maintaining aspect ratio.
  /// Uses a background Isolate via [compute] to prevent UI thread blocking.
  static Future<({Uint8List bytes, String fileName})> compressToWebp({
    required List<int> bytes,
    required String originalFileName,
    int maxWidth = 1024,
    int maxHeight = 1024,
    int quality = 80,
  }) async {
    // Basic verification of file type by extension to avoid processing PDFs or non-images if any are uploaded.
    final lowerName = originalFileName.toLowerCase();
    final isImage = lowerName.endsWith('.jpg') ||
        lowerName.endsWith('.jpeg') ||
        lowerName.endsWith('.png') ||
        lowerName.endsWith('.webp') ||
        lowerName.endsWith('.gif') ||
        lowerName.endsWith('.bmp');

    if (!isImage) {
      // If it is not a standard image format, return as is.
      return (bytes: Uint8List.fromList(bytes), fileName: originalFileName);
    }

    try {
      final result = await compute(_compressTask, {
        'bytes': bytes,
        'maxWidth': maxWidth,
        'maxHeight': maxHeight,
      });

      if (result != null) {
        final nameWithoutExt = originalFileName.contains('.')
            ? originalFileName.substring(0, originalFileName.lastIndexOf('.'))
            : originalFileName;
        return (bytes: result, fileName: '$nameWithoutExt.webp');
      }
    } catch (e) {
      debugPrint('Failed to compress image to WebP: $e');
    }

    // Fallback: return original bytes if processing failed
    return (bytes: Uint8List.fromList(bytes), fileName: originalFileName);
  }

  /// Isolate runner task
  static Uint8List? _compressTask(Map<String, dynamic> params) {
    final List<int> bytes = params['bytes'];
    final int maxWidth = params['maxWidth'];
    final int maxHeight = params['maxHeight'];

    // 1. Decode image
    final img.Image? decodedImage = img.decodeImage(Uint8List.fromList(bytes));
    if (decodedImage == null) return null;

    // 2. Resize proportionally if dimensions exceed limits
    img.Image resizedImage = decodedImage;
    if (decodedImage.width > maxWidth || decodedImage.height > maxHeight) {
      resizedImage = img.copyResize(
        decodedImage,
        width: decodedImage.width > decodedImage.height ? maxWidth : null,
        height: decodedImage.height >= decodedImage.width ? maxHeight : null,
        interpolation: img.Interpolation.average,
      );
    }

    // 3. Encode to WebP (lossless)
    return img.encodeWebP(resizedImage);
  }
}
