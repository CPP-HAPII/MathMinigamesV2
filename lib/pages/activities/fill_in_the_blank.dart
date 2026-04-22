import 'dart:math';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:onwards/pages/activities/game_page.dart';
import 'package:onwards/pages/components/calculator.dart';
import 'package:onwards/pages/components/progress_bar.dart';
import 'package:onwards/pages/components/skip.dart';
import 'package:onwards/pages/constants.dart';
import 'package:onwards/pages/game_data.dart';
import 'package:onwards/pages/home.dart';
import 'package:onwards/pages/score_display.dart';
import 'package:onwards/pages/translation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:onwards/pages/components/lang_assist.dart';
import 'package:onwards/pages/components/hover_translated_text.dart';
import 'package:onwards/pages/components/theme_controller.dart';


const FillBlanksGameData dummyData = FillBlanksGameData(displayedProblem: "", multiAcceptedAnswers: [], writtenPrompt: "", blankForm: "", optionList: [], skills: []);

class FillInActivityScreen extends StatelessWidget {
  final FillBlanksGameData fillBlanksGameData;
  final bool fromLevelSelect;
  final LanguageAssistLevel? langAssist;

  const FillInActivityScreen({
    super.key,
    this.fillBlanksGameData = dummyData,
    this.fromLevelSelect = false,
    this.langAssist,
  });

  const FillInActivityScreen.fromLevelSelect({required FillBlanksGameData fillData, super.key, this.langAssist}) : 
    fillBlanksGameData = fillData,
    fromLevelSelect = true;

  @override
  Widget build(BuildContext context) {
    FillBlanksGameData randomGameData = gameDataBank.getRandomFillBlanksElement();
    return ValueListenableBuilder<ColorProfile>(
      valueListenable: ThemeController.current,
      builder: (context, colorProfile, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              'Fill in the Blank Game',
              style: TextStyle(color: colorProfile.textColor),
            ),
            backgroundColor: colorProfile.headerColor,
            actions: const [ScoreDisplayAction(), CalcButton()],
            automaticallyImplyLeading: false,
          ),
          body: Container(
            decoration: colorProfile.backBoxDecoration,
            padding: const EdgeInsets.only(top: 40),
            child: !fromLevelSelect
                ? GameForm(
                    answers: randomGameData.multiAcceptedAnswers,
                    questionLabel: randomGameData.displayedProblem,
                    blankQuestLabel: randomGameData.blankForm,
                    maxSelectedAnswers: randomGameData.getMinSelection(),
                    buttonOptions: randomGameData.optionList,
                    colorProfile: colorProfile,
                    skills: randomGameData.skills,
                    id: randomGameData.id,
                    langAssist: langAssist,
                  )
                : GameForm(
                    answers: fillBlanksGameData.multiAcceptedAnswers,
                    questionLabel: fillBlanksGameData.displayedProblem,
                    blankQuestLabel: fillBlanksGameData.blankForm,
                    maxSelectedAnswers: fillBlanksGameData.getMinSelection(),
                    buttonOptions: fillBlanksGameData.optionList,
                    colorProfile: colorProfile,
                    skills: fillBlanksGameData.skills,
                    id: fillBlanksGameData.id,
                    langAssist: langAssist,
                  ),
          ),
        );
      },
    );
  }
}

// Show this game's unique game form using the data
// passed from GameData. The idea is to have the game
// move to the next question after the dialog, using context
// to pass the info over
class GameForm extends GamePage {
  const GameForm({
    super.key,
    super.colorProfile,
    required this.answers, 
    required this.questionLabel,
    required this.blankQuestLabel,
    required this.maxSelectedAnswers,
    required this.buttonOptions,
    required this.skills,
    required this.id,
    required this.langAssist,
  });

  final String questionLabel;
  final List<String> answers;
  final String blankQuestLabel;
  final int maxSelectedAnswers;
  final List<String> buttonOptions;
  final List<String> skills;
  final String id;
  final LanguageAssistLevel? langAssist;

