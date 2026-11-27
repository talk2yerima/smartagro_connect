import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartagro_connect/core/i18n/ha_strings.dart';
import 'package:smartagro_connect/core/i18n/i18n.dart';

void main() {
  tearDown(() => I18n.current = AppLanguage.en);

  test('English is the source; Hausa comes from the list', () {
    I18n.current = AppLanguage.en;
    expect(tr('Orders'), 'Orders');
    I18n.current = AppLanguage.ha;
    expect(tr('Orders'), 'Oda');
    expect(tr('Messages'), 'Saƙonni');
  });

  test('missing Hausa falls back to English; placeholders are filled', () {
    I18n.current = AppLanguage.ha;
    expect(tr('Not translated yet'), 'Not translated yet');
    expect(tr('{n} kg left', {'n': 40}), '40 kg left');
  });

  test('every Hausa entry is non-empty and keeps placeholders', () {
    for (final e in haStrings.entries) {
      expect(e.value.trim(), isNotEmpty, reason: e.key);
      for (final m in RegExp(r'\{\w+\}').allMatches(e.key)) {
        expect(e.value, contains(m.group(0)), reason: e.key);
      }
    }
  });

  testWidgets('T shows the current language', (tester) async {
    I18n.current = AppLanguage.ha;
    await tester
        .pumpWidget(const MaterialApp(home: Scaffold(body: T('Explore'))));
    expect(find.text('Bincika'), findsOneWidget);
  });
}
