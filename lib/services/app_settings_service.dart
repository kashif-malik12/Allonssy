import 'package:supabase_flutter/supabase_flutter.dart';

class AppSettings {
  const AppSettings(this.values);

  final Map<String, bool> values;

  bool get videoAutoplayEnabled =>
      values[AppSettingsService.videoAutoplayKey] ?? false;

  bool enabled(String key) => values[key] ?? AppSettingsService.defaultForKey(key);

  AppSettings copyWithValue(String key, bool value) {
    return AppSettings({
      ...values,
      key: value,
    });
  }
}

class AppSettingsService {
  AppSettingsService._();

  static const String settingsKey = 'app_settings';
  static const String videoAutoplayKey = 'video_autoplay';

  static const String inAppChatMessagesKey = 'in_app_chat_messages';
  static const String inAppOfferMessagesKey = 'in_app_offer_messages';
  static const String inAppOfferUpdatesKey = 'in_app_offer_updates';
  static const String inAppCommentsKey = 'in_app_comments';
  static const String inAppRepliesKey = 'in_app_replies';
  static const String inAppMentionsKey = 'in_app_mentions';
  static const String inAppFollowRequestsKey = 'in_app_follow_requests';
  static const String inAppNewFollowersKey = 'in_app_new_followers';
  static const String inAppAdminUpdatesKey = 'in_app_admin_updates';

  static const String pushChatMessagesKey = 'push_chat_messages';
  static const String pushOfferMessagesKey = 'push_offer_messages';
  static const String pushOfferUpdatesKey = 'push_offer_updates';
  static const String pushCommentsKey = 'push_comments';
  static const String pushRepliesKey = 'push_replies';
  static const String pushMentionsKey = 'push_mentions';
  static const String pushFollowRequestsKey = 'push_follow_requests';
  static const String pushNewFollowersKey = 'push_new_followers';
  static const String pushAdminUpdatesKey = 'push_admin_updates';

  static const List<String> notificationKeys = [
    inAppChatMessagesKey,
    inAppOfferMessagesKey,
    inAppOfferUpdatesKey,
    inAppCommentsKey,
    inAppRepliesKey,
    inAppMentionsKey,
    inAppFollowRequestsKey,
    inAppNewFollowersKey,
    inAppAdminUpdatesKey,
    pushChatMessagesKey,
    pushOfferMessagesKey,
    pushOfferUpdatesKey,
    pushCommentsKey,
    pushRepliesKey,
    pushMentionsKey,
    pushFollowRequestsKey,
    pushNewFollowersKey,
    pushAdminUpdatesKey,
  ];

  static Map<String, bool> defaults() {
    return {
      videoAutoplayKey: false,
      for (final key in notificationKeys) key: true,
    };
  }

  static bool defaultForKey(String key) {
    if (key == videoAutoplayKey) return false;
    return true;
  }

  static AppSettings loadCurrentSettings() {
    final user = Supabase.instance.client.auth.currentUser;
    final metadata = user?.userMetadata;
    final rawSettings = metadata?[settingsKey];
    final settings = rawSettings is Map
        ? Map<String, dynamic>.from(rawSettings)
        : <String, dynamic>{};

    final values = defaults();
    for (final entry in settings.entries) {
      if (entry.value is bool) {
        values[entry.key] = entry.value as bool;
      }
    }
    return AppSettings(values);
  }

  static bool currentVideoAutoplayEnabled() {
    return loadCurrentSettings().videoAutoplayEnabled;
  }

  static bool currentSettingEnabled(String key) {
    return loadCurrentSettings().enabled(key);
  }

  static Future<AppSettings> setBool(String key, bool enabled) async {
    final auth = Supabase.instance.client.auth;
    final user = auth.currentUser;
    if (user == null) {
      throw Exception('Not logged in');
    }

    final metadata = Map<String, dynamic>.from(user.userMetadata ?? const {});
    final currentSettings = metadata[settingsKey];
    final settings = currentSettings is Map
        ? Map<String, dynamic>.from(currentSettings)
        : <String, dynamic>{};
    settings[key] = enabled;
    metadata[settingsKey] = settings;

    await auth.updateUser(UserAttributes(data: metadata));
    return loadCurrentSettings();
  }

  static Future<AppSettings> setVideoAutoplayEnabled(bool enabled) {
    return setBool(videoAutoplayKey, enabled);
  }
}
