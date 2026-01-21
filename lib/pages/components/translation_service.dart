import 'package:translator/translator.dart';

class TranslationService {
  static final GoogleTranslator _translator = GoogleTranslator();

  static Future<String> translate(
    String text, {
    String targetLanguage = 'es',
  }) async {
    try {
      final translated =
          await _translator.translate(text, to: targetLanguage);
      return translated.text;
    } catch (e) {
      return 'Translation failed';
    }
  }
}
