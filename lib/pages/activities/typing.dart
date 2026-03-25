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
import 'package:onwards/pages/components/lang_assist.dart';
import 'package:onwards/pages/components/hover_translated_text.dart';
import 'package:onwards/pages/components/theme_controller.dart';


const TypingGameData dummyData = TypingGameData(
    displayedProblem: "", multiAcceptedAnswers: ["", ""], skills: []);

class TypeActivityScreen extends StatelessWidget {
  final TypingGameData typingGameData;
  final bool fromLevelSelect;
  final LanguageAssistLevel? langAssist;

  /// The default constructor that doesn't ask for the gameData.
  const TypeActivityScreen(
      {super.key,
      this.typingGameData = dummyData,
      this.fromLevelSelect = false,
      this.langAssist,});

  /// Using this constructor allows a gameData to be passed instead of randomly picked from the bank
  const TypeActivityScreen.fromLevelSelect(
      {required TypingGameData typingData,
      super.key,
      this.langAssist})
      : typingGameData = typingData,
        fromLevelSelect = true;

  @override
  Widget build(BuildContext context) {
    TypingGameData randomGameData = gameDataBank.getRandomTypingElement();

    return ValueListenableBuilder<ColorProfile>(
      valueListenable: ThemeController.current,
      builder: (context, colorProfile, _) {
        return Scaffold(
            appBar: AppBar(
              title: Text('Type it Out Game',
                  style: TextStyle(color: colorProfile.textColor)),
              backgroundColor: colorProfile.headerColor,
              actions: const [ScoreDisplayAction(), CalcButton()],
              automaticallyImplyLeading: false,
            ),
            body: Container(
                decoration: colorProfile.backBoxDecoration,
                padding: const EdgeInsets.only(top: 40),
                child: !fromLevelSelect
                    ? GameForm(
                        // Using the bank's random game data
                        answers: randomGameData.multiAcceptedAnswers,
                        questionLabel: randomGameData.displayedProblem,
                        instructions: randomGameData.writtenPrompt,
                        colorProfile: colorProfile,
                        skills: randomGameData.skills,
                        id: randomGameData.id,
                        langAssist: langAssist,
                      )
                    : GameForm(
                        // Using the passed gameData
                        answers: typingGameData.multiAcceptedAnswers,
                        questionLabel: typingGameData.displayedProblem,
                        instructions: typingGameData.writtenPrompt,
                        colorProfile: colorProfile,
                        skills: typingGameData.skills,
                        id: typingGameData.id,
                        langAssist: langAssist,
                      )));
      },
    );
  }
}

/// Show this game's unique game form using the data
/// passed from GameData. The idea is to have the game
/// move to the next question after the dialog, using context
/// to pass the info over
class GameForm extends GamePage {
  const GameForm(
      {super.key,
      super.colorProfile,
      required this.answers,
      required this.questionLabel,
      required this.instructions,
      required this.skills,
      required this.id,
      required this.langAssist
      });

  final String questionLabel;
  final List<String> answers;
  final String instructions;
  final count = 0;
  final List<String> skills;
  final String id;
  final LanguageAssistLevel? langAssist;


  @override
  State<GameForm> createState() => _GameFormState();
}

class _GameFormState extends GamePageState<GameForm> {
  // data for cache
  final _answerFieldController = TextEditingController();
  late FlutterTts flutterTts;
  late LanguageAssistLevel? assistLevel;

  // data for database
  bool lastCorrectState = false;

  @override
  void initState() {
    super.initState();
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

  /// Checks the answer in the field against the accepted answers. The answer in the
  bool validateAnswer() {
    var isCorrect = true;
    if (widget.count > 0) {
    } else {
      for (String potAnswer in widget.answers) {
        logger.i("Validating against $potAnswer");
        if (potAnswer != _answerFieldController.text) {
          isCorrect = false;
          // print("Answer was incorrect at: $potAnswer");
        } else {
          isCorrect = true;
          return isCorrect;
        }
      }
    }
    return isCorrect;
  }

  @override
  Widget build(BuildContext context) {
    bool valid;

    return Container(
      color: Colors.transparent,
      child: Stack(
        children: [
          addConfettiBlasters(),
          SingleChildScrollView(
            child: Center( 
              child: Form(
                key: const Key("_formKey"),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: MediaQuery.of(context).size.height * 0.1),
                    buildTextCard(
                      profile: currentProfile,
                      child: Text(
                        widget.instructions,
                        style: TextStyle(
                          color: currentProfile.textColor,
                          fontSize: 30,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    buildTextCard(
                      profile: currentProfile,
                      child: HoverTranslatedText(
                        text: widget.questionLabel,
                        colorProfile: currentProfile,
                        assistLevel: assistLevel,
                      ),
                    ),

                    if (assistLevel == LanguageAssistLevel.novice)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: ElevatedButton(
                          onPressed: _speakQuestion,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: currentProfile.buttonColor,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                          ),
                          child: Text(
                            'Hear Question',
                            style:
                                TextStyle(color: currentProfile.textColor),
                          ),
                        ),
                      ),

                    // TRANSLATE BUTTON:
                  if (assistLevel == LanguageAssistLevel.novice ||
                    assistLevel == LanguageAssistLevel.intermediate)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: TranslateButtonAndText(
                        sourceText: widget.questionLabel,
                        colorProfile: currentProfile,
                        speakOnTranslate: true,
                        targetLanguage: 'es',
                        autoTranslate: assistLevel == LanguageAssistLevel.novice,
                      ),
                    ),

                    buildTextCard(
                      profile: currentProfile,
                      maxWidth: 560,
                      padding: const EdgeInsets.all(16),
                      child: TextFormField(
                            maxLines: 3,
                            controller: _answerFieldController,
                            decoration: InputDecoration(
                              hintText: 'Type your answer...',
                              labelText: 'Your Answer',
                              filled: true,
                              hintStyle: TextStyle(
                                color: currentProfile.textColor,
                                fontSize: 18,
                              ),
                              fillColor: Colors.grey,
                              labelStyle: TextStyle(
                                color: currentProfile.textColor,
                                fontSize: 18,
                              ),
                              border: const OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(10)),
                              ),
                            ),
                            onFieldSubmitted: (_) {
                              showGameOverlay(-1);
                            },
                          ),
                    ),

                    SizedBox(
                      width: double.infinity, 
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: () {
                                  valid = validateAnswer();
                                  isCorrect = valid;
                                  valid
                                      ? showGameOverlay(-1)
                                      : showCorrectDialog(valid, currentProfile, -1);
                                },
                                style: ButtonStyle(
                                  backgroundColor: WidgetStatePropertyAll(
                                      currentProfile.checkAnswerButtonColor),
                                ),
                                child: Text(
                                  'Check Answer',
                                  style: TextStyle(
                                      color: currentProfile.textColor),
                                ),
                              ),

                              const SizedBox(width: 12),
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
                    )
                  ],
                ),
              ),
            ),
          ),
          const Align(
            alignment: Alignment.bottomCenter,
            child: ProgressBar(),
          ),
        ],
      ),
    );
  }
}
