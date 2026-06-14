import 'package:equatable/equatable.dart';

/// Live commodity quote row for dashboard + market screens.
class Commodity extends Equatable {
  const Commodity({
    required this.id,
    required this.name,
    required this.unit,
    required this.priceNgn,
    required this.changePct,
    required this.category,
  });

  final String id;
  final String name;
  final String unit;
  final int priceNgn;
  final double changePct;
  final String category;

  @override
  List<Object?> get props => [id];
}
