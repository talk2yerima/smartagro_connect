import 'package:equatable/equatable.dart';

enum ChatMessageKind { text, image, voice }

class ChatThread extends Equatable {
  const ChatThread({
    required this.id,
    required this.peerId,
    required this.peerName,
    required this.peerRole,
    required this.lastMessage,
    required this.updatedAt,
    required this.unread,
    this.peerLastReadAt,
  });

  final String id;
  final String peerId;
  final String peerName;
  final String peerRole;
  final String lastMessage;
  final DateTime updatedAt;
  final int unread;

  /// When the peer last marked this thread as read.
  /// Used to show ✓✓ (blue) on sent messages the peer has seen.
  final DateTime? peerLastReadAt;

  @override
  List<Object?> get props => [id];
}

class ChatMessage extends Equatable {
  const ChatMessage({
    required this.id,
    required this.threadId,
    required this.fromMe,
    required this.text,
    required this.sentAt,
    required this.kind,
    this.imageUrl,
    this.audioUrl,
    this.duration,
  });

  final String id;
  final String threadId;
  final bool fromMe;
  final String text;
  final DateTime sentAt;
  final ChatMessageKind kind;

  /// Download URL for image messages (kind == ChatMessageKind.image).
  final String? imageUrl;

  /// Voice notes: download URL (or a local file path while sending).
  final String? audioUrl;

  /// Voice notes: length of the recording.
  final Duration? duration;

  @override
  List<Object?> get props => [id];
}
