
// ignore_for_file: non_constant_identifier_names
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:onwards/pages/activities/game_page.dart';
import 'package:onwards/pages/components/calculator.dart';
import 'package:onwards/pages/components/progress_bar.dart';
import 'package:onwards/pages/components/skip.dart';
import 'package:onwards/pages/game_data.dart';
import 'package:onwards/pages/home.dart';
import 'package:onwards/pages/score_display.dart';
import 'package:onwards/pages/translation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:onwards/pages/components/lang_assist.dart';
import 'package:onwards/pages/components/hover_translated_text.dart';
import 'package:onwards/pages/components/theme_controller.dart';

import '../constants.dart';

const JumbleGameData dummyData = JumbleGameData(displayedProblem: '', multiAcceptedAnswers: [], optionList: [], skills: []);

class JumbleActivityScreen extends StatelessWidget {
  final JumbleGameData jumbleGameData;
  final bool fromLevelSelect;
  final LanguageAssistLevel? langAssist;

  const JumbleActivityScreen({
    super.key,
    this.jumbleGameData = dummyData,
    this.fromLevelSelect = false,
    this.langAssist,
  });

  const JumbleActivityScreen.fromLevelSelect({required JumbleGameData jumbleData, super.key, this.langAssist}) :
    jumbleGameData = jumbleData,
    fromLevelSelect = true;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ColorProfile>(
      valueListenable: ThemeController.current,
      builder: (context, colorProfile, _) {
        JumbleGameData randomGameData = gameDataBank.getRandomJumbleElement();
        return Scaffold(
          appBar: AppBar(
            title: Text('Word Jumble Game', style: TextStyle(color: colorProfile.textColor)),
            backgroundColor: colorProfile.headerColor,
            actions: const [ ScoreDisplayAction(), CalcButton()],
            automaticallyImplyLeading: false,
          ),
          body: Container(
            decoration: colorProfile.backBoxDecoration,
            padding: const EdgeInsets.only(top: 40),
            child: !fromLevelSelect ?
              GameForm(
                // Using the bank's random data
                answers: randomGameData.multiAcceptedAnswers, 
                questionLabel: randomGameData.displayedProblem, 
                maxSelectedAnswers: randomGameData.getMinSelection(), 
                buttonOptions: randomGameData.optionList,
                titleQuestion: randomGameData.writtenPrompt,
                showArithmitic: true,
                skills: randomGameData.skills,
                scoreValue: randomGameData.score,
                id: randomGameData.id,
                langAssist: langAssist,
              ) :
              GameForm(
                // using the passed gameData
                answers: jumbleGameData.multiAcceptedAnswers, 
                questionLabel: jumbleGameData.displayedProblem, 
                maxSelectedAnswers: jumbleGameData.getMinSelection(), 
                buttonOptions: jumbleGameData.optionList,
                titleQuestion: jumbleGameData.writtenPrompt,
                showArithmitic: true,
                colorProfile: colorProfile,
                skills: jumbleGameData.skills,
                scoreValue: jumbleGameData.score,
                id: jumbleGameData.id,
                langAssist: langAssist,
              )
            )
        );
      }
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
    required this.maxSelectedAnswers,
    required this.buttonOptions,
    required this.titleQuestion,
    required this.showArithmitic,
    required this.skills,
    required this.scoreValue,
    required this.id,
    required this.langAssist
  });

  /// The label for the question, which should be the math form for this game
  final String questionLabel;
  /// The list of combos accepted as answers
  final List<List<String>> answers;
  /// The number of max soloutions in the correct answer
  final int maxSelectedAnswers;
  /// the text for the buttons that can be used to create this phrase
  final List<String> buttonOptions;
  final String titleQuestion;
  final bool showArithmitic;
  final List<String> skills;
  final int scoreValue;
  final String id;
  final LanguageAssistLevel? langAssist;

  @override
  GameFormState createState() => GameFormState();
}

class GameFormState extends GamePageState<GameForm> {
  final List<String> _selectedAnswers = [];
  int maxSelection = 0;
  int currentCount = 0;
  // data for database
  bool lastCorrectState = false;
  late FlutterTts flutterTts;
  LanguageAssistLevel? assistLevel;

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

  /// Validate the current selection against the multiple answers. 
  /// If the value is -1, the answer is correct. If the answer is 0, not enough answers were selected. If the answer is greater than 0, then there is an error somewhere
  int validateAnswer() {
    // Helper to normalize strings for comparison: lowercase, drop punctuation,
    // collapse whitespace, and remove the word 'and' (common in written numbers).
    String _normalizeComparisonString(String s) {
      var out = s.toLowerCase();
      // remove punctuation except hyphens (we'll keep hyphens)
      out = out.replaceAll(RegExp(r"[^a-z0-9\s\-]"), ' ');
      // remove the word 'and' which often varies in written numbers
      out = out.replaceAll(RegExp(r"\band\b"), ' ');
      out = out.replaceAll(RegExp(r"\s+"), ' ').trim();
      return out;
    }

    // Build normalized joined form for selected answers
    final joinedSelected = _selectedAnswers.join(' ');
    final normSelected = _normalizeComparisonString(joinedSelected);

    // If the joined normalized selected string exactly matches any accepted
    // answer (after normalization), accept it even if the number of selected
    // buttons is less than the token count expected. This handles cases where
    // button labels combine multiple tokens (e.g. "four hundred thirty one").
    for (List<String> answerList in widget.answers) {
      final joinedAnswer = answerList.join(' ');
      final normAnswer = _normalizeComparisonString(joinedAnswer);
      if (normAnswer == normSelected) return -1;
    }

    // If not enough selections, return 0
    if (currentCount < maxSelection) {
      logger.d("Not enough answers are selected, could not validate. Expected $maxSelection but got $currentCount");
      return 0;
    }

    // Helper to find first mismatch index between two token lists; returns -1 if identical
    int _firstMismatchIndex(List<String> a, List<String> b) {
      int minLen = a.length < b.length ? a.length : b.length;
      for (int i = 0; i < minLen; i++) {
        if (a[i] != b[i]) return i;
      }
      if (a.length != b.length) return minLen;
      return -1;
    }

    int bestMismatch = -1;

    // Try each accepted answer
    for (List<String> answerList in widget.answers) {
      // 1) Direct token-wise exact match
      if (answerList.length == _selectedAnswers.length) {
        bool allMatch = true;
        for (int i = 0; i < answerList.length; i++) {
          if (_selectedAnswers[i] != answerList[i]) {
            allMatch = false;
            break;
          }
        }
        if (allMatch) return -1;
      }

      // If not matched token-wise, compute mismatch index for helpful feedback
      final mismatch = _firstMismatchIndex(_selectedAnswers, answerList);
      if (mismatch >= 0) {
        if (bestMismatch == -1 || mismatch < bestMismatch) bestMismatch = mismatch;
      }
    }

    // If no match found, return the best mismatch index (or 1 if none)
    return bestMismatch >= 0 ? bestMismatch : 1;
  }

