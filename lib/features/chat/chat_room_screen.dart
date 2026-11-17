import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/di/auth_providers.dart';
import '../../core/di/firestore_providers.dart';
import '../../core/di/repositories_provider.dart';
import '../../core/utils/app_logger.dart';
import '../../domain/entities/chat_models.dart';
import '../../shared/widgets/app_avatar.dart';
import '../../shared/widgets/status_badge.dart';

// ---------------------------------------------------------------------------
// Local state: extra messages appended via the input bar
// ---------------------------------------------------------------------------
final _localMessagesProvider = StateProvider.autoDispose
    .family<List<ChatMessage>, String>((ref, threadId) => []);

// ---------------------------------------------------------------------------
// Date helper
// ---------------------------------------------------------------------------
String _formatDate(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final d = DateTime(dt.year, dt.month, dt.day);
  if (d == today) return 'Today';
  if (d == yesterday) return 'Yesterday';
  return DateFormat('MMM d, yyyy').format(dt);
}

String _formatTime(DateTime dt) => DateFormat('h:mm a').format(dt);

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

// ---------------------------------------------------------------------------
// ChatRoomScreen
// ---------------------------------------------------------------------------
class ChatRoomScreen extends ConsumerStatefulWidget {
  const ChatRoomScreen(
      {super.key, required this.threadId, this.peerName, this.peerId});

