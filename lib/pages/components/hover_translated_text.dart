import 'package:flutter/material.dart';
import 'package:onwards/pages/components/lang_assist.dart';
import 'package:onwards/pages/components/translation_service.dart';
import '../constants.dart';

class ClickableTranslatedText extends StatefulWidget {
  final String text;
  final ColorProfile colorProfile;
  final LanguageAssistLevel? assistLevel;
  final String targetLanguage;

  const ClickableTranslatedText({
    super.key,
    required this.text,
    required this.colorProfile,
    required this.assistLevel,
    this.targetLanguage = 'es',
  });

  @override
  State<ClickableTranslatedText> createState() =>
      _ClickableTranslatedTextState();
}

class _ClickableTranslatedTextState extends State<ClickableTranslatedText> {
  final Map<String, String> _translationCache = {};
  final Set<String> _loadingWords = {};

  void _requestTranslation(String word) {
    if (_translationCache.containsKey(word) ||
        _loadingWords.contains(word)) return;

    _loadingWords.add(word);

    TranslationService.translate(
      word,
      targetLanguage: widget.targetLanguage,
    ).then((translated) {
      if (!mounted) return;
      setState(() {
        _translationCache[word] = translated;
        _loadingWords.remove(word);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.assistLevel != LanguageAssistLevel.novice) {
      return Text(
        widget.text,
        style: TextStyle(
          color: widget.colorProfile.textColor,
          fontSize: 30,
        ),
        textAlign: TextAlign.center,
      );
    }

    final tokens = RegExp(r'\S+|\s+')
        .allMatches(widget.text)
        .map((m) => m.group(0)!)
        .toList();

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        children: tokens.map((token) {
          if (token.trim().isEmpty) {
            return TextSpan(text: token);
          }

          final tooltipMessage = _translationCache[token] ??
              (_loadingWords.contains(token)
                  ? 'Translating...'
                  : 'Hover to translate');

          return WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: MouseRegion(
              cursor: SystemMouseCursors.help,
              onEnter: (_) => _requestTranslation(token),
              child: Tooltip(
                message: tooltipMessage,
                waitDuration: const Duration(milliseconds: 150),
                showDuration: const Duration(seconds: 3),
                decoration: BoxDecoration(
                  color: widget.colorProfile.headerColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                textStyle: TextStyle(
                  color: widget.colorProfile.contrastTextColor,
                  fontSize: 16,
                ),
                child: Text(
                  token,
                  style: TextStyle(
                    color: widget.colorProfile.buttonColor,
                    fontSize: 30,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
