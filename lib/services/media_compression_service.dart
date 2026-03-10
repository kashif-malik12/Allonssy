import 'dart:io' show Directory, File, Platform;
import 'dart:typed_data';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

class CompressedImageResult {
  const CompressedImageResult({
    required this.bytes,
    required this.extension,
    required this.contentType,
  });

  final Uint8List bytes;
  final String extension;
  final String contentType;
}

class MediaCompressionService {
  static Future<CompressedImageResult> compressImage(
    XFile image, {
    int quality = 78,
  }) async {
    try {
      final sourceBytes = await image.readAsBytes();
      final compressed = await FlutterImageCompress.compressWithList(
        sourceBytes,
        quality: quality,
        minWidth: 1600,
        minHeight: 1600,
        format: CompressFormat.jpeg,
        keepExif: true,
      );
      final bytes = compressed.isNotEmpty ? compressed : sourceBytes;
      return CompressedImageResult(
        bytes: Uint8List.fromList(bytes),
        extension: 'jpg',
        contentType: 'image/jpeg',
      );
    } catch (_) {
      final fallbackBytes = await image.readAsBytes();
      final ext = image.name.split('.').last.toLowerCase();
      final safeExt = ext.isEmpty ? 'jpg' : ext;
      return CompressedImageResult(
        bytes: fallbackBytes,
        extension: safeExt,
        contentType: _imageContentType(safeExt),
      );
    }
  }

  static Future<XFile> compressVideo(XFile video) async {
    if (kIsWeb) return video;
    if (!(Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
      return video;
    }

    final sourcePath = video.path;
    if (sourcePath.isEmpty) return video;

    final outputPath =
        '${Directory.systemTemp.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final command =
        '-y -i "${_escapePath(sourcePath)}" -vf "scale=\'min(1280,iw)\':-2" '
        '-c:v libx264 -preset veryfast -crf 30 '
        '-c:a aac -b:a 128k -movflags +faststart "${_escapePath(outputPath)}"';

    try {
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();
      final outputFile = File(outputPath);
      if (!ReturnCode.isSuccess(returnCode) || !outputFile.existsSync()) {
        return video;
      }

      final originalSize = await video.length();
      final compressedSize = outputFile.lengthSync();
      if (compressedSize <= 0 || compressedSize >= originalSize) {
        if (outputFile.existsSync()) {
          outputFile.deleteSync();
        }
        return video;
      }

      return XFile(outputFile.path, mimeType: 'video/mp4', name: 'compressed.mp4');
    } catch (_) {
      return video;
    }
  }

  static String _escapePath(String value) => value.replaceAll('"', r'\"');

  static String _imageContentType(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }
}
