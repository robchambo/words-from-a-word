import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/language_mode.dart';

class SettingsProvider extends ChangeNotifier {
  LanguageMode _languageMode = LanguageMode.russian;
  LanguageMode get languageMode => _languageMode;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('language_mode');
    if (saved == 'english') {
      _languageMode = LanguageMode.english;
    } else {
      _languageMode = LanguageMode.russian;
    }
    notifyListeners();
  }

  Future<void> setLanguageMode(LanguageMode mode) async {
    _languageMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_mode', mode.name);
    notifyListeners();
  }
}
