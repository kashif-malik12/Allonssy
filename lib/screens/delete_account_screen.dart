import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class DeleteAccountScreen extends StatelessWidget {
  const DeleteAccountScreen({super.key});

  Future<void> _openDeletionEmail() async {
    final currentEmail = Supabase.instance.client.auth.currentUser?.email ?? '';
    final body = Uri.encodeComponent(
      'Hello Allonssy,\n\n'
      'I would like to request deletion of my Allonssy account.\n'
      'Account email: $currentEmail\n\n'
      'Please confirm the next steps.\n',
    );
    final uri = Uri.parse(
      'mailto:hello@allonssy.com'
      '?subject=Allonssy%20account%20deletion%20request'
      '&body=$body',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final canPop = GoRouter.of(context).canPop();
    final theme = Theme.of(context);

    Widget sectionTitle(String text) => Padding(
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
                'Contact',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              SizedBox(height: 6),
              Text('Tradister SAS', style: TextStyle(fontWeight: FontWeight.w600)),
              Text('SIREN: 988 318 945'),
              Text('Ris-Orangis, France'),
              SizedBox(height: 6),
              Text('Email: hello@allonssy.com'),
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
        title: const Text('Suppression du compte / Delete Account'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
            children: [
              Text(
                'Suppression du compte',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              body(
                'Pour demander la suppression de votre compte Allonssy et des donnees associees, '
                'envoyez une demande a hello@allonssy.com depuis l adresse e-mail liee a votre compte '
                'ou utilisez le bouton ci-dessous.',
              ),
              body(
                'Merci d inclure votre adresse e-mail de compte et toute information utile pour verifier '
                'votre identite. Nous traiterons les demandes valides dans un delai maximal de 30 jours, '
                'sauf obligation legale de conservation.',
              ),
              bullet('Adresse de contact : hello@allonssy.com'),
              bullet('Objet conseille : Demande de suppression de compte Allonssy'),
              bullet('Delai cible de traitement : 30 jours maximum'),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _openDeletionEmail,
                icon: const Icon(Icons.mail_outline),
                label: const Text('Envoyer une demande par e-mail'),
              ),
              const SizedBox(height: 36),
              const Divider(),
              sectionTitle('Delete account'),
              body(
                'To request deletion of your Allonssy account and associated personal data, '
                'email hello@allonssy.com from the email address linked to your account or use the button below.',
              ),
              body(
                'Please include your account email and any useful details needed to verify your identity. '
                'We process valid requests within 30 days, unless longer retention is required by law.',
              ),
              bullet('Contact address: hello@allonssy.com'),
              bullet('Suggested subject: Allonssy account deletion request'),
              bullet('Target processing time: within 30 days'),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _openDeletionEmail,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Send deletion request by email'),
              ),
              contactBox(),
            ],
          ),
        ),
      ),
    );
  }
}
