import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/router.dart' show appRouterNavigatorKey;
import '../core/config/app_version.dart';

class AppUpdateInfo {
  final String latestVersion;
  final int latestBuild;
  final int minBuild;
  final String storeUrl;
  final String notesFr;
  final String notesEn;

  const AppUpdateInfo({
    required this.latestVersion,
    required this.latestBuild,
    required this.minBuild,
    required this.storeUrl,
    required this.notesFr,
    required this.notesEn,
  });

  bool get hasUpdate => AppVersion.buildNumber < latestBuild;
  bool get isForced => AppVersion.buildNumber < minBuild;
}

class AppUpdateService {
  AppUpdateService._();
  static final AppUpdateService instance = AppUpdateService._();

  static const Duration _checkCooldown = Duration(minutes: 30);
  static const Duration _dismissCooldown = Duration(hours: 24);
  static const String _dismissKeyPrefix = 'allonssy_update_dismissed_build_';

  DateTime? _lastCheckedAt;
  bool _checking = false;
  bool _dialogShowing = false;

  String get _platformKey {
    if (kIsWeb) return 'web';
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
    return 'android';
  }

  /// Checks `https://app.allonssy.com/app_version.json` and shows a sleek
  /// update dialog if a newer build is available for the current platform.
  Future<void> checkForUpdate({bool forceCheck = false}) async {
    if (_checking || _dialogShowing) return;

    final now = DateTime.now();
    if (!forceCheck &&
        _lastCheckedAt != null &&
        now.difference(_lastCheckedAt!) < _checkCooldown) {
      return;
    }

    _checking = true;
    _lastCheckedAt = now;

    try {
      final info = await _fetchUpdateInfo();
      if (info == null || !info.hasUpdate) return;

      if (!info.isForced && !forceCheck) {
        final dismissedRecently = await _wasDismissedRecently(info.latestBuild);
        if (dismissedRecently) return;
      }

      // Wait briefly if navigator context is still mounting on cold start.
      BuildContext? ctx = appRouterNavigatorKey.currentContext;
      if (ctx == null) {
        await Future<void>.delayed(const Duration(milliseconds: 600));
        ctx = appRouterNavigatorKey.currentContext;
      }
      if (ctx == null || !ctx.mounted) return;

      await _showUpdateDialog(ctx, info);
    } catch (_) {
      // Never block or crash the app when offline or unreachable.
    } finally {
      _checking = false;
    }
  }

  Future<AppUpdateInfo?> _fetchUpdateInfo() async {
    final uri = Uri.parse(
      '${AppVersion.updateManifestUrl}?t=${DateTime.now().millisecondsSinceEpoch}',
    );
    final res = await http.get(uri).timeout(const Duration(seconds: 6));
    if (res.statusCode != 200) return null;

    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    if (decoded is! Map<String, dynamic>) return null;

    final section = decoded[_platformKey];
    if (section is! Map<String, dynamic>) return null;

    final latestBuild = (section['latest_build'] as num?)?.toInt() ?? 0;
    final minBuild = (section['min_build'] as num?)?.toInt() ?? 0;
    final latestVersion = (section['latest_version'] ?? '').toString().trim();
    final storeUrl = (section['store_url'] ?? AppVersion.playStoreUrl)
        .toString()
        .trim();
    final notesFr = (section['notes_fr'] ?? '').toString().trim();
    final notesEn = (section['notes_en'] ?? '').toString().trim();

    if (latestBuild <= 0) return null;

    return AppUpdateInfo(
      latestVersion: latestVersion.isEmpty ? '1.3.2' : latestVersion,
      latestBuild: latestBuild,
      minBuild: minBuild,
      storeUrl: storeUrl.isEmpty ? AppVersion.playStoreUrl : storeUrl,
      notesFr: notesFr,
      notesEn: notesEn,
    );
  }

  Future<bool> _wasDismissedRecently(int build) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tsMs = prefs.getInt('$_dismissKeyPrefix$build');
      if (tsMs == null) return false;
      final dismissedAt = DateTime.fromMillisecondsSinceEpoch(tsMs);
      return DateTime.now().difference(dismissedAt) < _dismissCooldown;
    } catch (_) {
      return false;
    }
  }

  Future<void> _markDismissed(int build) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        '$_dismissKeyPrefix$build',
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      // ignore storage errors
    }
  }

  Future<void> _performUpdate(AppUpdateInfo info) async {
    if (kIsWeb) {
      // Cache-busting same-tab reload so the browser loads the new Flutter Web bundle.
      final target = Uri.base.replace(
        queryParameters: {
          ...Uri.base.queryParameters,
          'v': info.latestBuild.toString(),
        },
      );
      await launchUrl(target, webOnlyWindowName: '_self');
      return;
    }

    final uri = Uri.tryParse(info.storeUrl) ?? Uri.parse(AppVersion.playStoreUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _showUpdateDialog(BuildContext context, AppUpdateInfo info) async {
    if (_dialogShowing) return;
    _dialogShowing = true;

    final isFr = (Localizations.maybeLocaleOf(context)?.languageCode ?? 'fr')
        .toLowerCase()
        .startsWith('fr');

    final title = isFr
        ? 'Nouvelle mise à jour disponible'
        : 'New update available';
    final defaultBody = isFr
        ? (kIsWeb
            ? 'Une version plus récente d’Allonssy est prête. Rechargez la page pour profiter des dernières améliorations.'
            : 'Une nouvelle version d’Allonssy est disponible sur le store avec les dernières améliorations et correctifs.')
        : (kIsWeb
            ? 'A newer version of Allonssy is ready. Reload the page to get the latest improvements.'
            : 'A new version of Allonssy is available on the store with the latest improvements and fixes.');

    final releaseNotes = isFr
        ? (info.notesFr.isNotEmpty ? info.notesFr : defaultBody)
        : (info.notesEn.isNotEmpty ? info.notesEn : defaultBody);

    final updateBtnLabel = isFr
        ? (kIsWeb ? 'Actualiser maintenant' : 'Mettre à jour')
        : (kIsWeb ? 'Refresh now' : 'Update now');
    final laterBtnLabel = isFr ? 'Plus tard' : 'Later';

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: !info.isForced,
        builder: (dialogCtx) {
          return PopScope(
            canPop: !info.isForced,
            child: AlertDialog(
              backgroundColor: const Color(0xFFFFFCF7),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 8),
              contentPadding: const EdgeInsets.fromLTRB(22, 6, 22, 16),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              title: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F766E).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.system_update_rounded,
                      color: Color(0xFF0F766E),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF12211D),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(
                              color: const Color(0xFFA7F3D0),
                            ),
                          ),
                          child: Text(
                            'v${info.latestVersion} (build ${info.latestBuild})',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF065F46),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: Text(
                releaseNotes,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: Color(0xFF374151),
                ),
              ),
              actions: [
                if (!info.isForced)
                  TextButton(
                    onPressed: () async {
                      await _markDismissed(info.latestBuild);
                      if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                    },
                    child: Text(
                      laterBtnLabel,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 11,
                    ),
                  ),
                  onPressed: () async {
                    await _performUpdate(info);
                    if (!info.isForced && dialogCtx.mounted) {
                      Navigator.of(dialogCtx).pop();
                    }
                  },
                  icon: Icon(
                    kIsWeb ? Icons.refresh_rounded : Icons.download_rounded,
                    size: 18,
                  ),
                  label: Text(
                    updateBtnLabel,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          );
        },
      );
    } finally {
      _dialogShowing = false;
    }
  }
}
