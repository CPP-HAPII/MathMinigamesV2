import 'dart:collection';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:onwards/pages/activities/game_series.dart';
import 'package:onwards/pages/activities/fill_in_the_blank.dart';
import 'package:onwards/pages/constants.dart';
import 'package:onwards/pages/debug_home.dart';
import 'package:onwards/pages/game_data.dart';
import 'package:onwards/pages/score_display.dart';
import 'package:onwards/pages/create_sequence.dart';
import 'package:onwards/pages/create_question.dart';
import 'package:onwards/pages/components/lang_assist.dart';

import 'package:shared_preferences/shared_preferences.dart';

const ImageProvider placeholderImage = AssetImage('assets/images/placeholder.png');
const desktopPadding = 81.0;
const homeWidth = 1400.0;
const desktopMargin = 8.0;

GameDataBank gameDataBank = GameDataBank();
SequenceFiltersBank sequenceFiltersBank = SequenceFiltersBank();

HashMap<String, String> skillMap = HashMap();

// Image is currently 4:3 ratio
const itemWidth = 396.0; // controls the width of the card (should match image)
const minHeight = 340.0; // controls the height of the card (should match image)
var logger = Logger();

class HomeApp extends StatelessWidget {
  const HomeApp({
    super.key,
  });


  final ColorProfile colorProfile = lightFlavor;

