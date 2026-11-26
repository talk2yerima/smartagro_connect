import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/di/auth_providers.dart';
import '../../core/di/firestore_providers.dart';
import '../../core/di/repositories_provider.dart';
import '../../core/errors/friendly_error.dart';
import '../../core/i18n/i18n.dart';
import '../../domain/entities/chat_models.dart';
import '../../shared/widgets/app_avatar.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/skeleton_list.dart';
// ─── Role colour helper ────────────────────────────────────────────────────

Color _roleColor(String role) {
  switch (role.toLowerCase()) {
    case 'farmer':
      return AppColors.deepGreen;
    case 'buyer':
      return AppColors.infoBlue;
    case 'transporter':
      return AppColors.warmOrange;
    default:
      return AppColors.gray;
  }
}

// ─── Card box-decoration ───────────────────────────────────────────────────

BoxDecoration _card(bool isDark) => isDark
    ? BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.darkBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      )
    : BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      );

// ─── Timestamp formatter ───────────────────────────────────────────────────

String _formatTime(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(dt.year, dt.month, dt.day);

  if (date == today) {
    return DateFormat('h:mm a').format(dt);
  }
  final yesterday = today.subtract(const Duration(days: 1));
  if (date == yesterday) return 'Yesterday';
  if (now.difference(dt).inDays < 7) {
    return DateFormat('EEE').format(dt);
  }
  return DateFormat('MMM d').format(dt);
}

// ─── Filter chip labels ───────────────────────────────────────────────────

const List<String> _filters = ['All', 'Buyers', 'Farmers', 'Transporters'];

// ─── Main screen ──────────────────────────────────────────────────────────

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String _activeFilter = 'All';
  _Box _box = _Box.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ChatThread> _applyFilters(List<ChatThread> threads) {
    var result = switch (_box) {
      _Box.all => threads.where((t) => !t.archived).toList(),
      _Box.unread => threads.where((t) => !t.archived && t.unread > 0).toList(),
      _Box.archived => threads.where((t) => t.archived).toList(),
    };

    // Apply search query
    if (_query.trim().isNotEmpty) {
      final q = _query.trim().toLowerCase();
      result = result
          .where((t) =>
              t.peerName.toLowerCase().contains(q) ||
              t.lastMessage.toLowerCase().contains(q))
          .toList();
    }

    // Apply role filter
    if (_activeFilter != 'All') {
      final roleKey = _activeFilter.toLowerCase();
      // "Buyers" → "buyer", "Farmers" → "farmer", "Transporters" → "transporter"
      final singular = roleKey.endsWith('s')
          ? roleKey.substring(0, roleKey.length - 1)
          : roleKey;
      result =
          result.where((t) => t.peerRole.toLowerCase() == singular).toList();
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final async = ref.watch(chatThreadsProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.softWhite,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkBg : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        title: const T(
          'Messages',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: tr('New conversation'),
            onPressed: () => context.push('/search'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: async.when(
        loading: () =>
            const SkeletonList(count: 5, showAvatar: true, height: 72),
        error: (error, _) => _ErrorBody(error: friendlyError(error)),
        data: (threads) {
          final filtered = _applyFilters(threads);
          final unreadCount =
              threads.where((t) => !t.archived && t.unread > 0).length;
          final archivedCount = threads.where((t) => t.archived).length;
          return RefreshIndicator(
            color: AppColors.deepGreen,
            onRefresh: () async => ref.invalidate(chatThreadsProvider),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: SegmentedButton<_Box>(
                      showSelectedIcon: false,
                      segments: [
                        const ButtonSegment(value: _Box.all, label: T('All')),
                        ButtonSegment(
                            value: _Box.unread,
                            label: Text(unreadCount == 0
                                ? 'Unread'
                                : 'Unread ($unreadCount)')),
                        ButtonSegment(
                            value: _Box.archived,
                            label: Text(archivedCount == 0
                                ? 'Archived'
                                : 'Archived ($archivedCount)')),
                      ],
                      selected: {_box},
                      onSelectionChanged: (s) => setState(() => _box = s.first),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _SearchAndFilterBar(
                    isDark: isDark,
                    controller: _searchController,
                    query: _query,
                    activeFilter: _activeFilter,
                    onQueryChanged: (v) => setState(() => _query = v),
                    onFilterChanged: (f) => setState(() => _activeFilter = f),
                  ),
                ),
                if (filtered.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: switch (_box) {
                      _Box.unread => EmptyState(
                          icon: Icons.mark_chat_read_outlined,
                          title: tr('All caught up'),
                          subtitle: tr('You have read every message.'),
                        ),
                      _Box.archived => EmptyState(
                          icon: Icons.archive_outlined,
                          title: tr('No archived chats'),
                          subtitle:
                              tr('Swipe a chat to the left to archive it.'),
                        ),
                      _Box.all => EmptyState(
                          type: EmptyStateType.chat,
                          icon: Icons.chat_bubble_outline,
                          title: tr('No messages yet'),
                          subtitle:
                              tr('Start a conversation with buyers or sellers'),
                        ),
                    },
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => _Archivable(
                          thread: filtered[i],
                          child: _ThreadTile(
                            thread: filtered[i],
                            isDark: isDark,
                            index: i,
                          ),
                        ),
                        childCount: filtered.length,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

enum _Box { all, unread, archived }

/// Swipe a chat left to archive it (or, under Archived, to bring it back).
class _Archivable extends ConsumerWidget {
  const _Archivable({required this.thread, required this.child});

  final ChatThread thread;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authSessionProvider.select((u) => u?.id));
    if (uid == null) return child;
    final archive = !thread.archived;
    return Dismissible(
      key: ValueKey('chat-${thread.id}-${thread.archived}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: archive ? AppColors.gray : AppColors.emerald,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(archive ? Icons.archive_outlined : Icons.unarchive_outlined,
                color: Colors.white),
            const SizedBox(width: 6),
            Text(archive ? 'Archive' : 'Unarchive',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      onDismissed: (_) {
        final db = ref.read(firestoreServiceProvider);
        db.setThreadArchived(thread.id, uid, archive);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(archive
              ? 'Chat with ${thread.peerName} archived.'
              : 'Chat with ${thread.peerName} moved back.'),
          action: SnackBarAction(
            label: tr('Undo'),
            onPressed: () => db.setThreadArchived(thread.id, uid, !archive),
          ),
        ));
      },
      child: child,
    );
  }
}

// ─── Search + Filter bar ──────────────────────────────────────────────────

class _SearchAndFilterBar extends StatelessWidget {
  const _SearchAndFilterBar({
    required this.isDark,
    required this.controller,
    required this.query,
    required this.activeFilter,
    required this.onQueryChanged,
    required this.onFilterChanged,
  });

  final bool isDark;
  final TextEditingController controller;
  final String query;
  final String activeFilter;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search field
          Container(
            height: 46,
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.borderLight,
              ),
            ),
            child: TextField(
              controller: controller,
              onChanged: onQueryChanged,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.darkTextPrimary : AppColors.charcoal,
              ),
              decoration: InputDecoration(
                hintText: tr('Search conversations…'),
                hintStyle: const TextStyle(
                  fontSize: 14,
                  color: AppColors.gray,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: AppColors.gray,
                ),
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded,
                            size: 18, color: AppColors.gray),
                        onPressed: () {
                          controller.clear();
                          onQueryChanged('');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Filter chips
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final label = _filters[i];
                final selected = label == activeFilter;
                return _FilterChip(
                  label: label,
                  selected: selected,
                  isDark: isDark,
                  onTap: () => onFilterChanged(label),
                );
              },
            ),
          ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ─── Single filter chip ───────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.deepGreen
              : (isDark ? AppColors.cardDark : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppColors.deepGreen
                : (isDark ? AppColors.darkBorder : AppColors.borderLight),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            fontSize: 13,
            color: selected
                ? Colors.white
                : (isDark ? AppColors.darkTextSecondary : AppColors.gray),
          ),
        ),
      ),
    );
  }
}

