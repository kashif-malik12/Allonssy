import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'brand_wordmark.dart';

class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBack;
  final List<Widget>? actions;

  const AppTopBar({
    super.key,
    this.title = 'Allonssy!',
    this.showBack = true,
    this.actions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  void _goHome(BuildContext context) {
    // Change this if your home route is "/" instead of "/feed"
    context.go('/feed');
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      leading: showBack && context.canPop()
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            )
          : null,
      title: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _goHome(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              title == 'Allonssy!'
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        BrandMark(size: 24),
                        SizedBox(width: 8),
                        BrandWordmark(
                          fontSize: 20,
                          color: Color(0xFF12211D),
                          accentColor: Color(0xFF0F766E),
                          letterSpacing: -0.5,
                          showIcon: false,
                        ),
                      ],
                    )
                  : Text(title),
              const SizedBox(width: 6),
              const Icon(Icons.home, size: 18),
            ],
          ),
        ),
      ),
      actions: actions,
    );
  }
}