  void addSkills() {
    skillMap.addAll(
      (
        {
          "single_digit_addition" : "Addition with Single Digits",
          "word_problem_written_form" : "Written Form from Word Problems",
          "three_place_addition" : "Addition with Three Digits/Places",
          "multiple_operations" : "Expressions with Multiple Operations",
          "three_place_subtraction" : "Subtraction with Three Digits/Places",
          "written_four_place_number_values" : "Numbers with Four Places in Written Form",
          "written_three_place_number_values" : "Numbers with Three Places in Written Form",
          "written_two_place_number_values" : "Numbers with Two Places in Written Form",
          "written_decimals_two_number_places" : "Decimals with Two Places in Written Form",
          "written_decimals_three_number_places" : "Decimals with Three Places in Written Form",
          "single_digit_division" : "Division with Single Digits",
          "spoken_written_form" : "Listening Written Form Expressions/Problems",
          "money" : "Money Operations",
          "single_digit_multiplication" : "Multiplication with Single Digits",
          "self-spoken_written_form" : "Speaking in Written Form",
          "two_place_multiplication" : "Multiplication with Two Digits/Places",
          "three_or_more_place_multiplication" : "Multiplication with Three or More Digits/Places",
          "four_or_more_number_places" : "Understanding Numbers with Four or More Digits/Places",
          "four_or_more_place_addition" : "Addition with Four or More Digits/Places",
          "two_place_addition" : "Addition with Two Digits/Places",
          "written_three_number_places" : "Writing Numbers with Three Digits/Places in Written Form",
          "fractions" : "Fraction Handling",
          "two_place_division" : "Division with Two Digits/Places",
          "number_sentences" : "Understanding Number Sentences",
          "three_place_division" : "Division with Three Digits/Places",
          "time" : "Time Operations",
          "written_form": "Written Form"
        }
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    addSkills();
    logger.i('Loading app...');
    return const MaterialApp(
      title: 'Onwards',
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage ({super.key});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  final Future<SharedPreferencesWithCache> _prefs =
    SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(
        allowList: <String>{'theme_id', 'sequence_id', 'lang_assist_level', 'correct', 'missed', 'mastered_topics', 'weak_topics', 'score'}
      )
    );

  late Future<int> themeId;
  late Future<int> correctCounter;
  late Future<int> missedCounter;
  late Future<List<String>> masteredTopicList;
  late Future<List<String>> weakTopicList;
  late Future<int> score;
  late Future<int> sequenceId;
  late Future<int> langAssistIndex;
  final List<LanguageAssistLevel> levels = LanguageAssistLevel.values;
  int selected = 0;

  SequenceData? currentSequence;

  final maxThemes = 6;

  ColorProfile currentProfile = lightFlavor;
  Future<void> loadTheme() async {
    final SharedPreferencesWithCache prefs = await _prefs;
    int? themeIndex = (prefs.getInt('theme_id') ?? 0);

    setState(() {
      currentProfile = _getProfileByIndex(themeIndex);
    });
  }

  Future<void> loadSequence() async {
    final SharedPreferencesWithCache prefs = await _prefs;
    int index = prefs.getInt('sequence_id') ?? 0;
    if (sequenceFiltersBank.sequenceBank.isNotEmpty) {
      setState(() {
        currentSequence = sequenceFiltersBank.sequenceBank[index];
      });
    }
  }

  Future<int> _loadSequenceIndex() async {
    final prefs = await _prefs;
    int index = prefs.getInt('sequence_id') ?? 0;
    if (sequenceFiltersBank.sequenceBank.isNotEmpty) {
      currentSequence = sequenceFiltersBank.sequenceBank[index];
    }
    return index;
  }

  Future<void> _setSequenceCounter(int index) async {
    final SharedPreferencesWithCache prefs = await _prefs;

    setState(() {
      sequenceId = prefs.setInt('sequence_id', index).then((_) {
        logger.i('Updating sequence...');
        currentSequence = sequenceFiltersBank.sequenceBank[index];
        return index;
      });
    });
  }

  Future<SequenceData> getCurrrentSequence(Future<int> sequenceId) async {
    final SharedPreferencesWithCache prefs = await _prefs;
    int index = (prefs.getInt('sequence_id') ?? 0);
    return sequenceFiltersBank.sequenceBank[index];
  } 

  Future<void> _setLangAssistLevel(int index) async {
    if (index < 0 || index >= levels.length) return;

    final prefs = await _prefs;

    await prefs.setInt('lang_assist_level', index);

    setState(() {
      selected = index;
    });

    logger.i('Language Assist level set to ${levels[index].label}');
  }

  void _loadAssistLevel() async {
    final saved = await AssistLevelService.load();
    setState(() {
      selected = saved.index;
    });
  }

  ColorProfile _getProfileByIndex(int index) {
    switch(index) {
        case 0:
          return lightFlavor;
        case 1:
          return darkFlavor;
        case 2:
          return plainFlavor;
        case 3:
          return mintFlavor;
        case 4:
          return strawberryFlavor;
        case 5:
          return bananaFlavor;
        case 6:
          return peanutFlavor;
        default:
          return lightFlavor;
      }
  }

  Future<void> _incrementCounter() async {
    final SharedPreferencesWithCache prefs = await _prefs;
    if ((prefs.getInt('theme_id') ?? 0) >= maxThemes) {
      return;
    }
    final int counter = (prefs.getInt('theme_id') ?? 0) + 1;
    setState(() {
      themeId = prefs.setInt('theme_id', counter).then((_) {
        logger.i('Updating theme...');
        currentProfile = _getProfileByIndex(counter);
        return counter;
      });
    });
  }

  Future<void> addMasteredTopic(String topic) async {
    final SharedPreferencesWithCache prefs = await _prefs;
    final List<String> mastered = (prefs.getStringList('mastered_topics') ?? <String>[]);
    if (mastered.contains(topic)) {
      return;
    }

    mastered.add(topic);

    setState(() {
      masteredTopicList = prefs.setStringList('mastered_topics', mastered).then((_) {
        return mastered;
      });
    });
  }

  Future<void> removeMasteredTopic(String topic) async {
    final SharedPreferencesWithCache prefs = await _prefs;
    final List<String> mastered = (prefs.getStringList('mastered_topics') ?? <String>[]);
    if (!mastered.contains(topic)) {
      return;
    }
    
    mastered.remove(topic);

    setState(() {
      masteredTopicList = prefs.setStringList('mastered_topics', mastered).then((_) {
        return mastered;
      });
    });
  }

  Future<void> _decrementCounter() async {
    final SharedPreferencesWithCache prefs = await _prefs;
    if ((prefs.getInt('theme_id') ?? 0) <= 0) {
      return;
    }

    final int counter = (prefs.getInt('theme_id') ?? 0) - 1;
    setState(() {
      themeId = prefs.setInt('theme_id', counter).then((_) {
        logger.i('Updating theme...');
        currentProfile = _getProfileByIndex(counter);
        return counter;
      });
    });
  }

  @override
  void initState() {
    super.initState();
    themeId = _prefs.then((SharedPreferencesWithCache prefs) {
      return prefs.getInt('theme_id') ?? 0;
    });
    correctCounter = _prefs.then((SharedPreferencesWithCache prefs) {
      return prefs.getInt('correct') ?? 0;
    });
    missedCounter = _prefs.then((SharedPreferencesWithCache prefs) {
      return prefs.getInt('missed') ?? 0;
    });
    score = _prefs.then((SharedPreferencesWithCache prefs) {
      return prefs.getInt('score') ?? 0;
    });

    masteredTopicList = _prefs.then((SharedPreferencesWithCache prefs) {
      return prefs.getStringList('mastered_topics') ?? <String>[];
    });
    weakTopicList = _prefs.then((SharedPreferencesWithCache prefs) {
      return prefs.getStringList('weak_topics') ?? <String>[];
    });
    sequenceId = _loadSequenceIndex();
    _loadAssistLevel();
    loadTheme();
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> gameCards = <Widget> [
      // TODO: Add image asset for Play Game mode
      GameCard(
        imageAsset: const AssetImage(
          'assets/images/play_mode.png'
        ),
        gameRoute: '/play-mode', 
        gameWidget: SeriesHomePage(colorProfile: currentProfile, difficultyType: DifficultyType.easy, sequenceData: currentSequence),
        keyId: 5,
        title: "Play Mode",
        subtitle: "A series of questions based off the sequence.",
        styleMode: TextStyle(color: currentProfile.textColor),
        colorProfile: currentProfile,
        sequenceData: currentSequence ?? sequenceFiltersBank.sequenceBank[0],
      ),
      GameCard(
        imageAsset: const AssetImage(
          'assets/images/debug_mode.png'
        ),
        gameRoute: '/debug', 
        gameWidget: const DebugHomePage(),
        keyId: 4,
        title: "Debug Mode",
        subtitle: "Dev Only. For testing purposes.",
        styleMode: TextStyle(color: currentProfile.textColor),
        colorProfile: currentProfile,
        sequenceData: currentSequence ?? sequenceFiltersBank.sequenceBank[0],
      )
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        backgroundColor: currentProfile.headerColor,
        centerTitle: true,
        actions: const [ScoreDisplayAction()],
      ),
      body: SingleChildScrollView(
        child: Container(
          decoration: currentProfile.backBoxDecoration,
          child: Column(
            children: [
              SizedBox(
                width: 900.0,
                height: 500.0,
                child: ListView(
                  key: const ValueKey('HomeListView'),
                  primary: true,
                  padding: const EdgeInsetsDirectional.only(
                    top: 90.0,
                  ),
                  children: [
                    CarouselCardItem(
                      child: DesktopCarousel(
                        height: minHeight,
                        colorProfile: currentProfile,
                        children: gameCards,
                      ),
                    )
                  ],
                ),
              ),

              // TODO: Entrance to the custom input page (create_sequence.dart) Move to admin page
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: ElevatedButton(
                  style: ButtonStyle(backgroundColor: WidgetStatePropertyAll(currentProfile.buttonColor)),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const CustomSequencePage()),
                    );
                  },
                  child: Text(
                    'Add Sequence for Game',
                    style: TextStyle(color: currentProfile.textColor),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: ElevatedButton(
                  style: ButtonStyle(backgroundColor: WidgetStatePropertyAll(currentProfile.buttonColor)),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const CustomQuestionPage()),
                    );
                  },
                  child: Text(
                    'Add Question to Database',
                    style: TextStyle(color: currentProfile.textColor),
                  ),
                ),
              ),
              FutureBuilder<int>(
                future: themeId,
                builder: (BuildContext context, AsyncSnapshot<int> snapshot) {
                  switch (snapshot.connectionState) {
                    case ConnectionState.none:
                    case ConnectionState.waiting:
                      return const CircularProgressIndicator();
                    case ConnectionState.active:
                    case ConnectionState.done:
                      if (snapshot.hasError) {
                        return Text('Error: ${snapshot.error}', style: TextStyle(color: currentProfile.textColor));
                      } else {
                        return Text(
                          'Current theme: ${currentProfile.idKey}',
                          style: TextStyle(
                            color: currentProfile.textColor,
                          ),
                        );
                      }
                  }
                },
              ),
              Text(
                "Language Assist",
                style: TextStyle(
                  fontSize: 24,
                  color: currentProfile.textColor,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(levels.length, (index) {
                  final isSelected = selected == index;

                  return Padding(
                    padding: const EdgeInsets.all(8),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSelected
                            ? Colors.green
                            : currentProfile.buttonColor,
                      ),
                      onPressed: () => _setLangAssistLevel(index),
                      child: Text(
                        levels[index].label,
                        style: TextStyle(
                          color: currentProfile.textColor,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }),
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Tooltip(
                    message: "Previous Theme",
                    child: ElevatedButton(
                      style: ButtonStyle(backgroundColor: WidgetStatePropertyAll(currentProfile.buttonColor)),
                      onPressed: _decrementCounter,
                      child: Icon(Icons.arrow_left, color: currentProfile.textColor),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      "Theme Select",
                      style: TextStyle(
                        color: currentProfile.textColor,
                      ),
                    ),
                  ),
                  Tooltip(
                    message: "Next Theme",
                    preferBelow: true,
                    child: ElevatedButton(
                      style: ButtonStyle(backgroundColor: WidgetStatePropertyAll(currentProfile.buttonColor)),
                      onPressed: _incrementCounter,
                      child: Icon(Icons.arrow_right, color: currentProfile.textColor),
                    ),
                  )
                ],
              ),
              FutureBuilder<int>(
                future: sequenceId,
                builder: (BuildContext context, AsyncSnapshot<int> snapshot) {
                  if (!snapshot.hasData) {
                    return const CircularProgressIndicator();
                  }

                  int currentIndex = snapshot.data!;
                  // Prevent crash if Firestore hasn't loaded sequences yet
                  if (sequenceFiltersBank.sequenceBank.isEmpty) {
                    return Text("No sequences loaded.", style: TextStyle(color: currentProfile.textColor));
                  }

                  // Clamp index within valid range
                  currentIndex = currentIndex.clamp(0, sequenceFiltersBank.sequenceBank.length - 1);

                  final currentSequence = sequenceFiltersBank.sequenceBank[currentIndex];

                  return Column(
                    children: [
                      Text(
                        "Current Sequence: ${currentSequence.name}",
                        style: TextStyle(color: currentProfile.textColor),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Difficulty: ${currentSequence.difficulty.join(', ')}",
                        style: TextStyle(color: currentProfile.textColor),
                      ),
                      Text(
                        "Game Types: ${currentSequence.gameType.join(', ')}",
                        style: TextStyle(color: currentProfile.textColor),
                      ),
                      Text(
                        "Filters: ${currentSequence.filters.join(', ')}",
                        style: TextStyle(color: currentProfile.textColor),
                      ),
                      Text(
                        "Random: ${currentSequence.random ? "Yes" : "No"}",
                        style: TextStyle(color: currentProfile.textColor),
                      )
                    ],
                  );
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Tooltip(
                    message: "Previous Sequence",
                    child: ElevatedButton(
                      onPressed: () async {
                        final prefs = await _prefs;
                        int currentIndex = (prefs.getInt('sequence_id') ?? 0);
                        if (currentIndex > 0) {
                          await _setSequenceCounter(currentIndex - 1);
                        }
                      },
                      style: ButtonStyle(backgroundColor: WidgetStatePropertyAll(currentProfile.buttonColor)),
                      child: Icon(Icons.arrow_left, color: currentProfile.textColor),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      "Sequence Select",
                      style: TextStyle(color: currentProfile.textColor),
                    ),
                  ),
                  Tooltip(
                    message: "Next Sequence",
                    child: ElevatedButton(
                      onPressed: () async {
                        final prefs = await _prefs;
                        int currentIndex = (prefs.getInt('sequence_id') ?? 0);
                        if (currentIndex < sequenceFiltersBank.sequenceBank.length - 1) {
                          await _setSequenceCounter(currentIndex + 1);
                        }
                      },
                      style: ButtonStyle(backgroundColor: WidgetStatePropertyAll(currentProfile.buttonColor)),
                      child: Icon(Icons.arrow_right, color: currentProfile.textColor),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/*

            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Tooltip(
                message: "Start a series of 10 questions",
                verticalOffset: -50,
                child: GameTestPage(
                  colorProfile: currentProfile
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Tooltip(
                message: "Easy Mode (10)",
                verticalOffset: -50,
                child: GameTestPage(
                  colorProfile: currentProfile,
                  difficultyType: DifficultyType.easy,
                ),
              ),
            ),
            ElevatedButton(
              style: ButtonStyle(backgroundColor: WidgetStatePropertyAll(currentProfile.buttonColor)),
              onPressed: () => {
                Navigator.of(context).push(MaterialPageRoute(builder: (context) => SeriesEndPage(colorProfile: currentProfile),))
              }, 
              child: Text(
                "Test the result page",
                style: TextStyle(
                  color: currentProfile.textColor
                ),
              )
            ),
*/

class CarouselCardItem extends StatelessWidget {
  const CarouselCardItem({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return(
      Align(
        alignment: Alignment.center,
        child: Container(
          constraints: const BoxConstraints(maxWidth: homeWidth),
          padding: const EdgeInsets.symmetric(
            horizontal: desktopPadding
          ),
          child: child,
        ),
      )
    );
  }
}

class DesktopCarousel extends StatefulWidget {
  const DesktopCarousel({
    super.key, 
    required this.height, 
    required this.children,
    this.colorProfile = plainFlavor,
    this.modeHeader = "Game Select: Select the Game you want to try"
  });

  final double height;
  final List<Widget> children;
  final ColorProfile colorProfile;
  final String modeHeader;


  @override
  DesktopCarouselState createState() => DesktopCarouselState();
}

class DesktopCarouselState extends State<DesktopCarousel> {
  late ScrollController controller;

  @override
  void initState() {
    super.initState();
    controller = ScrollController();
    controller.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var showPreviousButton = false;
    var showNextButton = true;

    if (controller.hasClients) {
      showPreviousButton = controller.offset > 0;
      showNextButton = controller.offset < controller.position.maxScrollExtent;
    }

    return(Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          height: 300.0,
          width: 550.0,
          child: Align(
            alignment: Alignment.center,
            child: Container(
              height: widget.height,
              constraints: const BoxConstraints(maxWidth: homeWidth),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 0.0),
                    child: Text(
                    widget.modeHeader,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: widget.colorProfile.textColor
                    ),
                  ),
                  ),
                  ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: desktopPadding - desktopMargin,
                    ),
                    scrollDirection: Axis.horizontal,
                    primary:  false,
                    physics: const SnappingScrollPhysics(),
                    controller: controller,
                    itemExtent: itemWidth,
                    itemCount: widget.children.length,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: widget.children[index],
                    ),
                  ),
                  if (showPreviousButton)
                    _DesktopPageButton(
                      onTap: () {
                        controller.animateTo(
                          controller.offset - itemWidth, 
                          duration: const Duration(milliseconds: 200), 
                          curve: Curves.easeOut
                        );
                      },
                    ),
                  if (showNextButton)
                    _DesktopPageButton(
                      isEnd: true,
                      colorProfile: widget.colorProfile,
                      onTap: () {
                        controller.animateTo(
                          controller.offset + itemWidth, 
                          duration: const Duration(milliseconds: 200), 
                          curve: Curves.easeInOut,
                        );
                      },
                    )
                ],
              ),
            ),
          ),
        ),
        
      ],
    )
    );
  }
}

