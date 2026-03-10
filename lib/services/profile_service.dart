import 'dart:io' show File;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'media_compression_service.dart';

class ProfileService {
  final SupabaseClient _db;
  ProfileService(this._db);

  String _contentTypeFromExt(String ext) {
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

  Future<String> uploadAvatar({
    required XFile image,
    required String userId,
  }) async {
    final compressed = await MediaCompressionService.compressImage(image, quality: 72);
    final safeExt = compressed.extension;

    final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.$safeExt';
    final path = '$userId/$fileName';

    await _db.storage.from('avatars').uploadBinary(
          path,
          compressed.bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: compressed.contentType,
          ),
        );

    // Works if bucket is PUBLIC
    return _db.storage.from('avatars').getPublicUrl(path);
  }

  Future<void> updateAvatarUrl({
    required String userId,
    required String avatarUrl,
  }) async {
    await _db.from('profiles').update({'avatar_url': avatarUrl}).eq('id', userId);
  }
}
