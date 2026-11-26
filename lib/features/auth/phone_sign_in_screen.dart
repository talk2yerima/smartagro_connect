import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/di/auth_providers.dart';
import '../../core/errors/failures.dart';
import '../../core/errors/friendly_error.dart';
import '../../core/i18n/i18n.dart';
import '../../core/utils/phone_number.dart';
import '../../data/repositories/auth_repository.dart';
import '../../domain/entities/app_user.dart';
import '../../shared/widgets/gradient_button.dart';
import 'widgets/role_card.dart';

enum _Step { phone, code, profile }

/// Sign in (or sign up) with a Nigerian phone number and an SMS code.
///
/// 1. Phone number  →  2. 6-digit code  →  3. name + role (new people only)
class PhoneSignInScreen extends ConsumerStatefulWidget {
  const PhoneSignInScreen({super.key});

  @override
  ConsumerState<PhoneSignInScreen> createState() => _PhoneSignInScreenState();
}

class _PhoneSignInScreenState extends ConsumerState<PhoneSignInScreen> {
  static const _resendWait = Duration(seconds: 45);

  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _name = TextEditingController();
  _Step _step = _Step.phone;
  UserRole _role = UserRole.farmer;
  bool _busy = false;
  String? _error;

  String? _e164;
  PhoneCodeRequest? _request;
  Timer? _resendTimer;
  int _resendIn = 0;

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phone.dispose();
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on Failure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Step 1 → 2
  Future<void> _sendCode({bool resend = false}) => _run(() async {
        final e164 = resend ? _e164 : normalizeNigerianPhone(_phone.text);
        if (e164 == null) {
          setState(() => _error =
              'Enter a Nigerian mobile number, for example 0803 123 4567.');
          return;
        }
        final request = await _repo.sendPhoneCode(
          e164,
          resendToken: resend ? _request?.resendToken : null,
        );
        _e164 = e164;
        _request = request;
        if (request.instantCredential != null) {
          // Android confirmed the number itself: no code to type.
          await _finishSignIn();
          return;
        }
        _code.clear();
        setState(() => _step = _Step.code);
        _startResendTimer();
      });

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendIn = _resendWait.inSeconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendIn--);
      if (_resendIn <= 0) t.cancel();
    });
  }

  // Step 2 → home (existing account) or 3 (new person)
  Future<void> _verifyCode() => _run(() async {
        if (_code.text.trim().length != 6) {
          setState(() => _error = 'Enter the 6-digit code from the SMS.');
          return;
        }
        await _finishSignIn();
      });

  Future<void> _finishSignIn() async {
    final user = await _repo.confirmPhoneCode(
      verificationId: _request?.verificationId,
      smsCode: _code.text.trim(),
      instantCredential: _request?.instantCredential,
    );
    if (user == null) {
      setState(() => _step = _Step.profile);
      return;
    }
    _enterApp(user);
  }

  // Step 3 → home
  Future<void> _saveProfile() => _run(() async {
        final name = _name.text.trim();
        if (name.length < 2) {
          setState(() => _error = 'Enter your name.');
          return;
        }
        final user = await _repo.completePhoneProfile(name: name, role: _role);
        _enterApp(user);
      });

  void _enterApp(AppUser user) {
    ref.read(authSessionProvider.notifier).setUser(user);
    if (mounted) context.go('/main/home');
  }

  void _changeNumber() {
    _resendTimer?.cancel();
    setState(() {
      _step = _Step.phone;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = Theme.of(context).textTheme;
    final sub = AppColors.subText(isDark);

    final (title, subtitle) = switch (_step) {
      _Step.phone => (
          'Your phone number',
          "We'll send you a 6-digit code by SMS.",
        ),
      _Step.code => (
          'Enter the code',
          'Sent to ${formatNigerianPhone(_e164 ?? '')}.',
        ),
      _Step.profile => (
          'Welcome to SmartAgro',
          'Tell us your name and how you will use the app.',
        ),
    };

    return Scaffold(
      appBar: AppBar(
        title: const T('Sign in with phone'),
        leading: _step == _Step.code
            ? IconButton(
                tooltip: tr('Change number'),
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: _changeNumber,
              )
            : null,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: text.headlineSmall),
              const SizedBox(height: 4),
              Text(subtitle, style: text.bodyMedium?.copyWith(color: sub)),
              const SizedBox(height: 24),
              ...switch (_step) {
                _Step.phone => _phoneStep(),
                _Step.code => _codeStep(sub),
                _Step.profile => _profileStep(isDark),
              },
              if (_error != null) ...[
                const SizedBox(height: 16),
                _ErrorText(message: _error!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _phoneStep() => [
        TextField(
          controller: _phone,
          autofocus: true,
          keyboardType: TextInputType.phone,
          autofillHints: const [AutofillHints.telephoneNumber],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _sendCode(),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d+\s-]')),
          ],
          decoration: InputDecoration(
            labelText: tr('Phone number'),
            hintText: '0803 123 4567',
            prefixIcon: const Icon(Icons.phone_outlined),
          ),
        ),
        const SizedBox(height: 20),
        PrimaryGradientButton(
          label: _busy ? 'Sending code…' : 'Send code',
          icon: Icons.sms_outlined,
          onPressed: _busy ? null : _sendCode,
        ),
      ];

  List<Widget> _codeStep(Color sub) => [
        TextField(
          controller: _code,
          autofocus: true,
          keyboardType: TextInputType.number,
          autofillHints: const [AutofillHints.oneTimeCode],
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 26,
            letterSpacing: 10,
            fontWeight: FontWeight.w600,
          ),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (v) {
            if (v.length == 6) _verifyCode();
          },
          decoration: const InputDecoration(
            counterText: '',
            hintText: '······',
          ),
        ),
        const SizedBox(height: 20),
        PrimaryGradientButton(
          label: _busy ? 'Checking…' : 'Verify',
          icon: Icons.verified_outlined,
          onPressed: _busy ? null : _verifyCode,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_resendIn > 0)
              Text("Didn't get it? Send again in ${_resendIn}s",
                  style: TextStyle(color: sub))
            else
              TextButton(
                onPressed: _busy ? null : () => _sendCode(resend: true),
                child: const T('Send a new code'),
              ),
          ],
        ),
        TextButton(
          onPressed: _busy ? null : _changeNumber,
          child: const T('Use a different number'),
        ),
      ];

  List<Widget> _profileStep(bool isDark) => [
        TextField(
          controller: _name,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          autofillHints: const [AutofillHints.name],
          decoration: InputDecoration(
            labelText: tr('Full name'),
            prefixIcon: const Icon(Icons.person_outline_rounded),
          ),
        ),
        const SizedBox(height: 20),
        T('I am a', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
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
        PrimaryGradientButton(
          label: _busy ? 'Saving…' : 'Start using SmartAgro',
          icon: Icons.arrow_forward_rounded,
          onPressed: _busy ? null : _saveProfile,
        ),
      ];
}

class _ErrorText extends StatelessWidget {
  const _ErrorText({required this.message});

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