  @override
  GameFormState createState() => GameFormState();
}

class GameFormState extends GamePageState<GameForm> {
  final List<String> _selectedAnswers = [];
  int maxSelection = 0;
  int currentCount = 0;
  late FlutterTts flutterTts;
  late LanguageAssistLevel? assistLevel;

  @override
  void initState() {
    super.initState();
    maxSelection = widget.maxSelectedAnswers;
    flutterTts = FlutterTts();
    assistLevel = widget.langAssist;
    logger.i("GameForm received assist level: $assistLevel");
  }

  @override
  void dispose() {
    logger.i("Finihing up and disposing Typing Game...");
    // add skills from game for database
    List<String> currentSkills = [];
    for (String skill in widget.skills) {
      currentSkills.add(skill);
    }
    setSkills(currentSkills);
    setQuestionId(widget.id);
    super.dispose();
  }

  void _speakQuestion() async {
    try {
      await flutterTts.setLanguage('en-US');
    } catch (_) {}
    await flutterTts.setPitch(1.0);
    await flutterTts.setSpeechRate(1.0);
    await flutterTts.speak(widget.questionLabel);
  }

  bool validateAnswer() {
    if (currentCount < widget.maxSelectedAnswers) {
      logger.d("Not enough answers are selected, could not validate");
      return false;
    }

    if (_selectedAnswers.length != widget.answers.length) {
      logger.d(
        "Answer length mismatch. Selected ${_selectedAnswers.length}, expected ${widget.answers.length}",
      );
      return false;
    }

    bool isCorrect = true;
    for (int i = 0; i < _selectedAnswers.length; i++) {
      if (_selectedAnswers[i] != widget.answers[i]) {
        isCorrect = false;
        logger.d("Correct answer did not match at: ${widget.answers[i]}");
      }
    }
    logger.d("validated answer");
    return isCorrect;
  }

