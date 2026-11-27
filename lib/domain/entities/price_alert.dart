/// "Tell me when [commodityName] rises above / falls below [targetNgn]."
/// Fires once (the backend switches it off), then shows as used.
class PriceAlert {
  const PriceAlert({
    required this.id,
    required this.commodityId,
    required this.targetNgn,
    required this.above,
    required this.active,
  });

  factory PriceAlert.fromMap(String id, Map<String, dynamic> m) => PriceAlert(
        id: id,
        commodityId: (m['commodityId'] as String?) ?? '',
        targetNgn: (m['targetNgn'] as num?)?.toInt() ?? 0,
        above: m['direction'] != 'below',
        active: m['active'] != false,
      );

  final String id;
  final String commodityId;
  final int targetNgn;

  /// True: notify when the price rises to or above the target.
  /// False: when it falls to or below it.
  final bool above;

  /// False once it has fired.
  final bool active;

  /// Rises above a target over today's price; falls below one under it.
  static bool directionFor({required int target, required int current}) =>
      target > current;
}