class _DesktopPageButton extends StatelessWidget {
  const _DesktopPageButton({
    this.isEnd = false,
    this.onTap,
    this.colorProfile = lightFlavor
  });

  final bool isEnd;
  final GestureTapCallback? onTap;
  final ColorProfile colorProfile;

  @override
  Widget build(BuildContext context) {
    const buttonSize = 58.0;
    const padding = desktopPadding - buttonSize / 2;
    return ExcludeSemantics(
      child: Align(
        alignment: isEnd
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: Container(
          width: buttonSize,
          height: buttonSize,
          margin: EdgeInsetsDirectional.only(
            start: isEnd ? 0 : padding,
            end: isEnd ? padding : 0,
          ),
          child: Tooltip(
            message: isEnd
                ? MaterialLocalizations.of(context).nextPageTooltip
                : MaterialLocalizations.of(context).previousPageTooltip,
            child: Material(
              color: colorProfile.buttonColor,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: Icon(
                  isEnd ? Icons.arrow_forward_ios : Icons.arrow_back_ios,
                  color: colorProfile.textColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SnappingScrollPhysics extends ScrollPhysics {
  const SnappingScrollPhysics({super.parent});

  @override
  ScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return SnappingScrollPhysics(parent: buildParent(ancestor));
  }

  double getTargetPixels(ScrollMetrics pos, Tolerance tolerance,
    double velocity) {
    final itemW = pos.viewportDimension / 4;
    var item = pos.pixels / itemW;
    if (velocity < -tolerance.velocity) {
      item -= 0.5;
    } else if (velocity > tolerance.velocity) {
      item += 0.5;
    }
    return min(item.roundToDouble() * itemW, pos.maxScrollExtent);
  }

  

  @override
  bool get allowImplicitScrolling => true;
}

class GameCard extends StatelessWidget {
  const GameCard({super.key, 
    required this.gameRoute, 
    required this.keyId,
    this.imageAsset,
    this.gameWidget = const FillInActivityScreen(colorProfile: plainFlavor),
    required this.title,
    required this.subtitle,
    required this.styleMode,
    this.colorProfile = plainFlavor,
    required this.sequenceData,
  });

  final Widget gameWidget;
  final String gameRoute;
  final int? keyId;
  final ImageProvider? imageAsset;
  final String title;
  final String subtitle;
  final TextStyle? styleMode;
  final ColorProfile colorProfile;
  final SequenceData sequenceData;
  
  final desktopMargin = 8.0;
  final minHeight = 240.0;
  final itemWidth = 296.0;

  @override
  Widget build(BuildContext context) {
    // final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;
    final asset = imageAsset;
    final style = styleMode;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: desktopMargin),
      margin: const EdgeInsets.symmetric(vertical: 16.0),
      height: minHeight,
      width: itemWidth,
      child: Material(
        key: ValueKey(keyId),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (asset != null)
            Image(
              image: asset,
              fit: BoxFit.cover,
              height: minHeight,
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    width: 500.0,
                    color: colorProfile.buttonColor,
                    child: Column(
                      children: [
                        Text(
                          title,
                          maxLines: 3,
                          overflow: TextOverflow.visible,
                          style: style,
                        ),
                        Text(
                          subtitle,
                          maxLines: 5,
                          overflow: TextOverflow.visible,
                          style: style,
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => gameWidget,
                      ),
                    );
                  },
                ),
              )
            )
          ],
        ),
      ),
    );
  }
}

class OverlayWidget extends StatefulWidget {
  const OverlayWidget({super.key});