// ─── Thread tile ──────────────────────────────────────────────────────────

class _ThreadTile extends StatelessWidget {
  const _ThreadTile({
    required this.thread,
    required this.isDark,
    required this.index,
  });

  final ChatThread thread;
  final bool isDark;
  final int index;

  @override
  Widget build(BuildContext context) {
    final roleColor = _roleColor(thread.peerRole);
    final hasUnread = thread.unread > 0;

    return GestureDetector(
      onTap: () => context.push('/main/messages/thread/${thread.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: _card(isDark),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar with online dot
            Stack(
              children: [
                AppAvatar(
                  name: thread.peerName,
                  color: roleColor,
                  radius: 26,
                ),
                Positioned(
                  right: 1,
                  bottom: 1,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.mintGreen,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? AppColors.cardDark : Colors.white,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(width: 12),

            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name row + timestamp
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          thread.peerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight:
                                hasUnread ? FontWeight.w700 : FontWeight.w600,
                            fontSize: 14,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.charcoal,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(thread.updatedAt),
                        style: TextStyle(
                          fontSize: 11,
                          color:
                              hasUnread ? AppColors.deepGreen : AppColors.gray,
                          fontWeight:
                              hasUnread ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // Last message row + unread badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          thread.lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: hasUnread
                                ? (isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.charcoal)
                                : AppColors.gray,
                            fontWeight:
                                hasUnread ? FontWeight.w500 : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: 8),
                        _UnreadBadge(count: thread.unread),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    )
        .animate(delay: (50 * index).ms)
        .fadeIn(duration: 280.ms)
        .slideX(begin: 0.02, duration: 280.ms, curve: Curves.easeOut);
  }
}

// ─── Unread badge ─────────────────────────────────────────────────────────

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.deepGreen,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ─── Error body ───────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppColors.errorRed,
            ),
            const SizedBox(height: 12),
            const T(
              'Failed to load messages',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: AppColors.charcoal,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              error,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: AppColors.gray),
            ),
          ],
        ),
      ),
    );
  }
}
