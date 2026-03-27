import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:onwards/pages/activities/game_page.dart';
import 'package:onwards/pages/activities/jumble.dart';
import 'package:onwards/pages/components/calculator.dart';
import 'package:onwards/pages/components/lang_assist.dart';
import 'package:onwards/pages/components/progress_bar.dart';
import 'package:onwards/pages/components/skip.dart';
import 'package:onwards/pages/constants.dart';
import 'package:onwards/pages/game_data.dart';
import 'package:onwards/pages/home.dart';
import 'package:onwards/pages/score_display.dart';
import 'package:onwards/pages/tts.dart';
import 'package:onwards/pages/translation.dart';
import 'package:onwards/pages/components/theme_controller.dart';

const PlaybackGameData dummyData = PlaybackGameData(webAudioLink: "", multiAcceptedAnswers: [], writtenPrompt: "", optionList: [], skills: []);

class PlaybackActivityScreen extends StatelessWidget {
  final PlaybackGameData playbackGameData;
  final bool fromLevelSelect;
  final LanguageAssistLevel? langAssist;

  const PlaybackActivityScreen({
    super.key,
    this.playbackGameData = dummyData,
    this.fromLevelSelect = false,
    this.langAssist,
  });

  const PlaybackActivityScreen.fromLevelSelect({super.key, required PlaybackGameData gameData, this.langAssist}) :
    playbackGameData = gameData,
    fromLevelSelect = true;

  @override
  Widget build(BuildContext context) {
    PlaybackGameData randomData = gameDataBank.getRandomPlaybackElement();

    return ValueListenableBuilder<ColorProfile>(
      valueListenable: ThemeController.current,
      builder: (context, colorProfile, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text('Playback and Answer Game', style: TextStyle(color: colorProfile.textColor)),
            backgroundColor: colorProfile.headerColor,
            actions: const [ScoreDisplayAction(), CalcButton()],
            automaticallyImplyLeading: false,
          ),
          body: Container(
            decoration: colorProfile.backBoxDecoration,
            child: !fromLevelSelect ?
              PlaybackGameForm(
                audioSource: AssetSource(randomData.webAudioLink),
                answers: randomData.multiAcceptedAnswers, 
                questionLabel: randomData.audioTranscript, 
                maxSelectedAnswers: randomData.getMinSelection(), 
                buttonOptions: randomData.optionList,
                titleQuestion: randomData.writtenPrompt,
                showArithmitic: true,
                colorProfile: colorProfile,
                skills: randomData.skills,
                id: randomData.id,
                langAssist: langAssist,
              ) :
              PlaybackGameForm(
                audioSource: AssetSource(playbackGameData.webAudioLink),
                answers: playbackGameData.multiAcceptedAnswers, 
                questionLabel: playbackGameData.audioTranscript, 
                maxSelectedAnswers: playbackGameData.getMinSelection(), 
                buttonOptions: playbackGameData.optionList,
                titleQuestion: playbackGameData.writtenPrompt,
                showArithmitic: true,
                colorProfile: colorProfile,
                skills: playbackGameData.skills,
                id: playbackGameData.id,
                langAssist: langAssist,
              ),
          )
        );
      },
    );
  }
}

// Show this game's unique game form using the data
// passed from GameData. The idea is to have the game
// move to the next question after the dialog, using context
// to pass the info over
class PlaybackGameForm extends GamePage {
  const PlaybackGameForm({
    super.key,
    required this.answers, 
    required this.questionLabel,
    required this.maxSelectedAnswers,
    required this.buttonOptions,
    required this.titleQuestion,
    required this.showArithmitic,
    super.colorProfile,
    required this.audioSource,
    required this.skills,
    required this.id,
    required this.langAssist
  });

  final AssetSource audioSource;
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
  final String id;
  final LanguageAssistLevel? langAssist;

  @override
  PlaybackGameFormState createState() => PlaybackGameFormState();
}

class PlaybackGameFormState extends GamePageState<PlaybackGameForm> {

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

  /// Validate the current selection against the multiple answers
  int validateAnswer() {
    int errorIndex = 0;
    bool isCorrect = true;
    if (currentCount >= maxSelection) {
      for (List<String> answerList in widget.answers) {
        for (int i = 0; i < answerList.length; i++) {
          if (_selectedAnswers[i] != answerList[i]) {
            logger.d("Validating Answer: Expected ${answerList[i]}");
            isCorrect = false;
            errorIndex = i;
          }
        }
        
        // when we are done going through one answer, if its correct, just skip checking the rest
        if (isCorrect) {
          return -1;
        } else {
          return errorIndex;
        }
      }
    } else {
      logger.d("Not enough answers are selected, could not validate");
      return 0;
    }
    return 0;
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
                    child: TTSRunner(voiceLine: widget.questionLabel),
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
                  SizedBox(
                    width: double.infinity, 
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              onPressed: _selectedAnswers.isEmpty
                                  ? null
                                  : () {
                                      validIndex = validateAnswer();
                                      if (validIndex < 0) {
                                        showGameOverlay(validIndex);
                                      } else {
                                        showCorrectDialog(validIndex < 0, widget.colorProfile, validIndex);
                                      }
                                    },
                              style: ButtonStyle(
                                backgroundColor: WidgetStatePropertyAll(
                                  widget.colorProfile.checkAnswerButtonColor,
                                ),
                              ),
                              child: Text(
                                'Check Answer',
                                style: TextStyle(color: widget.colorProfile.textColor),
                              ),
                            ),

                            const SizedBox(width: 12),

                            TextButton(
                              onPressed: clearAnswers,
                              style: ButtonStyle(
                                backgroundColor: WidgetStatePropertyAll(
                                  widget.colorProfile.clearAnswerButtonColor,
                                ),
                              ),
                              child: Text(
                                'Clear all answers',
                                style: TextStyle(color: widget.colorProfile.textColor),
                              ),
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
                  )
                ],
              ),
            ),
          const Align(
            alignment: Alignment.bottomCenter,
            child: ProgressBar(),
          )
        ],
      ),
    );
  }
}
