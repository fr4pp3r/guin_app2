import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide language preference backed by [SharedPreferences].
///
/// The selected language drives `MaterialApp.locale`. Supported values are
/// English (`en`), Tagalog/Filipino (`fil`) and Cebuano (`ceb`). The default
/// is English so first-run behavior is predictable.
class LocaleProvider extends ChangeNotifier {
  static const String _prefsKey = 'app_locale_code';

  /// Language codes the UI can switch between.
  static const List<String> supportedLanguageCodes = <String>['en', 'fil', 'ceb'];

  Locale _locale = const Locale('en');

  /// Currently selected locale (never null).
  Locale get locale => _locale;

  /// Language code currently selected, e.g. `en`, `fil`, `ceb`.
  String get languageCode => _locale.languageCode;

  LocaleProvider() {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_prefsKey);
      if (code != null && supportedLanguageCodes.contains(code)) {
        _locale = Locale(code);
        notifyListeners();
      }
    } catch (_) {
      // Preferences are best-effort; keep the English default on failure.
    }
  }

  /// Persist and apply a new language. Unknown codes are ignored.
  Future<void> setLanguage(String code) async {
    if (!supportedLanguageCodes.contains(code) || code == _locale.languageCode) {
      return;
    }
    _locale = Locale(code);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, code);
    } catch (_) {
      // Ignore persistence failures; the in-memory selection still applies.
    }
  }
}
