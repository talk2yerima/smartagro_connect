import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/di/auth_providers.dart';
import '../../core/di/payment_providers.dart';
import '../../core/services/app_lock.dart';
import '../../core/utils/money_format.dart';
import '../../data/services/payments_api.dart';

/// Shows the Paystack payment flow as a modal bottom sheet.
///
/// Usage:
/// ```dart
/// final result = await PaymentSheet.show(
///   context,
///   productId: product.id,
///   amountNgn: 28000, // display only — the server decides the charge
///   description: 'Maize lot #1042 — 50 bags',
/// );
/// if (result == PaymentResult.initiated) { ... }
/// ```
enum PaymentResult { initiated, cancelled, error, success, failed }

enum _Stage { entering, pendingReturn, verifying, done }

class PaymentSheet extends ConsumerStatefulWidget {
  const PaymentSheet({
    super.key,
    required this.productId,
    required this.amountNgn,
    required this.description,
  });

  /// Listing being bought. The backend prices it from Firestore.
  final String productId;

  /// Shown to the buyer only; the amount charged comes from the server.
  final double amountNgn;
  final String description;

  static Future<PaymentResult?> show(
    BuildContext context, {
    required String productId,
    required double amountNgn,
    required String description,
  }) {
    return showModalBottomSheet<PaymentResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PaymentSheet(
        productId: productId,
        amountNgn: amountNgn,
        description: description,
      ),
    );
  }

  @override
  ConsumerState<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<PaymentSheet> {
  late final TextEditingController _emailCtrl;
  _Stage _stage = _Stage.entering;
  String? _error;
  String? _reference;
  String _txStatus = '';

  @override
  void initState() {
    super.initState();
    final userEmail = ref.read(authSessionProvider)?.email ?? '';
    _emailCtrl = TextEditingController(text: userEmail);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  bool _connecting = false;

  Future<void> _pay() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    setState(() {
      _connecting = true;
      _error = null;
    });

    final queue = ref.read(transactionRefQueueProvider);
    final api = ref.read(paymentsApiProvider);

    try {
      final result = await api.initialize(
        productId: widget.productId,
        email: email,
      );

      // Persist BEFORE opening the browser so the reference survives the app
      // being killed while the buyer is on the Paystack page.
      await queue.enqueue(
        reference: result.reference,
        amountKobo: result.amountKobo,
        email: email,
        description: result.description.isNotEmpty
            ? result.description
            : widget.description,
      );
      _reference = result.reference;

      // The Paystack page is an expected trip: no re-lock on return.
      ref.read(appLockProvider.notifier).allowNextReturn();
      final opened = await launchUrl(
        Uri.parse(result.authorizationUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _stage = _Stage.pendingReturn;
        if (!opened) {
          _error = 'Could not open the payment page. Tap below to retry.';
        }
      });
    } on PaymentException catch (e) {
      if (mounted) {
        setState(() {
          _connecting = false;
          _error = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _connecting = false;
          _error = 'Could not start payment. Try again.';
        });
      }
    }
  }

  Future<void> _verify() async {
    if (_reference == null) return;
    setState(() {
      _stage = _Stage.verifying;
      _error = null;
    });
    try {
      final queue = ref.read(transactionRefQueueProvider);
      final status = await queue.verifyRef(_reference!);
      if (!mounted) return;
      if (status == 'pending' || status == 'abandoned') {
        // Paystack has not confirmed the charge yet — let the buyer retry.
        // The webhook will also complete it on the server in the background.
        setState(() {
          _stage = _Stage.pendingReturn;
          _error = 'Payment not confirmed yet. If you have paid, wait a '
              'moment and tap the button again.';
        });
        return;
      }
      if (mounted) {
        setState(() {
          _txStatus = status;
          _stage = _Stage.done;
        });
        await Future.delayed(const Duration(milliseconds: 1400));
        if (mounted) {
          Navigator.of(context).pop(
            status == 'success' ? PaymentResult.success : PaymentResult.failed,
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _stage = _Stage.pendingReturn;
          _error = 'Verification failed. Check your connection and try again.';
        });
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetColor = isDark ? AppColors.cardDark : Colors.white;
    final padding = MediaQuery.viewInsetsOf(context);

    return Container(
      decoration: BoxDecoration(
        color: sheetColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + padding.bottom),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        child: switch (_stage) {
          _Stage.entering => _buildEntering(isDark),
          _Stage.pendingReturn => _buildPendingReturn(isDark),
          _Stage.verifying => _buildVerifying(),
          _Stage.done => _buildDone(isDark),
        },
      ),
    );
  }

  // ── Stage: email entry ─────────────────────────────────────────────────────

  Widget _buildEntering(bool isDark) {
    final isConnecting = _connecting;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _handle(),
        const SizedBox(height: 20),
        const Text(
          'Complete Payment',
          style: TextStyle(
              fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 18),
        ),
        const SizedBox(height: 16),
        _summaryCard(isDark),
        const SizedBox(height: 16),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'Receipt email',
            hintText: 'you@example.com',
            prefixIcon: const Icon(Icons.email_outlined, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 8),
        const Row(
          children: [
            Icon(Icons.lock_outlined, size: 13, color: AppColors.gray),
            SizedBox(width: 4),
            Flexible(
              child: Text(
                'Secured by Paystack · Card, bank transfer & USSD accepted',
                style: TextStyle(fontSize: 11, color: AppColors.gray),
              ),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          _errorBanner(_error!)
        ],
        const SizedBox(height: 16),
        _fullButton(
          onPressed: isConnecting ? null : _pay,
          icon: isConnecting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.open_in_new_rounded, size: 18),
          label: isConnecting
              ? 'Connecting to Paystack…'
              : 'Pay ${formatNgn(widget.amountNgn)}',
        ),
        const SizedBox(height: 8),
        _cancelButton(),
      ],
    );
  }

  // ── Stage: browser open, waiting for user return ───────────────────────────

  Widget _buildPendingReturn(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _handle(),
        const SizedBox(height: 24),
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.deepGreen.withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.open_in_browser_rounded,
              size: 32, color: AppColors.deepGreen),
        ),
        const SizedBox(height: 16),
        const Text(
          'Payment page opened',
          style: TextStyle(
              fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 17),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'Complete your payment in the browser,\nthen come back and tap the button below.',
          style: TextStyle(color: AppColors.gray, fontSize: 13, height: 1.5),
          textAlign: TextAlign.center,
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          _errorBanner(_error!)
        ],
        const SizedBox(height: 24),
        _fullButton(
          onPressed: _verify,
          icon: const Icon(Icons.verified_rounded, size: 18),
          label: "I've completed payment",
        ),
        const SizedBox(height: 8),
        _cancelButton(),
      ],
    );
  }

  // ── Stage: verifying ───────────────────────────────────────────────────────

  Widget _buildVerifying() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _handle(),
        const SizedBox(height: 40),
        const CircularProgressIndicator(
            color: AppColors.deepGreen, strokeWidth: 3),
        const SizedBox(height: 20),
        const Text(
          'Verifying your payment…',
          style: TextStyle(
              fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 16),
        ),
        const SizedBox(height: 8),
        const Text(
          'This usually takes a few seconds.',
          style: TextStyle(color: AppColors.gray, fontSize: 13),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  // ── Stage: done ────────────────────────────────────────────────────────────

  Widget _buildDone(bool isDark) {
    final isSuccess = _txStatus == 'success';
    final color = isSuccess ? AppColors.deepGreen : AppColors.errorRed;
    final icon = isSuccess ? Icons.check_circle_rounded : Icons.cancel_rounded;
    final title = isSuccess ? 'Payment successful!' : 'Payment not completed';
    final body = isSuccess
        ? 'Your order has been placed. The seller will be notified.'
        : _txStatus == 'amount_mismatch'
            ? 'The amount received did not match the order. Our team will '
                'review it — please contact support with your reference.'
            : 'Status: $_txStatus. You can retry or contact support.';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _handle(),
        const SizedBox(height: 32),
        Icon(icon, size: 64, color: color),
        const SizedBox(height: 16),
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          body,
          style:
              const TextStyle(color: AppColors.gray, fontSize: 13, height: 1.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  // ── Shared sub-widgets ─────────────────────────────────────────────────────

  Widget _handle() => Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFFE0E0E0),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _summaryCard(bool isDark) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.deepGreen.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: AppColors.deepGreen.withValues(alpha: 0.20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.inventory_2_outlined,
                    size: 16, color: AppColors.deepGreen),
                SizedBox(width: 6),
                Text(
                  'ORDER SUMMARY',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    letterSpacing: 1.0,
                    color: AppColors.deepGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.description,
              style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white : AppColors.charcoal),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.gray,
                        fontSize: 13)),
                Text(
                  formatNgn(widget.amountNgn),
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: isDark ? Colors.white : AppColors.charcoal,
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _errorBanner(String message) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.errorRed.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.errorRed.withValues(alpha: 0.30)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 15, color: AppColors.errorRed),
            const SizedBox(width: 8),
            Expanded(
                child: Text(message,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.errorRed))),
          ],
        ),
      );

  Widget _fullButton(
          {required VoidCallback? onPressed,
          required Widget icon,
          required String label}) =>
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.deepGreen,
            disabledBackgroundColor:
                AppColors.deepGreen.withValues(alpha: 0.45),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: onPressed,
          icon: icon,
          label: Text(
            label,
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
                fontSize: 15),
          ),
        ),
      );

  Widget _cancelButton() => SizedBox(
        width: double.infinity,
        child: TextButton(
          onPressed: () => Navigator.of(context).pop(PaymentResult.cancelled),
          child: const Text('Cancel', style: TextStyle(color: AppColors.gray)),
        ),
      );
}
