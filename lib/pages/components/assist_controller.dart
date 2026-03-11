import 'package:flutter/material.dart';
import 'package:onwards/pages/components/lang_assist.dart';

class AssistController {
  static final ValueNotifier<LanguageAssistLevel> current =
      ValueNotifier(LanguageAssistLevel.novice);

  static Future<void> load() async {
    current.value = await AssistLevelService.load();
  }

  static Future<void> set(LanguageAssistLevel level) async {
    await AssistLevelService.save(level);
    current.value = level;
  }
}