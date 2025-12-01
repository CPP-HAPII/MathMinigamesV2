import 'package:shared_preferences/shared_preferences.dart';

enum LanguageAssistLevel {
  novice,
  intermediate,
  advanced,
}

extension LanguageAssistLevelExt on LanguageAssistLevel {
  String get label {
    switch (this) {
      case LanguageAssistLevel.novice:
        return "Novice";
      case LanguageAssistLevel.intermediate:
        return "Intermediate";
      case LanguageAssistLevel.advanced:
        return "Advanced";
    }
  }
}

class AssistLevelService {
  static const String _key = 'lang_assist_level';

  static Future<void> save(LanguageAssistLevel level) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, level.index);
  }

  static Future<LanguageAssistLevel> load() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt('lang_assist_level') ?? 0;
    return LanguageAssistLevel.values[index];
  }
}