import 'package:supabase_flutter/supabase_flutter.dart';

class AppSettingsService {
  AppSettingsService._();

  static const String _settingsKey = 'app_settings';
  static const String _videoAutoplayKey = 'video_autoplay';

  static bool currentVideoAutoplayEnabled() {
    final user = Supabase.instance.client.auth.currentUser;
    final metadata = user?.userMetadata;
    final settings = metadata?[_settingsKey];
    if (settings is Map && settings[_videoAutoplayKey] is bool) {
      return settings[_videoAutoplayKey] as bool;
    }
    return false;
  }

  static Future<void> setVideoAutoplayEnabled(bool enabled) async {
    final auth = Supabase.instance.client.auth;
    final user = auth.currentUser;
    if (user == null) {
      throw Exception('Not logged in');
    }

    final metadata = Map<String, dynamic>.from(user.userMetadata ?? const {});
    final currentSettings = metadata[_settingsKey];
    final settings = currentSettings is Map
        ? Map<String, dynamic>.from(currentSettings)
        : <String, dynamic>{};
    settings[_videoAutoplayKey] = enabled;
    metadata[_settingsKey] = settings;

    await auth.updateUser(UserAttributes(data: metadata));
  }
}
