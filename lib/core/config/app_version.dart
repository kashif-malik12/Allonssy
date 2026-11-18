/// Single source of truth for the running app version & build number.
/// Keep in sync with `version:` in `pubspec.yaml` whenever cutting a release.
class AppVersion {
  static const String version = '1.3.2';
  static const int buildNumber = 10;

  static const String updateManifestUrl =
      'https://app.allonssy.com/app_version.json';
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.allonssy.app';
  static const String webAppUrl = 'https://app.allonssy.com/';
}
