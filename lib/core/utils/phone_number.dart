/// Turns what Nigerians actually type into the international (E.164) form
/// Firebase needs, or null when it isn't a valid Nigerian mobile number.
///
/// Accepts "0803 658 2546", "08036582546", "803-658-2546", "2348036582546"
/// and "+234 803 658 2546"; all become "+2348036582546". Nigerian mobile
/// numbers are 10 digits after the country code and start with 7, 8 or 9.
String? normalizeNigerianPhone(String input) {
  var digits = input.replaceAll(RegExp(r'[^\d+]'), '');
  if (digits.startsWith('+')) {
    digits = digits.substring(1);
    if (!digits.startsWith('234')) return null; // another country
    digits = digits.substring(3);
  } else if (digits.startsWith('234') && digits.length == 13) {
    digits = digits.substring(3);
  } else if (digits.startsWith('0') && digits.length == 11) {
    digits = digits.substring(1);
  }
  if (!RegExp(r'^[789]\d{9}$').hasMatch(digits)) return null;
  return '+234$digits';
}

/// "+2348036582546" → "+234 803 658 2546", for showing back to people.
String formatNigerianPhone(String e164) {
  final m = RegExp(r'^\+234(\d{3})(\d{3})(\d{4})$').firstMatch(e164);
  if (m == null) return e164;
  return '+234 ${m[1]} ${m[2]} ${m[3]}';
}
