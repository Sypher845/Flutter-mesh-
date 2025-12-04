import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ImageHelper {
  // Private constructor to prevent instantiation
  ImageHelper._();

  static const int _maxDimension = 800;
  static const int _jpegQuality = 85;
  static const int _maxFileSizeKB = 200;

  static Future<File?> compressImage(File imageFile) async {
    try {
      // Check file size first
      final fileSize = await imageFile.length();
      if (fileSize <= _maxFileSizeKB * 1024) {
        return imageFile; // Already small enough
      }

      final imageBytes = await imageFile.readAsBytes();
      final image = img.decodeImage(imageBytes);
      
      if (image == null) return null;
      
      // Resize if needed
      final resizedImage = _resizeIfNeeded(image);
      
      // Compress as JPEG
      final compressedBytes = img.encodeJpg(resizedImage, quality: _jpegQuality);
      
      // Save to temp file
      return await _saveTempFile(compressedBytes);
    } catch (e) {
      return null;
    }
  }

  static img.Image _resizeIfNeeded(img.Image image) {
    if (image.width <= _maxDimension && image.height <= _maxDimension) {
      return image;
    }

    return img.copyResize(
      image,
      width: image.width > image.height ? _maxDimension : null,
      height: image.height > image.width ? _maxDimension : null,
    );
  }

  static Future<File> _saveTempFile(List<int> bytes) async {
    final tempDir = await getTemporaryDirectory();
    final fileName = 'compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final file = File(path.join(tempDir.path, fileName));
    return await file.writeAsBytes(bytes);
  }
}
