import 'package:equatable/equatable.dart';

class NearbyBuyer extends Equatable {
  const NearbyBuyer({
    required this.id,
    required this.name,
    required this.type,
    required this.state,
    required this.distanceKm,
    required this.rating,
    required this.verified,
  });

  final String id;
  final String name;
  final String type;
  final String state;
  final int distanceKm;
  final double rating;
  final bool verified;

  @override
  List<Object?> get props => [id];
}
