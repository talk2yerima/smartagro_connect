import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/di/payment_providers.dart';
import '../../core/errors/friendly_error.dart';
import '../../core/utils/money_format.dart';
import '../../data/repositories/transaction_ref_queue.dart';
import '../../shared/widgets/empty_state.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final async = ref.watch(transactionHistoryProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.softWhite,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        title: Text(
          'Payment History',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
      ),
      body: async.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.deepGreen),
        ),
        error: (e, _) => Center(
            child: Text('Could not load your orders.\n${friendlyError(e)}',
                textAlign: TextAlign.center)),
        data: (refs) {
          if (refs.isEmpty) {
            return const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No payments yet',
              subtitle:
                  'Your payment history will appear here after your first purchase.',
            );
          }
          return RefreshIndicator(
            color: AppColors.deepGreen,
            onRefresh: () => ref.refresh(transactionHistoryProvider.future),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: refs.length,
              itemBuilder: (context, i) =>
                  _OrderTile(ref: refs[i], isDark: isDark)
                      .animate(delay: (40 * i).ms)
                      .fadeIn(duration: 260.ms)
                      .slideY(begin: 0.04),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.ref, required this.isDark});

  final TransactionRef ref;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark ? AppColors.cardDark : Colors.white;
    final textColor = AppColors.text(isDark);
    final subColor = AppColors.subText(isDark);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.borderLight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Status icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _statusColor(ref.status).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _statusIcon(ref.status),
              color: _statusColor(ref.status),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),

          // Description + date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ref.description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('d MMM yyyy · HH:mm').format(ref.createdAt),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: subColor,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Amount + status badge
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatNgn(ref.amountNgn),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
              ),
              const SizedBox(height: 4),
              _StatusBadge(status: ref.status),
            ],
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) => switch (status) {
        'success' => AppColors.deepGreen,
        'failed' || 'reversed' || 'amount_mismatch' => AppColors.errorRed,
        'abandoned' => AppColors.gray,
        _ => const Color(0xFFF59E0B), // pending = amber
      };

  IconData _statusIcon(String status) => switch (status) {
        'success' => Icons.check_circle_rounded,
        'failed' || 'reversed' => Icons.cancel_rounded,
        'amount_mismatch' => Icons.report_gmailerrorred_rounded,
        'abandoned' => Icons.remove_circle_outline_rounded,
        _ => Icons.hourglass_empty_rounded,
      };
}

// ---------------------------------------------------------------------------

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      'success' => ('Paid', const Color(0xFFE8F5E9), AppColors.deepGreen),
      'failed' => ('Failed', const Color(0xFFFFEBEE), AppColors.errorRed),
      'reversed' => ('Refunded', const Color(0xFFFFEBEE), AppColors.errorRed),
      'amount_mismatch' => (
          'Under review',
          const Color(0xFFFFEBEE),
          AppColors.errorRed
        ),
      'abandoned' => ('Abandoned', const Color(0xFFF5F5F5), AppColors.gray),
      _ => ('Pending', const Color(0xFFFFF8E1), const Color(0xFFF59E0B)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
