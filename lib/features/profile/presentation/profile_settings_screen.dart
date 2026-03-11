import 'package:flutter/material.dart';

import '../../../services/app_settings_service.dart';
import '../../../widgets/global_app_bar.dart';
import '../../../widgets/global_bottom_nav.dart';

class _SettingItem {
  const _SettingItem({
    required this.keyName,
    required this.title,
    required this.subtitle,
  });

  final String keyName;
  final String title;
  final String subtitle;
}

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  static const List<_SettingItem> _inAppItems = [
    _SettingItem(
      keyName: AppSettingsService.inAppChatMessagesKey,
      title: 'Chat messages',
      subtitle: 'Show live in-app alerts for direct chat messages.',
    ),
    _SettingItem(
      keyName: AppSettingsService.inAppOfferMessagesKey,
      title: 'Offer messages',
      subtitle: 'Show notifications for listing conversation messages.',
    ),
    _SettingItem(
      keyName: AppSettingsService.inAppOfferUpdatesKey,
      title: 'Offer updates',
      subtitle: 'Show sent, accepted, and rejected offer updates.',
    ),
    _SettingItem(
      keyName: AppSettingsService.inAppCommentsKey,
      title: 'Comments on my posts',
      subtitle: 'Notify you when someone comments on your content.',
    ),
    _SettingItem(
      keyName: AppSettingsService.inAppRepliesKey,
      title: 'Replies to my comments',
      subtitle: 'Notify you when someone replies to your comment or question.',
    ),
    _SettingItem(
      keyName: AppSettingsService.inAppMentionsKey,
      title: 'Mentions',
      subtitle: 'Notify you when someone tags you in a post or comment.',
    ),
    _SettingItem(
      keyName: AppSettingsService.inAppFollowRequestsKey,
      title: 'Follow requests',
      subtitle: 'Notify you when someone requests to follow you.',
    ),
    _SettingItem(
      keyName: AppSettingsService.inAppNewFollowersKey,
      title: 'New followers',
      subtitle: 'Notify you when someone follows you or accepts your request.',
    ),
    _SettingItem(
      keyName: AppSettingsService.inAppAdminUpdatesKey,
      title: 'Admin and safety updates',
      subtitle: 'Show account, moderation, and safety-related updates.',
    ),
  ];

  static const List<_SettingItem> _pushItems = [
    _SettingItem(
      keyName: AppSettingsService.pushChatMessagesKey,
      title: 'Push chat messages',
      subtitle: 'Reserved for future mobile and web push support.',
    ),
    _SettingItem(
      keyName: AppSettingsService.pushOfferMessagesKey,
      title: 'Push offer messages',
      subtitle: 'Reserved for future push notifications on offer chats.',
    ),
    _SettingItem(
      keyName: AppSettingsService.pushOfferUpdatesKey,
      title: 'Push offer updates',
      subtitle: 'Reserved for offer sent, accepted, and rejected pushes.',
    ),
    _SettingItem(
      keyName: AppSettingsService.pushCommentsKey,
      title: 'Push comments',
      subtitle: 'Reserved for future push notifications on comments.',
    ),
    _SettingItem(
      keyName: AppSettingsService.pushRepliesKey,
      title: 'Push replies',
      subtitle: 'Reserved for future push notifications on replies.',
    ),
    _SettingItem(
      keyName: AppSettingsService.pushMentionsKey,
      title: 'Push mentions',
      subtitle: 'Reserved for future push notifications on mentions.',
    ),
    _SettingItem(
      keyName: AppSettingsService.pushFollowRequestsKey,
      title: 'Push follow requests',
      subtitle: 'Reserved for future push notifications on follow requests.',
    ),
    _SettingItem(
      keyName: AppSettingsService.pushNewFollowersKey,
      title: 'Push new followers',
      subtitle: 'Reserved for future push notifications on follows.',
    ),
    _SettingItem(
      keyName: AppSettingsService.pushAdminUpdatesKey,
      title: 'Push admin and safety updates',
      subtitle: 'Reserved for important admin and safety pushes.',
    ),
  ];

  late AppSettings _settings;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _settings = AppSettingsService.loadCurrentSettings();
  }

  Future<void> _updateSetting(String key, bool enabled) async {
    final previous = _settings;
    setState(() {
      _settings = _settings.copyWithValue(key, enabled);
      _saving = true;
    });

    try {
      final updated = await AppSettingsService.setBool(key, enabled);
      if (!mounted) return;
      setState(() => _settings = updated);
    } catch (e) {
      if (!mounted) return;
      setState(() => _settings = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save setting: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Widget _buildSettingsCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required List<_SettingItem> items,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            for (final item in items)
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _settings.enabled(item.keyName),
                onChanged: _saving ? null : (value) => _updateSetting(item.keyName, value),
                title: Text(item.title),
                subtitle: Text(item.subtitle),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GlobalAppBar(
        title: 'Profile settings',
        showBackIfPossible: true,
        homeRoute: '/profile',
      ),
      bottomNavigationBar: const GlobalBottomNav(),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSettingsCard(
                context: context,
                title: 'Playback',
                subtitle: 'Control how videos behave across the app.',
                items: [
                  const _SettingItem(
                    keyName: AppSettingsService.videoAutoplayKey,
                    title: 'Video auto play',
                    subtitle: 'Videos start playing automatically when enabled.',
                  ),
                ],
              ),
              _buildSettingsCard(
                context: context,
                title: 'In-app notifications',
                subtitle: 'Choose which updates should appear inside the app.',
                items: _inAppItems,
              ),
              _buildSettingsCard(
                context: context,
                title: 'Push notifications',
                subtitle: 'Saved now for future mobile and web push support.',
                items: _pushItems,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
