import 'package:equatable/equatable.dart';

class AppNotification extends Equatable {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.type,
    this.read = false,
    this.route,
  });

  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final String type;
  final bool read;

  /// Screen to open when tapped, e.g. '/orders'. Null for info-only.
  final String? route;

  @override
  List<Object?> get props => [id];
}