  List<Widget> renderConditionalLabels(List<String> splitter) {
    List<Widget> widgets =[];
    int countForSelected = 0;
    for (String part in splitter) {
      if (part.contains("_")) {
        if (_selectedAnswers.isNotEmpty && countForSelected < _selectedAnswers.length) {
          widgets.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5), 
              child: Text(
                _selectedAnswers[countForSelected],
                style: TextStyle(
                  fontSize: 18.0,
                  color: widget.colorProfile.textColor
                ),
              )
            )
          );
          countForSelected += 1;
        } else {
          widgets.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5), 
              child: Text(
                part,
                style: TextStyle(
                  fontSize: 18.0,
                  color: widget.colorProfile.textColor
                ),
              ),
            )
          );
        }
      }
      else {
          widgets.add(Padding(
            padding: const EdgeInsets.symmetric(vertical: 5), 
            child: Text(
              part,
              style: TextStyle(
                fontSize: 18.0,
                color: widget.colorProfile.textColor
              ),
            ),
          )
        );
      }
      widgets.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 5), 
          child: Text(
            " ",
            style: TextStyle(
              fontSize: 18.0,
              color: widget.colorProfile.textColor
            ),
          ),
        )
      );
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    // List<String> selectedAnswers = [];
    // This is the data of multiple games
    List<Widget> dynamicButtonList = <Widget> [];
    List<String> splitter = widget.blankQuestLabel.split(" ");
    bool isValid;

    for (String option in widget.buttonOptions) {
      ElevatedButton button = ElevatedButton(
        onPressed: () => {
          setState(() {
            if (currentCount < maxSelection) {
              _selectedAnswers.add(option);
              currentCount += 1;
            }
          })
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: widget.colorProfile.buttonColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)
          ),
          padding: const EdgeInsets.symmetric(
            vertical: 8,
            horizontal: 24
          ),
        ),
        child: Text(
          option, 
          style: TextStyle(color: widget.colorProfile.textColor),
        ),
      );
      Padding padding = Padding(
        padding: const EdgeInsets.all(8.0),
        child: button,
      );
      dynamicButtonList.add(padding);
    }
    
    // Render the form here
    return Container(
      color: Colors.transparent,
      child: Stack(
        children: [
          addConfettiBlasters(),
          SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.1),
                buildTextCard(
                  profile: widget.colorProfile,
                  child: Text(
                    "Use the blocks below to form the written form of the expression:",
                    style: TextStyle(
                      color: widget.colorProfile.textColor,
                      fontSize: 30,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                buildTextCard(
                  profile: widget.colorProfile,
                  child: HoverTranslatedText(
                    text: widget.questionLabel,
                    colorProfile: widget.colorProfile,
                    assistLevel: assistLevel,
                    onTranslationHover: () => recordAssistUsage(
                      LanguageAssistLevel.advanced,
                      'hover_translation',
                    ),
                  ),
                ),
                if (assistLevel == LanguageAssistLevel.novice ||
                    assistLevel == LanguageAssistLevel.intermediate)
                  buildTextCard(
                    profile: widget.colorProfile,
                    maxWidth: 560,
                    child: Column(
                      children: [
                        if (assistLevel == LanguageAssistLevel.novice)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: ElevatedButton(
                              onPressed: _speakQuestion,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: widget.colorProfile.buttonColor,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                              ),
                              child: Text(
                                'Hear Question',
                                style: TextStyle(color: widget.colorProfile.textColor),
                              ),
                            ),
                          ),
                        TranslateButtonAndText(
                          sourceText: widget.questionLabel,
                          colorProfile: widget.colorProfile,
                          speakOnTranslate: true,
                          targetLanguage: 'es',
                          autoTranslate: assistLevel == LanguageAssistLevel.novice,
                          onTranslationShown: () => recordAssistUsage(
                            LanguageAssistLevel.intermediate,
                            'translation_displayed',
                          ),
                          onTranslationSpoken: () => recordAssistUsage(
                            LanguageAssistLevel.novice,
                            'translation_heard',
                          ),
                        ),
                      ],
                    ),
                  ),
                buildTextCard(
                  profile: widget.colorProfile,
                  maxWidth: 820,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: Column(
                    children: [
                      Text(
                        'Your answer',
                        style: TextStyle(
                          color: widget.colorProfile.textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: renderConditionalLabels(splitter),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    children: dynamicButtonList,
                  ),
                ),
                Padding(
                      padding: const EdgeInsets.only(bottom: 64),
                      child: SizedBox(
                        width: double.infinity, 
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                  child: TextButton(
                                    onPressed: () => {
                                      isValid = validateAnswer(),
                                      if (isValid) {
                                        showGameOverlay(-1)
                                      } else {
                                        showCorrectDialog(isValid, widget.colorProfile, -1)
                                      }
                                    }, 
                                    style: ButtonStyle(
                                      backgroundColor: WidgetStatePropertyAll(widget.colorProfile.checkAnswerButtonColor),
                                    ),
                                    child: Text(
                                      'Check Answer',
                                      style: TextStyle(color: widget.colorProfile.textColor),
                                    )
                                  )
                                ),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      currentCount = 0;
                                      _selectedAnswers.clear();
                                    });
                                  },
                                  style: ButtonStyle(
                                    backgroundColor: WidgetStatePropertyAll(widget.colorProfile.clearAnswerButtonColor),
                                  ),
                                  child: Text(
                                    'Clear all answers',
                                    style: TextStyle(color: widget.colorProfile.textColor),
                                    )
                                  )
                              ],
                            ),
                            const Positioned(
                              right: 8,
                              child: SizedBox(
                                height: 32,
                                child: Skip(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
              ],
            ),
            ),
          const Align(
            alignment: Alignment.bottomCenter,
            child: ProgressBar(),
          )
        ],
      )
    );
    
  }
}
