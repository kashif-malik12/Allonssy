import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../core/localization/app_localizations.dart';

/// Base web origin — same host the Flutter web app runs on.
const _webBase = 'https://app.allonssy.com';

/// Canonical share URLs for the shareable listing types and app.
String appShareUrl() => _webBase;
String marketplaceShareUrl(String postId) => '$_webBase/marketplace/product/$postId';
String gigShareUrl(String postId) => '$_webBase/gigs/service/$postId';
String foodShareUrl(String postId) => '$_webBase/foods/$postId';
String profileShareUrl(String profileId) => '$_webBase/p/$profileId';

/// Shares the Allonssy application with friends and community.
Future<void> shareApp(BuildContext context) async {
  final l10n = context.l10n;
  final title = l10n.tr('share_app_title');
  final message = l10n.tr('share_app_message', args: {'url': _webBase});
  final box = context.findRenderObject() as RenderBox?;
  final origin = box == null
      ? null
      : box.localToGlobal(Offset.zero) & box.size;

  if (kIsWeb) {
    try {
      await Share.share(message, subject: title);
    } catch (_) {
      await Clipboard.setData(const ClipboardData(text: _webBase));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.tr('link_copied')),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  } else {
    await Share.share(
      message,
      subject: title,
      sharePositionOrigin: origin,
    );
  }
}

/// A compact icon button that shares a listing URL.
///
/// On mobile (Android / iOS) it opens the native OS share sheet.
/// On web it tries the Web Share API (supported on mobile browsers and some
/// desktop browsers); if the browser does not support it, it falls back to
/// copying the link to the clipboard and shows a brief snackbar.
class ShareButton extends StatelessWidget {
  final String url;
  final String title;

  const ShareButton({
    super.key,
    required this.url,
    required this.title,
  });

  Future<void> _share(BuildContext context) async {
    if (kIsWeb) {
      await _shareWeb(context);
    } else {
      await _shareMobile(context);
    }
  }

  Future<void> _shareMobile(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    await Share.share(
      '$title\n$url',
      subject: title,
      sharePositionOrigin: box == null
          ? null
          : box.localToGlobal(Offset.zero) & box.size,
    );
  }

  Future<void> _shareWeb(BuildContext context) async {
    try {
      await Share.share('$title\n$url', subject: title);
    } catch (_) {
      // Web Share API not available (e.g. desktop Firefox/Safari) — copy link.
      await Clipboard.setData(ClipboardData(text: url));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Link copied to clipboard'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Share',
      icon: const Icon(Icons.share_outlined),
      onPressed: () => _share(context),
    );
  }
}

/// Bottom-sheet variant for placement inside a page body (not an app bar).
/// Shows a "Share" row card with the URL, a copy button, and native share.
class ShareSheet extends StatelessWidget {
  final String url;
  final String title;

  const ShareSheet({super.key, required this.url, required this.title});

  static Future<void> show(
    BuildContext context, {
    required String url,
    required String title,
  }) =>
      showModalBottomSheet(
        context: context,
        builder: (_) => ShareSheet(url: url, title: title),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Share listing',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      url,
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    tooltip: 'Copy link',
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: url));
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Link copied')),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.share_outlined),
                label: const Text('Share via…'),
                onPressed: () async {
                  Navigator.pop(context);
                  await Share.share('$title\n$url', subject: title);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
