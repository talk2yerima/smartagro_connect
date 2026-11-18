import 'package:flutter_test/flutter_test.dart';
import 'package:smartagro_connect/core/utils/phone_number.dart';

void main() {
  test('accepts the ways Nigerians write mobile numbers', () {
    for (final input in [
      '08036582546',
      '0803 658 2546',
      '0803-658-2546',
      '8036582546',
      '2348036582546',
      '+2348036582546',
      '+234 803 658 2546',
      ' (0803) 658 2546 ',
    ]) {
      expect(normalizeNigerianPhone(input), '+2348036582546', reason: input);
    }
  });

  test('accepts 07x and 09x networks', () {
    expect(normalizeNigerianPhone('07012345678'), '+2347012345678');
    expect(normalizeNigerianPhone('09087654321'), '+2349087654321');
  });

  test('rejects too short, too long, landlines and other countries', () {
    for (final input in [
      '',
      '0803658254',
      '080365825461',
      '01234567890', // Lagos landline style
      '+447700900123', // UK
      'hello',
    ]) {
      expect(normalizeNigerianPhone(input), isNull, reason: input);
    }
  });

  test('formats a number for display', () {
    expect(formatNigerianPhone('+2348036582546'), '+234 803 658 2546');
    expect(formatNigerianPhone('+15551234'), '+15551234');
  });
}
