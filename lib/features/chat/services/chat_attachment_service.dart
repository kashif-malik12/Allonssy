import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/media_limits.dart';
import '../../../services/media_compression_service.dart';

class ChatAttachmentService {
  ChatAttachmentService(this._db);

  final SupabaseClient _db;

  static const int maxImageBytes = MediaLimits.maxPhotoBytes;
  static const int maxFileBytes = 10 * 1024 * 1024;
  static const String _bucket = 'post-images';

  Future<String> uploadImage(XFile image) async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) throw Exception('Not logged in');

    final compressed = await MediaCompressionService.compressImage(image);
    final safeExt = compressed.extension;
    final path = '$userId/chat_attachments/${DateTime.now().millisecondsSinceEpoch}_image.$safeExt';

    await _db.storage.from(_bucket).uploadBinary(
          path,
          compressed.bytes,
          fileOptions: FileOptions(contentType: compressed.contentType),
        );

    return _db.storage.from(_bucket).getPublicUrl(path);
  }

  Future<String> uploadFile(PlatformFile file) async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) throw Exception('Not logged in');
    if ((file.bytes == null) && ((file.path ?? '').isEmpty)) {
      throw Exception('File bytes unavailable');
    }

    final safeName = file.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path = '$userId/chat_attachments/${DateTime.now().millisecondsSinceEpoch}_$safeName';

    final bytes = file.bytes ?? await XFile(file.path ?? '').readAsBytes();
    await _db.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: _fileContentType(file.extension)),
        );

    return _db.storage.from(_bucket).getPublicUrl(path);
  }

  String _fileContentType(String? ext) {
    switch ((ext ?? '').toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'txt':
        return 'text/plain';
      case 'zip':
        return 'application/zip';
      default:
        return 'application/octet-stream';
    }
  }
}
