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
  });

  final String id;
  final String peerId;
  final String peerName;
  final String peerRole;
  final String lastMessage;
  final DateTime updatedAt;
  final int unread;

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
  });

  final String id;
  final String threadId;
  final bool fromMe;
  final String text;
  final DateTime sentAt;
  final ChatMessageKind kind;

  @override
  List<Object?> get props => [id];
}
