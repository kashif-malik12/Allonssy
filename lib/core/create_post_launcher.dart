import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

Future<dynamic> openCreatePostFlow(BuildContext context) async {
  final isPhone = !kIsWeb && MediaQuery.of(context).size.width < 700;
  if (!isPhone) {
    return context.push('/create-post');
  }

  final initialAction = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Create post',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _CreatePostActionTile(
                      icon: Icons.camera_alt_outlined,
                      title: 'Camera',
                      subtitle: 'Quick photo or 10s video',
                      onTap: () => Navigator.of(sheetContext).pop('camera'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _CreatePostActionTile(
                      icon: Icons.edit_outlined,
                      title: 'Post',
                      subtitle: 'Open full composer',
                      onTap: () => Navigator.of(sheetContext).pop('post'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );

  if (!context.mounted || initialAction == null) return null;
  if (initialAction == 'post') {
    return context.push('/create-post');
  }

  final captureMode = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Quick camera',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _CreatePostActionTile(
                      icon: Icons.photo_camera_outlined,
                      title: 'Photo',
                      subtitle: 'Take and post now',
                      onTap: () => Navigator.of(sheetContext).pop('photo'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _CreatePostActionTile(
                      icon: Icons.videocam_outlined,
                      title: '10s Video',
                      subtitle: 'Record and post now',
                      onTap: () => Navigator.of(sheetContext).pop('video'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );

  if (!context.mounted || captureMode == null) return null;
  return context.push('/quick-camera-post/$captureMode');
}

class _CreatePostActionTile extends StatelessWidget {
  const _CreatePostActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F0E4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFD8C8AF)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 30, color: const Color(0xFF0F766E)),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
