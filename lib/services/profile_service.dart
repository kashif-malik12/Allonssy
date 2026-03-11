import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'media_compression_service.dart';

class ProfileService {
  final SupabaseClient _db;
  ProfileService(this._db);

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
