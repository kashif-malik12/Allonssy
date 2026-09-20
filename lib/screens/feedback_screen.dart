import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/localization/app_localizations.dart';
import '../services/feedback_service.dart';
import '../widgets/global_app_bar.dart';
import '../widgets/global_bottom_nav.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  /// Opens the feedback form as a modal bottom sheet.
  static Future<void> showSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const _FeedbackModalContent(),
    );
  }

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: GlobalAppBar(
        title: l10n.tr('give_feedback'),
        showBackIfPossible: true,
        homeRoute: '/feed',
      ),
      bottomNavigationBar: const GlobalBottomNav(),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: const FeedbackForm(),
          ),
        ),
      ),
    );
  }
}

class _FeedbackModalContent extends StatelessWidget {
  const _FeedbackModalContent();

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: const FeedbackForm(isModal: true),
        ),
      ),
    );
  }
}

class FeedbackForm extends StatefulWidget {
  final bool isModal;
  const FeedbackForm({super.key, this.isModal = false});

  @override
  State<FeedbackForm> createState() => _FeedbackFormState();
}

class _FeedbackFormState extends State<FeedbackForm> {
  final _feedbackService = FeedbackService();
  final _messageCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  String _category = 'general';
  int _rating = 5;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _messageCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final message = _messageCtrl.text.trim();
    if (message.isEmpty) {
      setState(() => _error = l10n.tr('feedback_message_empty'));
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await _feedbackService.submitFeedback(
        category: _category,
        message: message,
        rating: _rating,
        contactEmail: _emailCtrl.text.trim().isNotEmpty ? _emailCtrl.text.trim() : null,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(l10n.tr('feedback_submitted_success'))),
            ],
          ),
          backgroundColor: const Color(0xFF0F766E),
          behavior: SnackBarBehavior.floating,
        ),
      );

      if (widget.isModal) {
        Navigator.of(context).pop();
      } else if (context.canPop()) {
        context.pop();
      } else {
        context.go('/feed');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.rate_review_outlined,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.tr('give_feedback'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  Text(
                    l10n.tr('feedback_subtitle'),
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Category selection
        Text(
          l10n.tr('feedback_type'),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              avatar: const Icon(Icons.chat_bubble_outline, size: 16),
              label: Text(l10n.tr('feedback_general')),
              selected: _category == 'general',
              onSelected: (selected) {
                if (selected) setState(() => _category = 'general');
              },
            ),
            ChoiceChip(
              avatar: const Icon(Icons.bug_report_outlined, size: 16),
              label: Text(l10n.tr('feedback_bug')),
              selected: _category == 'bug',
              onSelected: (selected) {
                if (selected) setState(() => _category = 'bug');
              },
            ),
            ChoiceChip(
              avatar: const Icon(Icons.lightbulb_outline, size: 16),
              label: Text(l10n.tr('feedback_feature')),
              selected: _category == 'feature',
              onSelected: (selected) {
                if (selected) setState(() => _category = 'feature');
              },
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Rating
        Text(
          l10n.tr('feedback_rating'),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (index) {
            final star = index + 1;
            return IconButton(
              iconSize: 32,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              constraints: const BoxConstraints(),
              icon: Icon(
                star <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                color: star <= _rating ? Colors.amber[700] : Colors.grey,
              ),
              onPressed: () => setState(() => _rating = star),
            );
          }),
        ),
        const SizedBox(height: 18),

        // Message input
        Text(
          l10n.tr('feedback'),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _messageCtrl,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: l10n.tr('feedback_message_hint'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
        ),
        const SizedBox(height: 14),

        // Optional email
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: l10n.tr('email_optional'),
            hintText: 'name@example.com',
            prefixIcon: const Icon(Icons.email_outlined, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),

        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: const TextStyle(color: Colors.red, fontSize: 13),
          ),
        ],

        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _submitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : Text(
                    l10n.tr('submit'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ],
    );
  }
}
