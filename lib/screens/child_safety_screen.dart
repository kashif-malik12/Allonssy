import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ChildSafetyScreen extends StatelessWidget {
  const ChildSafetyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final canPop = GoRouter.of(context).canPop();
    final theme = Theme.of(context);

    Widget h1(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            text,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        );

    Widget h2(String text) => Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 8),
          child: Text(
            text,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        );

    Widget body(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(text, style: const TextStyle(height: 1.6)),
        );

    Widget bullet(String text) => Padding(
          padding: const EdgeInsets.only(left: 12, bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 7),
                child: SizedBox(
                  width: 6,
                  height: 6,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0xFF147A74),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(text, style: const TextStyle(height: 1.6))),
            ],
          ),
        );

    Widget contactBox() => Container(
          margin: const EdgeInsets.only(top: 24),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF147A74).withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF147A74).withValues(alpha: 0.18),
            ),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Child safety contact',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              SizedBox(height: 6),
              Text('Tradister SAS', style: TextStyle(fontWeight: FontWeight.w600)),
              Text('Email: kashif@tradister.com'),
              Text('General support: hello@allonssy.com'),
            ],
          ),
        );

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        leading: canPop
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              )
            : null,
        title: const Text('Child Safety Standards'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
            children: [
              h1('Allonssy child safety standards'),
              body(
                'Allonssy prohibits child sexual abuse and exploitation (CSAE), child sexual abuse material (CSAM), grooming, sexual extortion, trafficking, and any content or behaviour that endangers minors.',
              ),
              body(
                'We do not allow users to use Allonssy to create, store, share, request, promote, or distribute content involving the sexual exploitation of children. Accounts or content that violate these standards may be removed immediately and reported where required by law.',
              ),
              h2('Our standards'),
              bullet('No CSAM, exploitative imagery, or sexualised content involving minors.'),
              bullet('No grooming, coercion, sextortion, trafficking, or predatory behaviour toward minors.'),
              bullet('No attempts to use private messaging, posts, listings, or profiles to exploit children.'),
              bullet('No evasion, reposting, or re-uploading of banned exploitative content.'),
              h2('Reporting and enforcement'),
              body(
                'Allonssy allows users to report posts and user profiles in-app. Reported content can be reviewed by moderators and administrators, and we may suspend accounts, remove content, block access, and preserve evidence when needed for safety and legal compliance.',
              ),
              bullet('In-app reporting is available for posts and user profiles.'),
              bullet('Moderation tools allow review, removal, and account action.'),
              bullet('We may escalate credible child-safety incidents to relevant authorities.'),
              h2('Contact'),
              body(
                'For child safety, CSAE, or CSAM concerns related to Allonssy, contact us at kashif@tradister.com. This contact point is designated for safety and compliance matters.',
              ),
              contactBox(),
            ],
          ),
        ),
      ),
    );
  }
}
