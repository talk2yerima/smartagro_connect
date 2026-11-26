import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/di/auth_providers.dart';
import '../../core/errors/failures.dart';
import '../../core/errors/friendly_error.dart';
import '../../core/i18n/i18n.dart';
import '../../domain/entities/app_user.dart';
import '../../shared/widgets/farmland_illustration.dart';
import '../../shared/widgets/gradient_button.dart';

/// Full-screen sign-in: a brand header that runs under the status bar and a
/// single form sheet below it. It fits one phone screen without scrolling
/// and only scrolls when the keyboard needs the room.
///
/// In live mode a person's role comes from their account, so there is no
/// role picker. Demo mode (no Firebase) keeps a compact "demo account"
/// picker that fills in the matching demo email.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  UserRole _role = UserRole.farmer;
  bool _busy = false;
  bool _obscurePassword = true;
  String? _error;
  bool _isLiveMode = false;

  @override
  void initState() {
    super.initState();
    _isLiveMode = ref.read(authRepositoryProvider).isLiveMode;
    if (!_isLiveMode) {
      _email.text = 'farmer@demo.ng';
      _password.text = 'password123';
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = ref.read(authRepositoryProvider);
      final user = await repo.loginWithEmail(
        email: _email.text.trim(),
        password: _password.text,
        demoRole: _role,
      );
      ref.read(authSessionProvider.notifier).setUser(user);
      if (!mounted) return;
      context.go('/main/home');
    } on Failure catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _google() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = ref.read(authRepositoryProvider);
      final user = await repo.googleSignIn();
      ref.read(authSessionProvider.notifier).setUser(user);
      if (!mounted) return;
      context.go('/main/home');
    } on Failure catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _selectDemoRole(UserRole role) {
    setState(() {
      _role = role;
      _email.text = '${role.name}@demo.ng';
      _password.text = 'password123';
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final media = MediaQuery.of(context);

    // Light status-bar icons over the green header.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.bg(isDark),
        body: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                // Exactly one screen tall; grows only if content needs it
                // (large text, keyboard open).
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Header(topPadding: media.padding.top),
                      Expanded(
                        child: Center(
                          child: ConstrainedBox(
                            // Comfortable width on tablets.
                            constraints: const BoxConstraints(maxWidth: 460),
                            child: _FormSheet(
                              formKey: _formKey,
                              email: _email,
                              password: _password,
                              passwordFocus: _passwordFocus,
                              busy: _busy,
                              error: _error,
                              obscurePassword: _obscurePassword,
                              isDark: isDark,
                              showDemoPicker: !_isLiveMode,
                              demoRole: _role,
                              onDemoRole: _selectDemoRole,
                              onSubmit: _submit,
                              onGoogle: _google,
                              onTogglePassword: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─── Brand header ────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.topPadding});

  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.deepGreen, AppColors.emerald],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      // Drawn farm landscape behind the text (no image file needed).
      child: Stack(
        children: [
          const Positioned.fill(child: FarmlandIllustration()),
          Padding(
            padding: EdgeInsets.fromLTRB(24, topPadding + 28, 24, 92),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.eco_rounded,
                          color: AppColors.deepGreen, size: 26),
                    ),
                    const SizedBox(width: 12),
                    const T(
                      'SmartAgro Connect',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                const T(
                  'Welcome back',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    fontSize: 30,
                    height: 1.15,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                T(
                  'Sign in to sell, buy and move produce.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    height: 1.4,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Form sheet ──────────────────────────────────────────────────────────────

class _FormSheet extends StatelessWidget {
  const _FormSheet({
    required this.formKey,
    required this.email,
    required this.password,
    required this.passwordFocus,
    required this.busy,
    required this.error,
    required this.obscurePassword,
    required this.isDark,
    required this.showDemoPicker,
    required this.demoRole,
    required this.onDemoRole,
    required this.onSubmit,
    required this.onGoogle,
    required this.onTogglePassword,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController email;
  final TextEditingController password;
  final FocusNode passwordFocus;
  final bool busy;
  final String? error;
  final bool obscurePassword;
  final bool isDark;
  final bool showDemoPicker;
  final UserRole demoRole;
  final ValueChanged<UserRole> onDemoRole;
  final VoidCallback onSubmit;
  final VoidCallback onGoogle;
  final VoidCallback onTogglePassword;

  @override
  Widget build(BuildContext context) {
    final subText = AppColors.subText(isDark);

    // The sheet's rounded top overlaps the header, so the page reads as
    // one surface rather than two stacked cards.
    return Transform.translate(
      offset: const Offset(0, -24),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bg(isDark),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
        child: Form(
          key: formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showDemoPicker) ...[
                  _DemoRolePicker(selected: demoRole, onSelected: onDemoRole),
                  const SizedBox(height: 20),
                ],
                TextFormField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  onFieldSubmitted: (_) => passwordFocus.requestFocus(),
                  decoration: InputDecoration(
                    labelText: tr('Email'),
                    prefixIcon: const Icon(Icons.mail_outline_rounded),
                  ),
                  validator: (v) => v == null || !v.contains('@')
                      ? 'Enter a valid email'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: password,
                  focusNode: passwordFocus,
                  obscureText: obscurePassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onFieldSubmitted: (_) => onSubmit(),
                  decoration: InputDecoration(
                    labelText: tr('Password'),
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      tooltip:
                          obscurePassword ? 'Show password' : 'Hide password',
                      onPressed: onTogglePassword,
                      icon: Icon(obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                    ),
                  ),
                  validator: (v) =>
                      v == null || v.length < 6 ? 'Minimum 6 characters' : null,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.push('/forgot'),
                    child: const T('Forgot password?'),
                  ),
                ),
                if (error != null) ...[
                  _ErrorBanner(message: error!),
                  const SizedBox(height: 14),
                ],
                PrimaryGradientButton(
                  label: busy ? 'Signing in…' : 'Sign in',
                  icon: Icons.login_rounded,
                  onPressed: busy ? null : onSubmit,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(child: Divider(color: AppColors.border_(isDark))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: T('or', style: TextStyle(color: subText)),
                    ),
                    Expanded(child: Divider(color: AppColors.border_(isDark))),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : () => context.push('/phone'),
                    icon: const Icon(Icons.phone_iphone_rounded),
                    label: const T('Continue with phone number'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.text(isDark),
                      side: BorderSide(color: AppColors.border_(isDark)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : onGoogle,
                    icon: const Icon(Icons.g_mobiledata_rounded, size: 30),
                    label: const T('Continue with Google'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.text(isDark),
                      side: BorderSide(color: AppColors.border_(isDark)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                // Pushes "Create account" to the bottom of the screen.
                const Spacer(),
                Padding(
                  padding: EdgeInsets.only(
                    top: 16,
                    bottom: MediaQuery.of(context).padding.bottom + 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      T('New to SmartAgro?', style: TextStyle(color: subText)),
                      TextButton(
                        onPressed: () => context.push('/register'),
                        child: const T(
                          'Create account',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Demo mode only: picks which demo account to sign in with.
class _DemoRolePicker extends StatelessWidget {
  const _DemoRolePicker({required this.selected, required this.onSelected});

  final UserRole selected;
  final ValueChanged<UserRole> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        T('Demo account', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final role in UserRole.values)
              ChoiceChip(
                selected: role == selected,
                onSelected: (_) => onSelected(role),
                label: Text(switch (role) {
                  UserRole.farmer => 'Farmer',
                  UserRole.buyer => 'Buyer',
                  UserRole.transporter => 'Transporter',
                  UserRole.admin => 'Admin',
                }),
              ),
          ],
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.error;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: TextStyle(color: color))),
        ],
      ),
    );
  }
}
