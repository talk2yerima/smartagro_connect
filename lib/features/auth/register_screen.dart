import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_env.dart';
import '../../core/constants/app_colors.dart';
import '../../core/di/auth_providers.dart';
import '../../core/errors/failures.dart';
import '../../core/errors/friendly_error.dart';
import '../../core/i18n/i18n.dart';
import '../../domain/entities/app_user.dart';
import '../../shared/widgets/gradient_button.dart';
import 'widgets/role_card.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  UserRole _role = UserRole.farmer;
  bool _busy = false;
  bool _hidePassword = true;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = ref.read(authRepositoryProvider);
      final user = await repo.registerWithEmail(
        name: _name.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
        role: _role,
      );
      ref.read(authSessionProvider.notifier).setUser(user);
      if (!mounted) return;
      // No fake code step: phone numbers are verified by real SMS in
      // the phone sign-in flow.
      context.go('/main/home');
    } on Failure catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = Theme.of(context).textTheme;
    final errorColor = Theme.of(context).colorScheme.error;
    return Scaffold(
      appBar: AppBar(title: const T('Create account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                T('Join SmartAgro', style: text.headlineSmall),
                const SizedBox(height: 4),
                T(
                  'Pick how you will use the app. You can sell, buy or '
                  'transport produce.',
                  style: text.bodyMedium
                      ?.copyWith(color: AppColors.subText(isDark)),
                ),
                const SizedBox(height: 20),
                T('I am a', style: text.labelLarge),
                const SizedBox(height: 8),
                // Big tappable cards instead of a dropdown: easier for
                // first-time users. Admin is never self-selected (the
                // Firestore rules enforce this too).
                for (final role in const [
                  UserRole.farmer,
                  UserRole.buyer,
                  UserRole.transporter,
                ]) ...[
                  RoleCard(
                    role: role,
                    selected: _role == role,
                    isDark: isDark,
                    onTap: () => setState(() => _role = role),
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  decoration: InputDecoration(
                    labelText: tr('Full name'),
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                  ),
                  validator: (v) => v == null || v.trim().length < 2
                      ? 'Enter your name'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  decoration: InputDecoration(
                    labelText: tr('Email'),
                    prefixIcon: const Icon(Icons.mail_outline_rounded),
                  ),
                  validator: (v) => v == null || !v.contains('@')
                      ? 'Enter a valid email'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  obscureText: _hidePassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  onFieldSubmitted: (_) {
                    if (!_busy) _submit();
                  },
                  decoration: InputDecoration(
                    labelText: tr('Password'),
                    helperText: tr('At least 6 characters'),
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      tooltip:
                          _hidePassword ? 'Show password' : 'Hide password',
                      icon: Icon(_hidePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () =>
                          setState(() => _hidePassword = !_hidePassword),
                    ),
                  ),
                  validator: (v) =>
                      v == null || v.length < 6 ? 'Minimum 6 characters' : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: errorColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline_rounded, color: errorColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_error!,
                              style: TextStyle(color: errorColor)),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                PrimaryGradientButton(
                  label: _busy ? 'Creating account…' : 'Create account',
                  onPressed: _busy ? null : _submit,
                ),
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    T('By creating an account, you agree to our ',
                        style: text.bodySmall
                            ?.copyWith(color: AppColors.subText(isDark))),
                    _LinkText('Terms of Use', AppEnv.termsUrl),
                    T(' and ',
                        style: text.bodySmall
                            ?.copyWith(color: AppColors.subText(isDark))),
                    _LinkText('Privacy Policy', AppEnv.privacyPolicyUrl),
                    T('.',
                        style: text.bodySmall
                            ?.copyWith(color: AppColors.subText(isDark))),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const T('Already have an account?'),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: const T('Sign in'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A small underlined link that opens a public page in the browser.
class _LinkText extends StatelessWidget {
  const _LinkText(this.label, this.url);

  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).brightness == Brightness.dark
        ? AppColors.lightGreen
        : AppColors.deepGreen;
    return Semantics(
      link: true,
      child: InkWell(
        onTap: () =>
            launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                  decorationColor: color,
                ),
          ),
        ),
      ),
    );
  }
}