  final String threadId;
  final String? peerName;
  final String? peerId;

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authSessionProvider);
      final firestore = ref.read(firestoreServiceProvider);
      if (user != null && firestore.isAvailable) {
        firestore.markThreadRead(widget.threadId, user.id);
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final threadsAsync = ref.watch(chatThreadsProvider);
    final messagesAsync = ref.watch(chatMessagesProvider(widget.threadId));
    final localMsgs = ref.watch(_localMessagesProvider(widget.threadId));

    // Resolve thread info
    final thread = threadsAsync.whenData(
      (threads) => threads.cast<ChatThread?>().firstWhere(
            (t) => t?.id == widget.threadId,
            orElse: () => null,
          ),
    );

    final participantName =
        thread.valueOrNull?.peerName ?? widget.peerName ?? 'Conversation';
    final participantRole = thread.valueOrNull?.peerRole ?? '';
    final peerId = thread.valueOrNull?.peerId ?? widget.peerId;
    final peerLastReadAt = thread.valueOrNull?.peerLastReadAt;
    final isTyping = peerId != null
        ? ref
                .watch(peerTypingProvider('${widget.threadId}|$peerId'))
                .valueOrNull ??
            false
        : false;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.softWhite,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Row(
          children: [
            AppAvatar(
              name: participantName,
              color: AppColors.emerald,
              radius: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    participantName,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.charcoal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (participantRole.isNotEmpty)
                    StatusBadge(
                      label: participantRole,
                      color: AppColors.freshGreen,
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: const [SizedBox(width: 4)],
      ),
      body: Column(
        children: [
          // ── Message list ──────────────────────────────────────────
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                  color: AppColors.deepGreen,
                ),
              ),
              error: (e, _) => Center(
                child: Text(
                  'Could not load messages',
                  style: TextStyle(
                    color:
                        isDark ? AppColors.darkTextSecondary : AppColors.gray,
                  ),
                ),
              ),
              data: (fetchedMsgs) {
                // Combine fetched + local, sorted oldest-first
                final all = [
                  ...fetchedMsgs,
                  ...localMsgs,
                ]..sort((a, b) => a.sentAt.compareTo(b.sentAt));

                if (all.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 56,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.borderLight,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.gray,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Send a message to start the conversation',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.gray,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  color: AppColors.deepGreen,
                  onRefresh: () async {
                    ref.invalidate(chatMessagesProvider(widget.threadId));
                  },
                  child: ListView.builder(
                    controller: _scroll,
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    itemCount: all.length,
                    itemBuilder: (context, reversedIndex) {
                      final i = all.length - 1 - reversedIndex;
                      final msg = all[i];
                      final prev = i > 0 ? all[i - 1] : null;
                      final next = i < all.length - 1 ? all[i + 1] : null;

                      final isFirst = prev == null ||
                          prev.fromMe != msg.fromMe ||
                          !_sameDay(prev.sentAt, msg.sentAt);
                      final isLast = next == null ||
                          next.fromMe != msg.fromMe ||
                          !_sameDay(next.sentAt, msg.sentAt);

                      final showDate =
                          prev == null || !_sameDay(prev.sentAt, msg.sentAt);

                      final isRead = msg.fromMe &&
                          !msg.id.startsWith('local_') &&
                          peerLastReadAt != null &&
                          !peerLastReadAt.isBefore(msg.sentAt);

                      return Column(
                        children: [
                          if (showDate)
                            _DateSeparator(label: _formatDate(msg.sentAt)),
                          _ChatBubble(
                            message: msg,
                            isDark: isDark,
                            isFirst: isFirst,
                            isLast: isLast,
                            isRead: isRead,
                            animIndex: reversedIndex,
                          ),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
          ),

          // ── Typing indicator ──────────────────────────────────────
          if (isTyping) const _TypingIndicator(),

          // ── Input bar ─────────────────────────────────────────────
          _InputBar(
            threadId: widget.threadId,
            isDark: isDark,
            onSent: _scrollToBottom,
            peerId: peerId,
            peerName: participantName,
            peerRole: participantRole,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Date Separator
// ---------------------------------------------------------------------------
class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: isDark ? AppColors.darkBorder : AppColors.borderLight,
              thickness: 1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.gray,
                ),
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: isDark ? AppColors.darkBorder : AppColors.borderLight,
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chat Bubble
// ---------------------------------------------------------------------------
class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.message,
    required this.isDark,
    required this.isFirst,
    required this.isLast,
    required this.isRead,
    required this.animIndex,
  });

  final ChatMessage message;
  final bool isDark;
  final bool isFirst;
  final bool isLast;
  final bool isRead;
  final int animIndex;

  BorderRadius _radius() {
    if (message.fromMe) {
      // Sent: top-left, top-right, bottom-left, bottom-right
      return BorderRadius.only(
        topLeft: const Radius.circular(12),
        topRight: Radius.circular(isFirst ? 12 : 4),
        bottomLeft: const Radius.circular(12),
        bottomRight: Radius.circular(isLast ? 0 : 4),
      );
    } else {
      return BorderRadius.only(
        topLeft: Radius.circular(isFirst ? 12 : 4),
        topRight: const Radius.circular(12),
        bottomLeft: Radius.circular(isLast ? 0 : 4),
        bottomRight: const Radius.circular(12),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fromMe = message.fromMe;

    final bubbleColor = fromMe
        ? AppColors.deepGreen
        : (isDark ? AppColors.cardDark : Colors.white);

    final textColor = fromMe
        ? Colors.white
        : (isDark ? AppColors.darkTextPrimary : AppColors.charcoal);

    final timestampColor = fromMe
        ? Colors.white.withValues(alpha: 0.65)
        : (isDark ? AppColors.darkTextSecondary : AppColors.gray);

    Widget bubbleContent;
    switch (message.kind) {
      case ChatMessageKind.image:
        bubbleContent = message.imageUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: message.imageUrl!,
                  width: 220,
                  height: 180,
                  fit: BoxFit.cover,
                  placeholder: (ctx, _) => Container(
                    width: 220,
                    height: 180,
                    color: Colors.grey.withValues(alpha: 0.2),
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (ctx, _, __) => Container(
                    width: 220,
                    height: 180,
                    color: Colors.grey.withValues(alpha: 0.2),
                    child: const Icon(Icons.broken_image_outlined),
                  ),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.image_outlined, size: 18, color: textColor),
                  const SizedBox(width: 6),
                  Text(
                    'Image',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              );
      case ChatMessageKind.voice:
        bubbleContent = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.graphic_eq_rounded, size: 18, color: textColor),
            const SizedBox(width: 6),
            Text(
              'Voice message',
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        );
      case ChatMessageKind.text:
        bubbleContent = Text(
          message.text,
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            height: 1.4,
          ),
        );
    }

    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.72,
      ),
      margin: EdgeInsets.only(
        top: isFirst ? 6 : 2,
        bottom: isLast ? 6 : 2,
        left: fromMe ? 48 : 0,
        right: fromMe ? 0 : 48,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: _radius(),
        border: fromMe
            ? null
            : Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.borderLight,
              ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            fromMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          bubbleContent,
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatTime(message.sentAt),
                style: TextStyle(
                  fontSize: 10,
                  color: timestampColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (fromMe) ...[
                const SizedBox(width: 3),
                Icon(
                  isRead ? Icons.done_all_rounded : Icons.done_rounded,
                  size: 12,
                  color: isRead
                      ? AppColors.mintGreen
                      : Colors.white.withValues(alpha: 0.55),
                ),
              ],
            ],
          ),
        ],
      ),
    );

    return Align(
      alignment: fromMe ? Alignment.centerRight : Alignment.centerLeft,
      child: bubble
          .animate(delay: (30 * (animIndex % 10)).ms)
          .fadeIn(duration: 200.ms)
          .scale(
            begin: const Offset(0.97, 0.97),
            end: const Offset(1, 1),
            duration: 200.ms,
            curve: Curves.easeOut,
          ),
    );
  }
}

// ---------------------------------------------------------------------------
// Typing Indicator
// ---------------------------------------------------------------------------
class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'typing ',
            style: TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: isDark ? AppColors.darkTextSecondary : AppColors.gray,
            ),
          ),
          const _Dot(index: 0),
          const _Dot(index: 1),
          const _Dot(index: 2),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 5,
      height: 5,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkTextSecondary : AppColors.gray,
        shape: BoxShape.circle,
      ),
    )
        .animate(
          delay: (index * 180).ms,
          onPlay: (c) => c.repeat(reverse: true),
        )
        .moveY(
          begin: 0,
          end: -4,
          duration: 380.ms,
          curve: Curves.easeInOut,
        );
  }
}

