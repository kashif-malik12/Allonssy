import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();

  bool _loading = false;
  bool _success = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    setState(() {
      _loading = true;
      _error = null;
      _success = false;
    });

    try {
      final res = await Supabase.instance.client.auth.signUp(
        email: _email.text.trim(),
        password: _password.text,
      );

      if (res.user == null) throw 'Sign up failed';

      final identities = res.user!.identities ?? const [];
      final looksLikeExistingUser = res.session == null &&
          identities.isEmpty &&
          (res.user!.email?.trim().toLowerCase() == _email.text.trim().toLowerCase());

      if (looksLikeExistingUser) {
        throw 'An account with this email already exists. Please log in instead.';
      }

      // If email verification is enabled, session might be null
      if (res.session == null) {
        if (mounted) {
          setState(() {
            _success = true;
            _loading = false;
          });
        }
      } else {
        if (mounted) context.go('/home');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted && !_success) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF5F1E8), Color(0xFFF0EEE7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;

              final brandPanel = Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFCC7A00), Color(0xFF8B5A12)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.groups_2_outlined,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Join Local Feed',
                      style: TextStyle(
                        fontSize: 40,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -1.1,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Create your account and start discovering nearby posts, local offers, food ads, and trusted community updates.',
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _brandChip('Create profile'),
                        _brandChip('Share locally'),
                        _brandChip('Find nearby deals'),
                        _brandChip('Chat safely'),
                      ],
                    ),
                  ],
                ),
              );

              final registerCard = Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: const Color(0xFFE6DDCE)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 24,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: _success
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.mark_email_read_outlined,
                                color: Color(0xFFCC7A00),
                                size: 64,
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Check your email',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'We have sent a verification link to ${_email.text}. Please click the link to confirm your account.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 32),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: () => context.go('/login'),
                                  child: const Text('Return to login'),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Create account',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Start your local profile in a few seconds.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 22),
                              TextField(
                                controller: _email,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                onSubmitted: (_) => _passwordFocus.requestFocus(),
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  prefixIcon: Icon(Icons.mail_outline),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _password,
                                focusNode: _passwordFocus,
                                obscureText: true,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) {
                                  if (!_loading) _register();
                                },
                                decoration: const InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: Icon(Icons.lock_outline),
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (_error != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Text(
                                    _error!,
                                    style: const TextStyle(color: Color(0xFFD92D20)),
                                  ),
                                ),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: _loading ? null : _register,
                                  child: Text(_loading ? 'Creating...' : 'Create account'),
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: () => context.go('/login'),
                                  child: const Text('Back to login'),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              );

              if (isWide) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 6,
                        child: brandPanel,
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 5,
                        child: registerCard,
                      ),
                    ],
                  ),
                );
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: brandPanel,
                    ),
                    const SizedBox(height: 16),
                    registerCard,
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _brandChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.16)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