  @override
  State<OverlayWidget> createState() => _OverlayWidgetState();
}

class _OverlayWidgetState extends State<OverlayWidget> {
  OverlayEntry? entry;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        displayOverlay();
      },
      child: const Text('Press Me'),
    );
  }

  void displayOverlay() {
    WidgetsBinding.instance!.addPostFrameCallback((_) => showOverlay());
  }

  void hideOverlay() {
    entry?.remove();
    entry = null;
  }

  void showOverlay() {
    entry = OverlayEntry(
      builder: (context) => OverlayBanner(
        onBannerDismissed: () {
          hideOverlay();
        },
      ),
    );

    final overlay = Overlay.of(context)!;
    overlay.insert(entry!);
  }
}

class OverlayBanner extends StatefulWidget {
  const OverlayBanner({Key? key, this.onBannerDismissed}) : super(key: key);

  final VoidCallback? onBannerDismissed;

  @override
  State<OverlayBanner> createState() => _OverlayBannerState();
}

class _OverlayBannerState extends State<OverlayBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  static const Curve curve = Curves.easeOut;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _playAnimation();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      builder: (context, child) {
        final double animationValue = curve.transform(_controller.value);
        return FractionalTranslation(
          translation: Offset(0, -(1 - animationValue)),
          child: child,
        );
      },
      animation: _controller,
      child: SingleChildScrollView(
        child: Container(
          width: double.infinity,
          height: 400,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage("assets/images/correct_overlay.png"),
              fit: BoxFit.fitHeight
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _playAnimation() async {
    // fist will show banner with forward.
    await _controller.forward();
    // wait for 3 second and then play reverse animation to hide the banner
    // Duration can be passed as parameter, banner will wait this much and then will dismiss
    await Future<void>.delayed(const Duration(seconds: 3));
    await _controller.reverse(from: 1);
    // call onDismissedCallback so OverlayWidget can remove and clear the OverlayEntry.
    widget.onBannerDismissed?.call();
  }
}