// ---------------------------------------------------------------------------
// Input Bar
// ---------------------------------------------------------------------------
class _InputBar extends ConsumerStatefulWidget {
  const _InputBar({
    required this.threadId,
    required this.isDark,
    required this.onSent,
    this.peerId,
    this.peerName,
    this.peerRole,
  });

  final String threadId;
  final bool isDark;
  final VoidCallback onSent;
  final String? peerId;
  final String? peerName;
  final String? peerRole;

  @override
  ConsumerState<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends ConsumerState<_InputBar> {
  final _controller = TextEditingController();
  bool _hasText = false;
  bool _sent = false;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _clearTyping();
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final has = _controller.text.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
    if (!has) {
      _typingTimer?.cancel();
      _clearTyping();
      return;
    }
    _typingTimer?.cancel();
    _setTyping(true);
    _typingTimer = Timer(const Duration(seconds: 3), _clearTyping);
  }

  void _setTyping(bool isTyping) {
    if (!mounted) return;
    final user = ref.read(authSessionProvider);
    final firestore = ref.read(firestoreServiceProvider);
    if (user == null || !firestore.isAvailable) return;
    firestore.setTyping(widget.threadId, user.id, isTyping);
  }

  void _clearTyping() => _setTyping(false);

  Future<void> _pickAndSendImage() async {
    final user = ref.read(authSessionProvider);
    final firestore = ref.read(firestoreServiceProvider);
    if (user == null || !firestore.isAvailable || widget.peerId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Image sending requires a live connection')),
        );
      }
      return;
    }
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (picked == null || !mounted) return;
    HapticFeedback.lightImpact();

    final ts = DateTime.now();
    final msgId = firestore.newMessageId(widget.threadId);
    final localId = 'local_img_${ts.millisecondsSinceEpoch}';
    final placeholder = ChatMessage(
      id: localId,
      threadId: widget.threadId,
      fromMe: true,
      text: '',
      sentAt: ts,
      kind: ChatMessageKind.image,
    );
    ref
        .read(_localMessagesProvider(widget.threadId).notifier)
        .update((s) => [...s, placeholder]);
    widget.onSent();

    try {
      Uint8List? bytes;
      if (!kIsWeb &&
          (Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
        bytes = await FlutterImageCompress.compressWithFile(
          picked.path,
          minWidth: 1024,
          minHeight: 1024,
          quality: 82,
        );
      }
      final storageRef = FirebaseStorage.instance
          .ref('chat_images/${widget.threadId}/$msgId.jpg');
      if (bytes != null) {
        await storageRef.putData(
            bytes, SettableMetadata(contentType: 'image/jpeg'));
      } else {
        await storageRef.putFile(File(picked.path));
      }
      final imageUrl = await storageRef.getDownloadURL();
      await firestore.sendChatMessage(
        threadId: widget.threadId,
        fromId: user.id,
        fromName: user.name,
        fromRole: user.role.name,
        peerId: widget.peerId!,
        peerName: widget.peerName ?? 'Unknown',
        peerRole: widget.peerRole ?? '',
        text: '',
        imageUrl: imageUrl,
      );
      if (mounted) {
        ref
            .read(_localMessagesProvider(widget.threadId).notifier)
            .update((s) => s.where((m) => m.id != localId).toList());
      }
    } catch (e) {
      log.e('[Chat] pickAndSendImage failed', error: e);
      if (mounted) {
        ref
            .read(_localMessagesProvider(widget.threadId).notifier)
            .update((s) => s.where((m) => m.id != localId).toList());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send image')),
        );
      }
    }
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _typingTimer?.cancel();
    _clearTyping();

    HapticFeedback.lightImpact();

    final ts = DateTime.now();
    final localId = 'local_${ts.millisecondsSinceEpoch}';
    final newMsg = ChatMessage(
      id: localId,
      threadId: widget.threadId,
      fromMe: true,
      text: text,
      sentAt: ts,
      kind: ChatMessageKind.text,
    );

    ref
        .read(_localMessagesProvider(widget.threadId).notifier)
        .update((state) => [...state, newMsg]);

    _controller.clear();
    widget.onSent();

    // Morph send → checkmark → send
    setState(() => _sent = true);
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _sent = false);
    });

    // Persist to Firestore; remove optimistic message once confirmed
    final user = ref.read(authSessionProvider);
    final firestore = ref.read(firestoreServiceProvider);
    if (user != null && firestore.isAvailable && widget.peerId != null) {
      () async {
        try {
          await firestore.sendChatMessage(
            threadId: widget.threadId,
            fromId: user.id,
            fromName: user.name,
            fromRole: user.role.name,
            peerId: widget.peerId!,
            peerName: widget.peerName ?? 'Unknown',
            peerRole: widget.peerRole ?? '',
            text: text,
          );
          if (mounted) {
            ref
                .read(_localMessagesProvider(widget.threadId).notifier)
                .update((s) => s.where((m) => m.id != localId).toList());
          }
        } catch (e) {
          log.e('[Chat] sendChatMessage failed', error: e);
          if (!mounted) return;
          // Don't leave a bubble that looks delivered: take it back out and
          // put the text back so the person can try again.
          ref
              .read(_localMessagesProvider(widget.threadId).notifier)
              .update((s) => s.where((m) => m.id != localId).toList());
          if (_controller.text.isEmpty) _controller.text = text;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Message not sent. Check your connection and '
                  'tap send to try again.'),
            ),
          );
        }
      }();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Attach icon
              IconButton(
                icon: Icon(
                  Icons.attach_file_rounded,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.gray,
                ),
                tooltip: 'Send image',
                onPressed: _pickAndSendImage,
              ),

              // Text field
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 120),
                  child: TextField(
                    controller: _controller,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.charcoal,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Type a message…',
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.gray,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.borderLight,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.borderLight,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(
                          color: AppColors.deepGreen,
                          width: 1.5,
                        ),
                      ),
                      filled: true,
                      fillColor: isDark
                          ? AppColors.darkSurface
                          : AppColors.surfaceLight,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Send button
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _hasText
                    ? GestureDetector(
                        onTap: _send,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          key: const ValueKey('send'),
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _sent
                                ? AppColors.mintGreen
                                : AppColors.deepGreen,
                            shape: BoxShape.circle,
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            transitionBuilder: (child, anim) =>
                                ScaleTransition(scale: anim, child: child),
                            child: Icon(
                              _sent ? Icons.check_rounded : Icons.send_rounded,
                              key: ValueKey(_sent),
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      )
                    : Container(
                        key: const ValueKey('mic'),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurface
                              : AppColors.surfaceLight,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.borderLight,
                          ),
                        ),
                        child: Icon(
                          Icons.mic_none_rounded,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.gray,
                          size: 20,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
