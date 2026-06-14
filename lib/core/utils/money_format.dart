import 'package:intl/intl.dart';

/// Formats Nigerian Naira compactly for marketplace UI.
String formatNgn(num value) {
  return NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0)
      .format(value);
}
