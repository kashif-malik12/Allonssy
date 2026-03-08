import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app/chat_singletons.dart';

class GlobalAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  // existing features
  final Widget? notifBell;
  final bool showBackIfPossible;
  final String homeRoute;
  final Future<void> Function()? onBeforeLogout;

  // ✅ optional extra actions (e.g., Report user)
  final List<Widget>? actions;

  // ✅ routes for icons (override if needed)
  final String searchRoute;
  final String chatsRoute;
  final String myProfileRoute;
  final String notificationsRoute;

  const GlobalAppBar({
    super.key,
    required this.title,
    this.notifBell,
    this.showBackIfPossible = false,
    this.homeRoute = '/feed',
    this.onBeforeLogout,
    this.actions,

    // defaults — change if your app uses different ones
    this.searchRoute = '/search',
    this.chatsRoute = '/chats',
    this.myProfileRoute = '/profile',
    this.notificationsRoute = '/notifications',
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  Future<void> _logout(BuildContext context) async {
    try {
      if (onBeforeLogout != null) {
        await onBeforeLogout!();
      }
      await Supabase.instance.client.auth.signOut();
      if (context.mounted) context.go('/login');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPop = GoRouter.of(context).canPop();
    final showBack = showBackIfPossible && canPop;
    final theme = Theme.of(context);

    return AppBar(
      scrolledUnderElevation: 0,
      leading: showBack
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            )
          : null,
      title: InkWell(
        onTap: () => context.go(homeRoute),
        child: Text(title),
      ),
      actions: [
        // ✅ extra actions first (like report user ⋮)
        ...?actions,

        _actionIcon(
          context: context,
          tooltip: 'Home',
          icon: const Icon(Icons.home_outlined),
          onPressed: () => context.go(homeRoute),
        ),

        _actionIcon(
          context: context,
          tooltip: 'Search',
          icon: const Icon(Icons.search),
          onPressed: () => context.push(searchRoute),
        ),

        ValueListenableBuilder<int>(
          valueListenable: unreadBadgeController.unread,
          builder: (_, unread, __) {
            return _actionIcon(
              context: context,
              tooltip: 'Messages',
              onPressed: () {
                unreadBadgeController.refresh();
                context.push(chatsRoute);
              },
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.chat_bubble_outline),
                  if (unread > 0)
                    Positioned(
                      right: -7,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        constraints: const BoxConstraints(minWidth: 18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD92D20),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: theme.colorScheme.surface, width: 1.4),
                        ),
                        child: Text(
                          unread > 99 ? '99+' : '$unread',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),

        if (notifBell != null)
          notifBell!
        else
          _actionIcon(
            context: context,
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push(notificationsRoute),
          ),

        PopupMenuButton<String>(
          tooltip: 'More',
          onSelected: (value) {
            if (value == 'profile') {
              context.push(myProfileRoute);
            } else if (value == 'logout') {
              _logout(context);
            } else if (value == 'home') {
              context.go(homeRoute);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem<String>(
              value: 'home',
              child: Text('Home'),
            ),
            PopupMenuItem<String>(
              value: 'profile',
              child: Text('My profile'),
            ),
            PopupMenuItem<String>(
              value: 'logout',
              child: Text('Logout'),
            ),
          ],
          child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Material(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.7),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.more_horiz_rounded),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _actionIcon({
    required BuildContext context,
    required String tooltip,
    required Widget icon,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: IconButton(
          tooltip: tooltip,
          visualDensity: VisualDensity.compact,
          onPressed: onPressed,
          icon: icon,
        ),
      ),
    );
  }
}
