import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/language_mode.dart';

class SettingsProvider extends ChangeNotifier {
  static const _kLanguageMode = 'language_mode';
  static const _kMuted = 'settings.muted';

  LanguageMode? _languageMode;
  LanguageMode? get languageMode => _languageMode;

  bool _muted = false;
  bool get muted => _muted;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kLanguageMode);
    if (saved == 'russian') {
      _languageMode = LanguageMode.russian;
    } else if (saved == 'english') {
      _languageMode = LanguageMode.english;
    }
    // else: no saved value — null means "first launch, no language chosen yet"
    _muted = prefs.getBool(_kMuted) ?? false;
    notifyListeners();
  }

  Future<void> setLanguageMode(LanguageMode mode) async {
    _languageMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLanguageMode, mode.name);
    notifyListeners();
  }

  Future<void> setMuted(bool value) async {
    if (_muted == value) return;
    _muted = value;
    notifyListeners();
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kMuted, value);
  }
}
