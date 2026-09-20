import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FeedbackService {
  final SupabaseClient _db;

  FeedbackService([SupabaseClient? db])
      : _db = db ?? Supabase.instance.client;

  /// Submits user feedback or bug report to Supabase.
  Future<void> submitFeedback({
    required String category,
    required String message,
    int? rating,
    String? contactEmail,
    String? deviceInfo,
    String? appVersion,
  }) async {
    final user = _db.auth.currentUser;
    final platformStr = kIsWeb
        ? 'web'
        : Platform.isAndroid
            ? 'android'
            : Platform.isIOS
                ? 'ios'
                : 'desktop';

    final effectiveDeviceInfo = deviceInfo ?? 'platform: $platformStr';

    await _db.from('user_feedback').insert({
      if (user != null) 'user_id': user.id,
      'category': category,
      'message': message.trim(),
      if (rating != null) 'rating': rating,
      if (contactEmail != null && contactEmail.trim().isNotEmpty)
        'contact_email': contactEmail.trim(),
      'device_info': effectiveDeviceInfo,
      if (appVersion != null) 'app_version': appVersion,
    });
  }
}
