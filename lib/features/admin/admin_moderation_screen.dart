import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/di/firestore_providers.dart';
import '../../shared/widgets/status_badge.dart';

// ─── Provider ────────────────────────────────────────────────────────────────

final _reportsStreamProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(firestoreServiceProvider).reportsStream();
});

// ─── Screen ──────────────────────────────────────────────────────────────────

class AdminModerationScreen extends ConsumerStatefulWidget {
  const AdminModerationScreen({super.key});

  @override
  ConsumerState<AdminModerationScreen> createState() =>
      _AdminModerationScreenState();
}

class _AdminModerationScreenState extends ConsumerState<AdminModerationScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _setStatus(String reportId, String status, String label) async {
    await ref
        .read(firestoreServiceProvider)
        .updateReportStatus(reportId, status);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(label),
        backgroundColor:
            status == 'approved' ? AppColors.mintGreen : AppColors.errorRed,
        duration: const Duration(seconds: 2),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reportsAsync = ref.watch(_reportsStreamProvider);

    return reportsAsync.when(
      loading: () => Scaffold(
        backgroundColor: isDark ? AppColors.darkBg : AppColors.softWhite,
        appBar: AppBar(
          title: const Text('Moderation Queue',
              style: TextStyle(
                  fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
        ),
        body: const Center(
            child: CircularProgressIndicator(color: AppColors.deepGreen)),
      ),
      error: (_, __) => Scaffold(
        backgroundColor: isDark ? AppColors.darkBg : AppColors.softWhite,
        appBar: AppBar(
          title: const Text('Moderation Queue',
              style: TextStyle(
                  fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
        ),
        body: const Center(child: Text('Could not load moderation queue.')),
      ),
      data: (reports) {
        final pending = reports.where((r) => r['status'] == 'pending').toList();
        final approved =
            reports.where((r) => r['status'] == 'approved').toList();
        final rejected =
            reports.where((r) => r['status'] == 'rejected').toList();

        return Scaffold(
          backgroundColor: isDark ? AppColors.darkBg : AppColors.softWhite,
          appBar: AppBar(
            elevation: 0,
            scrolledUnderElevation: 0.5,
            title: Row(
              children: [
                const Text(
                  'Moderation Queue',
                  style: TextStyle(
                      fontFamily: 'Poppins', fontWeight: FontWeight.w700),
                ),
                if (pending.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Badge(
                    backgroundColor: AppColors.warmOrange,
                    label: Text('${pending.length}'),
                  ),
                ],
              ],
            ),
            bottom: TabBar(
              controller: _tabs,
              labelStyle: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  fontSize: 12),
              unselectedLabelStyle:
                  const TextStyle(fontFamily: 'Poppins', fontSize: 12),
              tabs: [
                Tab(text: 'Pending (${pending.length})'),
                const Tab(text: 'Approved'),
                const Tab(text: 'Rejected'),
              ],
            ),
          ),
          body: reports.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield_outlined,
                          size: 56, color: AppColors.gray),
                      SizedBox(height: 12),
                      Text(
                        'No reports yet',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: AppColors.gray),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Reports submitted by users will appear here.',
                        style: TextStyle(fontSize: 13, color: AppColors.gray),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabs,
                  children: [
                    _ReportList(
                      items: pending,
                      isDark: isDark,
                      onApprove: (id) =>
                          _setStatus(id, 'approved', 'Report approved'),
                      onReject: (id) => _setStatus(
                          id, 'rejected', 'Listing rejected and removed'),
                    ),
                    _ReportList(items: approved, isDark: isDark),
                    _ReportList(items: rejected, isDark: isDark),
                  ],
                ),
        );
      },
    );
  }
}

// ─── Report list ──────────────────────────────────────────────────────────────

class _ReportList extends StatelessWidget {
  const _ReportList({
    required this.items,
    required this.isDark,
    this.onApprove,
    this.onReject,
  });

  final List<Map<String, dynamic>> items;
  final bool isDark;
  final void Function(String id)? onApprove;
  final void Function(String id)? onReject;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          'Nothing here.',
          style: TextStyle(
              color: isDark ? AppColors.darkTextSecondary : AppColors.gray),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: items.length,
      itemBuilder: (context, i) => _ReportCard(
        item: items[i],
        isDark: isDark,
        onApprove: onApprove,
        onReject: onReject,
      )
          .animate(delay: (50 * i).ms)
          .fadeIn(duration: 300.ms)
          .slideY(begin: 0.04, end: 0, duration: 300.ms),
    );
  }
}

// ─── Report card ──────────────────────────────────────────────────────────────

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.item,
    required this.isDark,
    this.onApprove,
    this.onReject,
  });

  final Map<String, dynamic> item;
  final bool isDark;
  final void Function(String id)? onApprove;
  final void Function(String id)? onReject;

  String _formatTs(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
  }

  @override
  Widget build(BuildContext context) {
    final id = item['id'] as String? ?? '';
    final title = item['productTitle'] as String? ??
        item['title'] as String? ??
        'Untitled';
    final category = item['category'] as String? ?? '';
    final reason = item['reason'] as String? ?? '';
    final reportedBy = item['reportedBy'] as String? ?? 'Anonymous';
    final ts = _formatTs(item['reportedAt'] as String?);
    final status = item['status'] as String? ?? 'pending';
    final isPending = status == 'pending';
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF2E3C2E) : const Color(0xFFE2EAE0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.warmOrange.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.flag_outlined,
                      color: AppColors.warmOrange, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: isDark ? Colors.white : AppColors.charcoal,
                    ),
                  ),
                ),
                if (category.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  StatusBadge(label: category, color: AppColors.infoBlue),
                ],
              ],
            ),
            const SizedBox(height: 10),

            // Reason box
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.errorRed.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.errorRed.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      size: 14, color: AppColors.errorRed),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      reason,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.errorRed),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Meta
            Row(
              children: [
                const Icon(Icons.person_outline_rounded,
                    size: 13, color: AppColors.gray),
                const SizedBox(width: 4),
                Text('Reported by $reportedBy',
                    style:
                        const TextStyle(fontSize: 11, color: AppColors.gray)),
                const Spacer(),
                if (ts.isNotEmpty) ...[
                  const Icon(Icons.schedule_outlined,
                      size: 13, color: AppColors.gray),
                  const SizedBox(width: 4),
                  Text(ts,
                      style:
                          const TextStyle(fontSize: 11, color: AppColors.gray)),
                ],
              ],
            ),

            // Action buttons (pending only)
            if (isPending && (onApprove != null || onReject != null)) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (onApprove != null)
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.mintGreen,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: () => onApprove!(id),
                        icon: const Icon(Icons.check_rounded, size: 16),
                        label: const Text('Approve',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                      ),
                    ),
                  const SizedBox(width: 10),
                  if (onReject != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.errorRed,
                          side: const BorderSide(color: AppColors.errorRed),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: () => onReject!(id),
                        icon: const Icon(Icons.close_rounded, size: 16),
                        label: const Text('Reject',
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                      ),
                    ),
                ],
              ),
            ],

            // Status badge (resolved items)
            if (!isPending) ...[
              const SizedBox(height: 8),
              StatusBadge(
                label: status == 'approved' ? 'Approved' : 'Rejected',
                color: status == 'approved'
                    ? AppColors.mintGreen
                    : AppColors.errorRed,
                icon: status == 'approved'
                    ? Icons.check_circle_outline
                    : Icons.cancel_outlined,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
