import 'package:flutter/widgets.dart';
import 'generated/app_localizations.dart';
import 'generated/app_localizations_en.dart';

/// Context-free access to the active localization for code paths that have no
/// [BuildContext] available (validators, helpers, services, model getters).
///
/// [current] is refreshed from `MainApp`'s builder whenever the app locale
/// changes, so lookups always match the selected language. Before the first
/// build (or outside the widget tree, e.g. in tests) it falls back to English.
class AppL10n {
  AppL10n._();

  static AppLocalizations? _current;
  static final AppLocalizations _fallback = AppLocalizationsEn('en');

  static AppLocalizations get current => _current ?? _fallback;

  static set current(AppLocalizations value) => _current = value;
}