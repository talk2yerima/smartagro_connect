import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../di/auth_providers.dart';
import 'ha_strings.dart';

/// Languages the app speaks. English is the source text; Hausa comes from
/// [haStrings], and anything not translated yet falls back to English.
enum AppLanguage {
  en('English', 'English'),
  ha('Hausa', 'Hausa');

  const AppLanguage(this.englishName, this.nativeName);
  final String englishName;
  final String nativeName;
}

/// The language in use. Kept here (not only in a provider) so [tr] works
/// anywhere, including outside widgets.
abstract final class I18n {
  static AppLanguage current = AppLanguage.en;
}

/// [en] in the current language. `{name}` placeholders are filled from
/// [args]: `tr('{n} listings', {'n': 3})`.
String tr(String en, [Map<String, Object?> args = const {}]) {
  var text = I18n.current == AppLanguage.ha ? (haStrings[en] ?? en) : en;
  if (args.isNotEmpty) {
    args.forEach((key, value) => text = text.replaceAll('{$key}', '$value'));
  }
  return text;
}

/// A [Text] whose English [data] is shown in the current language. Can be
/// `const`, unlike `Text(tr('…'))`.
class T extends StatelessWidget {
  const T(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap,
    this.textScaler,
    this.semanticsLabel,
  });

  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;
  final TextScaler? textScaler;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) => Text(
        tr(data),
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
        softWrap: softWrap,
        textScaler: textScaler,
        semanticsLabel: semanticsLabel,
      );
}

/// The chosen language, saved on this phone.
class LanguageController extends StateNotifier<AppLanguage> {
  LanguageController(this._prefs) : super(_read(_prefs)) {
    I18n.current = state;
  }

  final SharedPreferences _prefs;
  static const _key = 'app_language';

  static AppLanguage _read(SharedPreferences prefs) {
    final saved = prefs.getString(_key);
    return AppLanguage.values
        .firstWhere((l) => l.name == saved, orElse: () => AppLanguage.en);
  }

  Future<void> set(AppLanguage language) async {
    if (language == state) return;
    I18n.current = language;
    state = language;
    await _prefs.setString(_key, language.name);
  }
}

final languageProvider =
    StateNotifierProvider<LanguageController, AppLanguage>((ref) {
  return LanguageController(ref.watch(loadedSharedPreferencesProvider));
});

/// Rebuilds every screen (keeping where you are and what you typed) when
/// the language changes, so all text switches at once.
class LanguageRefresher extends ConsumerStatefulWidget {
  const LanguageRefresher({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<LanguageRefresher> createState() => _LanguageRefresherState();
}

class _LanguageRefresherState extends ConsumerState<LanguageRefresher> {
  @override
  Widget build(BuildContext context) {
    ref.listen<AppLanguage>(languageProvider, (_, __) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        void rebuild(Element e) {
          e.markNeedsBuild();
          e.visitChildren(rebuild);
        }

        (context as Element).visitChildren(rebuild);
      });
    });
    return widget.child;
  }
}