  void clearAnswers() {
    setState(() {
      currentCount = 0;
      logger.d("Cleared answer selection");
      _selectedAnswers.clear();
    });
  }

  void _speakQuestion() async {
    try {
      await flutterTts.setLanguage('en-US');
    } catch (_) {}
    await flutterTts.setPitch(1.0);
    await flutterTts.setSpeechRate(1.0);
    await flutterTts.speak(widget.questionLabel);
  }

  // create a list of widgets that represents the selected button choices
  List<Widget> renderConditionalLabels() {
    List<Widget> widgets =[];

    for (String part in _selectedAnswers) {
      widgets.add(Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5), 
        child: Text(
          part,
          style: TextStyle(
            fontSize: 18.0,
            color: widget.colorProfile.textColor
          ),
        )
      ));
    }

    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    // List<String> selectedAnswers = [];
    // This is the data of multiple games
    List<Widget> dynamicButtonList = <Widget> [];
    int validIndex = 0;

    for (String option in widget.buttonOptions) {
      Widget button = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: GameButton(
          onPressed: () => {
            setState(() {
              if (currentCount < maxSelection) {
                _selectedAnswers.add(option);
                // _selectedIds.add(id);
                currentCount += 1;
              }
            }),
          }, 
          isDisabled: _selectedAnswers.contains(option), 
          label: option,
          colorProfile: widget.colorProfile,
        ),
      );
      
      dynamicButtonList.add(button);
    }
    
    // Render the form here
    /*
    'Button tapped ${snapshot.data ?? 0 + _externalCounter} time${(snapshot.data ?? 0 + _externalCounter) == 1 ? '' : 's'}.\n\n'
    'This should persist across restarts.', style: TextStyle(color: currentProfile.textColor)
    */
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
                      widget.titleQuestion,
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
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: renderConditionalLabels(),
                        ),
                      ],
                    ),
                  ),
                  
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8.0,
                        runSpacing: 8.0,
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
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: _selectedAnswers.isEmpty ? null : () => {
                                  validIndex = validateAnswer(),
                                  if (validIndex < 0) {
                                    showGameOverlay(validIndex)
                                  } else {
                                    showCorrectDialog(validIndex == -1, widget.colorProfile, validIndex)
                                  }
                                }, 
                                style: ButtonStyle(
                                  backgroundColor: WidgetStatePropertyAll(widget.colorProfile.checkAnswerButtonColor),
                                ),
                                child: Text(
                                  'Check Answer',
                                    style: TextStyle(
                                      color: widget.colorProfile.textColor
                                    ),
                                ),
                              ),
                              TextButton(
                                onPressed: () => {
                                  clearAnswers()
                                },
                                style: ButtonStyle(
                                  backgroundColor: WidgetStatePropertyAll(widget.colorProfile.clearAnswerButtonColor),
                                ),
                                child: Text(
                                  'Clear all answers',
                                  style: TextStyle(
                                    color: widget.colorProfile.textColor),
                                )
                              ),
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

class GameButton extends StatefulWidget {
  final VoidCallback onPressed;
  final bool isDisabled;
  final String label;
  final String disabledLabel;
  final ColorProfile colorProfile;
  final int id;

  const GameButton({
    super.key, 
    required this.onPressed, 
    required this.isDisabled,
    required this.label,
    this.disabledLabel = "",
    this.id = 0,
    required this.colorProfile
    });

    int getID() {
      return id;
    }

  @override
  GameButtonState createState() => GameButtonState();

}

class GameButtonState extends State<GameButton> {
  late bool isDisabled;

  @override
  void initState() {
    super.initState();
    isDisabled = widget.isDisabled; // Initialize internal state based on external flag
  }

  @override
  void didUpdateWidget(GameButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update the internal state when the external flag changes
    if (widget.isDisabled != oldWidget.isDisabled) {
      setState(() {
        isDisabled = widget.isDisabled;
      });
    }
  }

  void setDisabled(bool disabled) {
    setState(() {
      isDisabled = disabled;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isDisabled ? null : () {
        widget.onPressed();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        decoration: BoxDecoration(
          image: isDisabled ? const DecorationImage(
            image: AssetImage('images/disabled_button.png'),
            fit: BoxFit.fitHeight
          ) : null,
          color: isDisabled ? widget.colorProfile.buttonColor : widget.colorProfile.buttonColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          widget.label,
          style: TextStyle(
            color: widget.colorProfile.textColor,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
