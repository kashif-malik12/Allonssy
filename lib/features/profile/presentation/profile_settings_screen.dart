import 'package:flutter/material.dart';

import '../../../services/app_settings_service.dart';
import '../../../widgets/global_app_bar.dart';
import '../../../widgets/global_bottom_nav.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  late bool _videoAutoplayEnabled;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _videoAutoplayEnabled = AppSettingsService.currentVideoAutoplayEnabled();
  }

  Future<void> _updateVideoAutoplay(bool enabled) async {
    setState(() {
      _videoAutoplayEnabled = enabled;
      _saving = true;
    });

    try {
      await AppSettingsService.setVideoAutoplayEnabled(enabled);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _videoAutoplayEnabled = !enabled;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save setting: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
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
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'App settings',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Control how videos behave across the app.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 18),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: _videoAutoplayEnabled,
                        onChanged: _saving ? null : _updateVideoAutoplay,
                        title: const Text('Video auto play'),
                        subtitle: Text(
                          _videoAutoplayEnabled
                              ? 'Videos start playing automatically.'
                              : 'Videos stay paused until you press play.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
