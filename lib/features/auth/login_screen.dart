import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/di/auth_providers.dart';
import '../../core/errors/failures.dart';
import '../../domain/entities/app_user.dart';
import '../../shared/widgets/gradient_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
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
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _google() async {
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
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _selectRole(UserRole role) {
    setState(() {
      _role = role;
      if (!_isLiveMode) {
        _email.text = '${role.name}@demo.ng';
        _password.text = 'password123';
      }
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : const Color(0xFFF3F6F1),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 760;
            final brand = _BrandPanel(selectedRole: _role);
            final login = _LoginPanel(
              formKey: _formKey,
              email: _email,
              password: _password,
              role: _role,
              busy: _busy,
              error: _error,
              obscurePassword: _obscurePassword,
              isLiveMode: _isLiveMode,
              onRoleSelected: _selectRole,
              onSubmit: _submit,
              onGoogle: _google,
              onTogglePassword: () {
                setState(() => _obscurePassword = !_obscurePassword);
              },
            );

            return SingleChildScrollView(
              padding: EdgeInsets.all(wide ? 24 : 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - (wide ? 48 : 32),
                ),
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 5, child: brand),
                          const SizedBox(width: 20),
                          Expanded(flex: 4, child: login),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          brand,
                          const SizedBox(height: 16),
                          login,
                        ],
                      ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel({required this.selectedRole});

  final UserRole selectedRole;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 280),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.deepGreen,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
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
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.eco_rounded,
                  color: AppColors.deepGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'SmartAgro Connect',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 48),
          Text(
            _headlineForRole(selectedRole),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            _summaryForRole(selectedRole),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.82),
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 20),
          const Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _TrustBadge(
                icon: Icons.verified_user_outlined,
                label: 'Verified trade',
              ),
              _TrustBadge(icon: Icons.route_outlined, label: 'Logistics ready'),
              _TrustBadge(
                icon: Icons.analytics_outlined,
                label: 'Market intelligence',
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_outline, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Role-aware access keeps each workspace focused and secure.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.84),
                        ),
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

class _LoginPanel extends StatelessWidget {
  const _LoginPanel({
    required this.formKey,
    required this.email,
    required this.password,
    required this.role,
    required this.busy,
    required this.error,
    required this.obscurePassword,
    required this.isLiveMode,
    required this.onRoleSelected,
    required this.onSubmit,
    required this.onGoogle,
    required this.onTogglePassword,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController email;
  final TextEditingController password;
  final UserRole role;
  final bool busy;
  final String? error;
  final bool obscurePassword;
  final bool isLiveMode;
  final ValueChanged<UserRole> onRoleSelected;
  final VoidCallback onSubmit;
  final VoidCallback onGoogle;
  final VoidCallback onTogglePassword;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.06),
            blurRadius: 24,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Sign in',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose a workspace and continue into your enterprise console.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            if (!isLiveMode)
              _RoleSelector(selected: role, onSelected: onRoleSelected)
            else
              _RoleInfoBanner(role: role),
            const SizedBox(height: 18),
            TextFormField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Work email',
                prefixIcon: Icon(Icons.mail_outline),
              ),
              validator: (v) =>
                  v == null || !v.contains('@') ? 'Enter a valid email' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: password,
              obscureText: obscurePassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => busy ? null : onSubmit(),
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  tooltip: obscurePassword ? 'Show password' : 'Hide password',
                  onPressed: onTogglePassword,
                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: (v) =>
                  v == null || v.length < 6 ? 'Minimum 6 characters' : null,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.push('/forgot'),
                child: const Text('Forgot password?'),
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              _ErrorBanner(message: error!),
            ],
            const SizedBox(height: 14),
            PrimaryGradientButton(
              label: busy ? 'Signing in...' : 'Enter workspace',
              icon: Icons.login_rounded,
              onPressed: busy ? null : onSubmit,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: busy ? null : onGoogle,
                icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
                label: const Text('Continue with Google'),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('New to SmartAgro?'),
                TextButton(
                  onPressed: () => context.push('/register'),
                  child: const Text('Create account'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleSelector extends StatelessWidget {
  const _RoleSelector({
    required this.selected,
    required this.onSelected,
  });

  final UserRole selected;
  final ValueChanged<UserRole> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Workspace',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: UserRole.values.map((role) {
            final active = selected == role;
            final color = _roleColor(role);
            return ChoiceChip(
              selected: active,
              avatar: Icon(
                _roleIcon(role),
                size: 18,
                color: active ? Colors.white : color,
              ),
              label: Text(_roleLabel(role)),
              labelStyle: TextStyle(
                color: active ? Colors.white : null,
                fontWeight: FontWeight.w700,
              ),
              selectedColor: color,
              checkmarkColor: Colors.white,
              onSelected: (_) => onSelected(role),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _TrustBadge extends StatelessWidget {
  const _TrustBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.error),
      ),
      child: Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}

class _RoleInfoBanner extends StatelessWidget {
  const _RoleInfoBanner({required this.role});
  final UserRole role;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.deepGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.deepGreen.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(_roleIcon(role), size: 18, color: AppColors.deepGreen),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Signing in as ${_roleLabel(role)} — your workspace is set by your registration.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.deepGreen,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

String _headlineForRole(UserRole role) {
  return switch (role) {
    UserRole.farmer => 'Run your farm trade desk with confidence.',
    UserRole.buyer => 'Source verified produce with market clarity.',
    UserRole.transporter => 'Coordinate routes, hubs, and dispatch work.',
    UserRole.admin => 'Govern users, listings, and platform risk.',
  };
}

String _summaryForRole(UserRole role) {
  return switch (role) {
    UserRole.farmer =>
      'Manage listings, watch commodity prices, and connect with trusted buyers from one focused workspace.',
    UserRole.buyer =>
      'Compare listings, validate supplier quality, and move quickly from sourcing to negotiation.',
    UserRole.transporter =>
      'Track delivery opportunities, route lanes, and dispatch conversations without marketplace clutter.',
    UserRole.admin =>
      'Monitor platform health, review users, moderate commodities, and keep marketplace operations clean.',
  };
}

String _roleLabel(UserRole role) {
  return switch (role) {
    UserRole.farmer => 'Farmer',
    UserRole.buyer => 'Buyer',
    UserRole.transporter => 'Transporter',
    UserRole.admin => 'Admin',
  };
}

IconData _roleIcon(UserRole role) {
  return switch (role) {
    UserRole.farmer => Icons.agriculture_outlined,
    UserRole.buyer => Icons.storefront_outlined,
    UserRole.transporter => Icons.local_shipping_outlined,
    UserRole.admin => Icons.admin_panel_settings_outlined,
  };
}

Color _roleColor(UserRole role) {
  return switch (role) {
    UserRole.farmer => AppColors.deepGreen,
    UserRole.buyer => const Color(0xFF1565C0),
    UserRole.transporter => AppColors.warmOrange,
    UserRole.admin => const Color(0xFF5E35B1),
  };
}
