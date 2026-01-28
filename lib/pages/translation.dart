import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:translator/translator.dart';
import 'package:onwards/pages/constants.dart';

class TranslateButtonAndText extends StatefulWidget {
  const TranslateButtonAndText({
    super.key,
    required this.sourceText,
    this.colorProfile = lightFlavor,
    this.speakOnTranslate = false,
    this.targetLanguage = 'es',
    this.autoTranslate = false,
  });

  final String sourceText;
  final ColorProfile colorProfile;
  final bool speakOnTranslate;
  final String targetLanguage;
  final bool autoTranslate;

  @override
  State<TranslateButtonAndText> createState() => _TranslateButtonAndTextState();
}

class _TranslateButtonAndTextState extends State<TranslateButtonAndText> {
  final GoogleTranslator _translator = GoogleTranslator();
  final FlutterTts _flutterTts = FlutterTts();
  String? _translation;
  bool _loading = false;

  @override
  void initState() {
    super.initState();

    if (widget.autoTranslate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _doTranslate();
      });
    }
  }

  Future<void> _doTranslate() async {
    if (_loading) return;
    setState(() {
      _loading = true;
    });
    try {
      final translated = await _translator.translate(widget.sourceText, to: widget.targetLanguage);
      setState(() {
        _translation = translated.toString();
      });
    } catch (e) {
      setState(() {
        _translation = 'Translation failed';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _speak(String text) async {
    await _flutterTts.setLanguage(widget.targetLanguage);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(1.0);
    await _flutterTts.speak(text);
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _doTranslate,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.colorProfile.headerColor,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: _loading
                  ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: widget.colorProfile.contrastTextColor, strokeWidth: 2))
                  : Text('Translate', style: TextStyle(color: widget.colorProfile.contrastTextColor)),
            ),
            const SizedBox(width: 8),
            if (_translation != null && _translation!.isNotEmpty)
              ElevatedButton(
                onPressed: () => _speak(_translation!),
                style: ElevatedButton.styleFrom(backgroundColor: widget.colorProfile.buttonColor),
                child: Text('Play translation', style: TextStyle(color: widget.colorProfile.contrastTextColor)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_translation != null) Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            _translation!,
            style: TextStyle(color: widget.colorProfile.textColor, fontSize: 18),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
