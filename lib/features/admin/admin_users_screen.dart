import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/di/firestore_providers.dart';
import '../../shared/widgets/app_avatar.dart';
import '../../shared/widgets/status_badge.dart';

final _adminUsersProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(firestoreServiceProvider).fetchAllUsers();
});

Color _roleColor(String role) => switch (role) {
      'farmer' => AppColors.freshGreen,
      'buyer' => AppColors.infoBlue,
      'transporter' => AppColors.warmOrange,
      _ => AppColors.gray,
    };

String _roleLabel(String role) => switch (role) {
      'farmer' => 'Farmer',
      'buyer' => 'Buyer',
      'transporter' => 'Transporter',
      'admin' => 'Admin',
      _ => role,
    };

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filter(
      List<Map<String, dynamic>> all, String? role) {
    final q = _search.toLowerCase();
    return all.where((u) {
      if (role != null && (u['role'] as String?) != role) return false;
      if (q.isEmpty) return true;
      final name = (u['name'] as String? ?? '').toLowerCase();
      final email = (u['email'] as String? ?? '').toLowerCase();
      return name.contains(q) || email.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final usersAsync = ref.watch(_adminUsersProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.softWhite,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        title: const Text(
          'User Management',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(_adminUsersProvider),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelStyle: const TextStyle(
              fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 12),
          unselectedLabelStyle:
              const TextStyle(fontFamily: 'Poppins', fontSize: 12),
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Farmers'),
            Tab(text: 'Buyers'),
            Tab(text: 'Transporters'),
          ],
        ),
      ),
      body: usersAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.deepGreen)),
        error: (_, __) => const Center(child: Text('Could not load users.')),
        data: (all) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search by name or email…',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _UserList(users: _filter(all, null), isDark: isDark),
                  _UserList(users: _filter(all, 'farmer'), isDark: isDark),
                  _UserList(users: _filter(all, 'buyer'), isDark: isDark),
                  _UserList(users: _filter(all, 'transporter'), isDark: isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserList extends ConsumerWidget {
  const _UserList({required this.users, required this.isDark});

  final List<Map<String, dynamic>> users;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (users.isEmpty) {
      return const Center(child: Text('No users found.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      itemCount: users.length,
      itemBuilder: (context, i) => _UserCard(user: users[i], isDark: isDark)
          .animate(delay: (40 * i).ms)
          .fadeIn(duration: 300.ms)
          .slideY(begin: 0.04, end: 0, duration: 300.ms),
    );
  }
}

class _UserCard extends ConsumerStatefulWidget {
  const _UserCard({required this.user, required this.isDark});

  final Map<String, dynamic> user;
  final bool isDark;

  @override
  ConsumerState<_UserCard> createState() => _UserCardState();
}

class _UserCardState extends ConsumerState<_UserCard> {
  late bool _verified;
  late bool _banned;

  @override
  void initState() {
    super.initState();
    _verified = (widget.user['verified'] as bool?) ?? false;
    _banned = (widget.user['banned'] as bool?) ?? false;
  }

  Future<void> _toggleVerify() async {
    final next = !_verified;
    setState(() => _verified = next);
    try {
      await ref.read(firestoreServiceProvider).setUserVerified(
            widget.user['id'] as String,
            verified: next,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(next
              ? '${widget.user['name']} marked as verified'
              : '${widget.user['name']} verification removed'),
          backgroundColor: next ? AppColors.mintGreen : AppColors.gray,
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (_) {
      // Roll back optimistic update on failure.
      if (mounted) setState(() => _verified = !next);
    }
  }

  Future<void> _toggleBan() async {
    final next = !_banned;
    setState(() => _banned = next);
    try {
      await ref.read(firestoreServiceProvider).setUserBanned(
            widget.user['id'] as String,
            banned: next,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(next
              ? '${widget.user['name']} has been banned'
              : '${widget.user['name']} has been unbanned'),
          backgroundColor: next ? AppColors.errorRed : AppColors.mintGreen,
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (_) {
      if (mounted) setState(() => _banned = !next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final isDark = widget.isDark;
    final name = (u['name'] as String?) ?? 'Unknown';
    final email = (u['email'] as String?) ?? '';
    final role = (u['role'] as String?) ?? '';
    final location = (u['location'] as String?) ?? '';
    final createdAt = u['createdAt'] as String?;
    final joined = createdAt != null
        ? _formatDate(DateTime.tryParse(createdAt))
        : 'Unknown';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _banned
            ? AppColors.errorRed.withValues(alpha: 0.06)
            : (isDark ? AppColors.cardDark : Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _banned
              ? AppColors.errorRed.withValues(alpha: 0.35)
              : (isDark ? AppColors.darkBorder : AppColors.borderLight),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            AppAvatar(name: name, color: _roleColor(role), radius: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: isDark ? Colors.white : AppColors.charcoal,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (_verified)
                        const StatusBadge(
                          label: 'Verified',
                          color: AppColors.mintGreen,
                          icon: Icons.verified_rounded,
                        ),
                      if (_banned)
                        const StatusBadge(
                          label: 'Banned',
                          color: AppColors.errorRed,
                          icon: Icons.block_rounded,
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(fontSize: 12, color: AppColors.gray)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      StatusBadge(
                          label: _roleLabel(role), color: _roleColor(role)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          [if (location.isNotEmpty) location, 'Joined $joined']
                              .join(' · '),
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.gray),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, size: 20),
              onSelected: (v) {
                if (v == 'verify') _toggleVerify();
                if (v == 'ban') _toggleBan();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'verify',
                  child:
                      Text(_verified ? 'Remove verification' : 'Mark verified'),
                ),
                PopupMenuItem(
                  value: 'ban',
                  child: Text(
                    _banned ? 'Unban user' : 'Ban user',
                    style: TextStyle(
                      color: _banned ? AppColors.mintGreen : AppColors.errorRed,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Unknown';
    return '${_month(dt.month)} ${dt.day}, ${dt.year}';
  }

  String _month(int m) => const [
        '',
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ][m];
}
