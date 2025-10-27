import 'dart:math';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:onwards/pages/activities/game_series.dart';
import 'package:onwards/pages/home.dart';

// Helper: normalize various Firestore shapes for accepted answers 
List<List<String>> _normalizeNestedAnswers(dynamic value) {
  if (value == null) return <List<String>>[];
  // If it's already a string, try to parse it as JSON (e.g. '["a","b"]' or
  // '[ ["a","b"] ]'). If that fails, fall back to tokenizing by whitespace.
  if (value is String) {
    try {
      final decoded = jsonDecode(value);
      // If decoded is iterable, run normalization again on that structure
      if (decoded is Iterable) {
        return _normalizeNestedAnswers(decoded);
      }
    } catch (_) {
      // ignore JSON errors and fall through to whitespace tokenization
    }
    return [value.split(RegExp(r"\s+"))];
  }

  if (value is Iterable) {
    final list = value.toList();
    if (list.isEmpty) return <List<String>>[];

    // - If any element contains whitespace, assume each element is a full
    //   accepted-answer phrase -> tokenize each element into a List<String>.
    // - Otherwise (all elements are single tokens) assume the whole list
    //   represents one accepted answer (i.e. tokens in order) and wrap it.
    if (list.first is String) {
      final asStrings = list.map((e) => e.toString()).toList();
      final anyHasSpace = asStrings.any((s) => s.trim().contains(RegExp(r"\s+")));
      if (anyHasSpace) {
        // Each element is a phrase; split each into tokens
        return asStrings.map<List<String>>((s) => s.split(RegExp(r"\s+"))).toList();
      } else {
        // Treat the entire list as tokens for one accepted answer
        return [asStrings];
      }
    }

    // Otherwise assume it's an iterable of iterables and convert each to List<String>
    return list
        .map<List<String>>((e) => (e is Iterable)
            ? e.map((x) => x.toString()).toList()
            : [e.toString()])
        .toList();
  }

  // Fallback: convert to single tokenized string
  return [value.toString().split(RegExp(r"\s+"))];
}

List<String> _normalizeToStringList(dynamic value) {
  if (value == null) return <String>[];
  if (value is String) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Iterable) return decoded.map((e) => e.toString()).toList();
    } catch (_) {}
    return [value];
  }
  if (value is Iterable) return value.map((e) => e.toString()).toList();
  return [value.toString()];
}

class SequenceData {
  const SequenceData({
    required this.difficulty,
    required this.filters,
    required this. gameType,
    required this.name
  });
  final List<String> difficulty;
  final List<String> filters;
  final List<String> gameType;
  final String name;
  factory SequenceData.fromFirestore(Map<String, dynamic> doc) {
    return SequenceData(
      difficulty: List<String>.from(doc['difficulty'] ?? []),
      filters: List<String>.from(doc['filters'] ?? []),
      gameType: List<String>.from(doc['gameType'] ?? []),
      name: doc['name'] as String,
    );
  }
}

class SequenceFiltersBank {
  List<SequenceData> sequenceBank = [];

  SequenceFiltersBank();

  Future<void> initFiltersBank () async {
    sequenceBank.clear();
    await initSequenceBank();
  }

  Future<void> initSequenceBank() async{
    logger.i("Initializing sequence question bank from Firestore...");
    // Reference to `sequenceDoc` in Firestore
    DocumentSnapshot sequenceSnapshot = await FirebaseFirestore.instance
        .collection("gameData")
        .doc("sequenceDoc")
        .get();

    Map<String, dynamic> sequenceData = sequenceSnapshot.data() as Map<String, dynamic>;
    List<dynamic> sequences = sequenceData['sequences'];
    
    if (sequences.isEmpty) {
      logger.w("No sequences found inside 'sequences' array.");
      return;
    }

    for (int i = 0; i < sequences.length; i++) {
      var s = sequences[i];
      try {
        if (s is! Map<String, dynamic>) {
          logger.w("Skipping invalid sequence entry at index $i: $s");
          continue;
        }

        // Convert to SequenceFiltersData and add to bank
        sequenceBank.add(
          SequenceData.fromFirestore(Map<String, dynamic>.from(s)),
        );
      } catch (e) {
        logger.e("Error parsing sequence question at index $i: $e");
      }
    }
  logger.i("Loaded ${sequenceBank.length} sequences into sequenceBank.");
  }
}

/// Fill in the blank needs the question to show with blanks, 
class GameData {
  const GameData({
    required this.id,
    required this.skills,
    required this.score,
    this.tags = const []
  });

  final int score;
  final String id;
  final List<String> skills;
  final List<String> tags;

  // Factory constructor to create GameData from Firestore document
  factory GameData.fromFirestore(Map<String, dynamic> doc) {
    return GameData(
      id: doc['id'] as String,
      score: doc['score'] as int,
  skills: List<String>.from(doc['skills'] ?? []),
    );
  }
}

class PlaybackGameData extends GameData {
  const PlaybackGameData({
    required this.webAudioLink,
    required this.multiAcceptedAnswers,
    required this.writtenPrompt,
    this.audioTranscript = 'Dummy transcript',
    required this.optionList,
    super.id = "playback", 
    required super.skills,
    super.score = 25
  });
  
  /// Factory to create PlaybackGameData from Firestore
  factory PlaybackGameData.fromFirestore(Map<String, dynamic> doc) {
    return PlaybackGameData(
      id: doc['id'] as String? ?? 'playback',
      score: doc['score'] as int? ?? 25,
  skills: List<String>.from(doc['skills'] ?? []),
      webAudioLink: doc['webAudioLink'] as String? ?? '',
      multiAcceptedAnswers: _normalizeNestedAnswers(doc['multiAcceptedAnswers']),
      writtenPrompt: doc['writtenPrompt'] as String? ?? '',
      audioTranscript: doc['audioTranscript'] as String? ?? '',
      optionList: List<String>.from(doc['optionList'] ?? []),
    );
  }
  
  final String webAudioLink;
  final List<List<String>> multiAcceptedAnswers;
  final String writtenPrompt;
  final String audioTranscript;
  final List<String> optionList;

  int getMinSelection() {
    return multiAcceptedAnswers[0].length;
  }
}

class JumbleGameData extends GameData {
  const JumbleGameData({
    required this.displayedProblem,
    required this.multiAcceptedAnswers,
    this.writtenPrompt = "Use the buttons below to answer the prompt",
    required this.optionList,
    super.id = "jumble", 
    required super.skills,
    super.score = 10,
    super.tags = const []
  });
  
  /// The actual problem shown under the written prompt. This can be arithmitic or a word problem
  final String displayedProblem;
  /// A list of string lists that represent the multiple combinations of words from the options lists 
  final List<List<String>> multiAcceptedAnswers;
  /// The title prompt for the Jumble game. Use this to provide unique instructions for this problem. Optional.
  final String writtenPrompt;
  /// The labels that will be used on the buttons
  final List<String> optionList;

  int getMinSelection() {
    return multiAcceptedAnswers[0].length;
  }

    /// Factory to create JumbleGameData from Firestore
  factory JumbleGameData.fromFirestore(Map<String, dynamic> doc) {
    return JumbleGameData(
      id: doc['id'] as String? ?? 'jumble',
      score: doc['score'] as int? ?? 10,
      skills: List<String>.from(doc['skills'] ?? []),
      tags: List<String>.from(doc['tags'] ?? []),
      displayedProblem: doc['displayedProblem'] as String,
      multiAcceptedAnswers:
          _normalizeNestedAnswers(doc['multiAcceptedAnswers']),
      writtenPrompt: doc['writtenPrompt'] as String? ??
          "Use the buttons below to answer the prompt",
      optionList: List<String>.from(doc['optionList'] ?? []),
    );
  }
}

class ReadAloudGameData extends GameData {
  const ReadAloudGameData({
    required this.displayedProblem,
    required this.multiAcceptedAnswers,
    this.writtenPrompt = "Answer the question by speaking into to the microphone.",
    this.addtionalInstructions = "Your speech will be turned into numbers. Make sure you have microphone access enabled.",
    this.useNumWordProtocol = true,
    super.id = "reading",
    required super.skills,
    super.score = 30,
    super.tags = const []
  });
  
  /// The actual problem shown under the written prompt. This can be arithmitic or a word problem
  final String displayedProblem;
  /// A list of string lists that represent the multiple combinations of words from the options lists 
  final List<List<String>> multiAcceptedAnswers;
  /// The title prompt for the Jumble game. Use this to provide unique instructions for this problem. Optional.
  final String writtenPrompt;
  final String addtionalInstructions;
  final bool useNumWordProtocol;

  factory ReadAloudGameData.fromFirestore(Map<String, dynamic> doc) {
    return ReadAloudGameData(
      id: doc['id'] as String? ?? 'reading',
      score: doc['score'] as int? ?? 30,
      skills: List<String>.from(doc['skills'] ?? []),
      tags: List<String>.from(doc['tags'] ?? []),
      displayedProblem: doc['displayedProblem'] as String,
      multiAcceptedAnswers: _normalizeNestedAnswers(doc['multiAcceptedAnswers']),
      writtenPrompt: doc['writtenPrompt'] as String? ??
          "Answer the question by speaking into to the microphone.",
      addtionalInstructions: doc['addtionalInstructions'] as String? ??
          "Your speech will be turned into numbers. Make sure you have microphone access enabled.",
      useNumWordProtocol: doc['useNumWordProtocol'] as bool? ?? true,
    );
  }
}

class TypingGameData extends GameData {
  const TypingGameData({
    required this.displayedProblem,
    required this.multiAcceptedAnswers,
    this.writtenPrompt = "Write the expression in written form (do not use special characters)",
    super.id = "typing",
    required super.skills,
    super.score = 20,
    super.tags = const []
  });
  
  final String displayedProblem;
  final List<String> multiAcceptedAnswers;
  final String writtenPrompt;

  factory TypingGameData.fromFirestore(Map<String, dynamic> doc) {
    return TypingGameData(
      id: doc['id'] as String? ?? 'typing',
      score: doc['score'] as int? ?? 20,
      skills: List<String>.from(doc['skills'] ?? []),
      tags: List<String>.from(doc['tags'] ?? []),
      displayedProblem: doc['displayedProblem'] as String,
      multiAcceptedAnswers: _normalizeToStringList(doc['multiAcceptedAnswers']),
      writtenPrompt: doc['writtenPrompt'] as String? ??
          "Write the expression in written form (do not use special characters)",
    );
  }
}

class FillBlanksGameData extends GameData{
  const FillBlanksGameData({
    required this.displayedProblem,
    required this.multiAcceptedAnswers,
    required this.writtenPrompt,
    required this.blankForm,
    required this.optionList,
    super.id = "fill",
    required super.skills,
    super.score = 15,
    super.tags = const []
  });
  
  final String displayedProblem;
  final List<String> multiAcceptedAnswers;
  final String writtenPrompt;
  final String blankForm;
  final List<String> optionList;

  int getMinSelection() {
    return multiAcceptedAnswers.length;
  }
  factory FillBlanksGameData.fromFirestore(Map<String, dynamic> doc) {
    return FillBlanksGameData(
      id: doc['id'] as String? ?? 'fill',
      score: doc['score'] as int? ?? 15,
      skills: List<String>.from(doc['skills'] ?? []),
      tags: List<String>.from(doc['tags'] ?? []),
      displayedProblem: doc['displayedProblem'] as String,
      multiAcceptedAnswers: _normalizeToStringList(doc['multiAcceptedAnswers']),
      writtenPrompt: doc['writtenPrompt'] as String,
      blankForm: doc['blankForm'] as String,
      optionList: List<String>.from(doc['optionList'] ?? []),
    );
  }
}

class GameDataBank {
  List<GameData> dataBank = [];
  final random = Random();

  // Modified banks
  List<JumbleGameData> jumbleBank = [];
  List<PlaybackGameData> playbackBank = [];
  List<ReadAloudGameData> readingBank = [];
  List<TypingGameData> typingBank = [];
  List<FillBlanksGameData> fillBlanksBank = [];

  // Level select banks
  List<GameData> easyModeBank = [];
  List<GameData> intermediateModeBank = [];
  List<GameData> hardModeBank = [];

  // Firestore bank
  List<GameData> questionBank = [];
  // Raw Firestore documents cached for filtering (maps)
  List<Map<String, dynamic>> rawQuestionDocs = [];

  GameDataBank();

  Future<void> initBanks() async {
    // check if the banks already have data
    jumbleBank.clear();
    playbackBank.clear();
    jumbleBank.clear();
    typingBank.clear();
    fillBlanksBank.clear();

    easyModeBank.clear();
    intermediateModeBank.clear();
    hardModeBank.clear();

    questionBank.clear();

    // init local banks 
    initJumbleBank();
    initPlaybackBank();
    initReadingBank();
    initTypingBank();
    initFillBlanksBank();

    // init Firestore banks (await so callers receive fully populated banks)
    await initQuestionBank();
    // Future plan : deprecate mode banks and use sequenceBank instead
    await initEasyModeBank();
    await initHardModeBank();
    await initIntermediateModeBank();

    logger.i("Iniitalized the game questions from the database.");

    // shuffle bank; Note: Getter for these types are randomized too
    fillBlanksBank.shuffle(random);
    jumbleBank.shuffle(random);
    playbackBank.shuffle(random);
    readingBank.shuffle(random);
    typingBank.shuffle(random);
  }

  void initJumbleBank() {
    
    jumbleBank.addAll(
      // an example of a jumble game data object. This one does use the optional writtenPrompt parameter
      [
        const JumbleGameData(
          displayedProblem: 'Sally is 5 years old. Her mother 8 times as old as Sally is. How old is her mother?', 
          multiAcceptedAnswers: [
            ["She", "is", "forty", "years-old"]
          ],
          writtenPrompt: 'Answer the short-response question using the blocks below.',
          optionList: [
            "She", "eight", "five", "forty", "thrity-two", "is", "forty-eight", "years-old"
          ],
          id: "jumble.1",
          skills: ["single_digit_addition", "word_problem_written_form"],
        ),
        const JumbleGameData(
          displayedProblem: 'Franklin has a set of building blocks with 176 pieces. He received 2 more sets as gifts. One has 95 pieces; the other has 160 pieces. How many building blocks does Franklin have all together?', 
          multiAcceptedAnswers: [
            ["Franklin", "has", "four hundred and thirty one", "blocks"]
          ],
          writtenPrompt: 'Answer the short-response question using the blocks below.',
          optionList: [
            "blocks", "four hundred thirty one", "Franklin", "fourty-three and one", "has", "four thirty one", 
          ],
          id: "jumble.2",
          skills: ["word_problem_written_form", "three_place_addition"]
        ),
        const JumbleGameData(
          displayedProblem: 'Archery Team A hit the target 367 times. Team B hit the target 412 times. Did the two teams hit the target 800 times? If not, by how much did they miss?', 
          multiAcceptedAnswers: [
            ["They", "missed", "twenty-one", "times"]
          ],
          writtenPrompt: 'Answer the short-response question using the blocks below.',
          optionList: [
            "seven hundred and seventy nine", "They", "twenty-one", "missed", "seven hundred seventy", "times"
          ],
          id: "jumble.3",
          skills: ["word_problem_written_form", "multiple_operations", "three_place_subtraction"]
        ),
        const JumbleGameData(
          displayedProblem: '4153 + 3567 = 7720', 
          multiAcceptedAnswers: [
            ['four thousand one hundred and fifty three', "plus", 'three thousand five hundred and sixty seven', 'equals', 'seven thousand seven hundred and twenty'], 
            ['four thousand one hundred and fifty three', "plus", 'three thousand five hundred and sixty seven', 'is', 'seven thousand seven hundred and twenty']
          ],
          optionList: ['four thousand one hundred and fifty three', "minus", 'fourty one hundred and fifty three', 'thirty five hundred and sixty seven',
          'three thousand five hundred and sixty seven', 'plus', 'seventy seven hundred and twenty', 'seven thousand seven hundred and twenty', 'equals'],
          id: "jumble.4",
          skills: ["written_four_place_number_values"]
        ),
        const JumbleGameData(
          displayedProblem: '375 + 109 = 484', 
          multiAcceptedAnswers: [
            ['three hundred seventy five', "plus", 'one hundred and nine', 'equals', 'four hundred eighty four']
          ],
          optionList: ['three hundred seventy five', "minus", 'one o nine', 'three seven five',
          'one hundred and nine', 'plus', 'thirty seven and five', 'four hundred eighty four', 'equals'],
          id: "jumble.5",
          skills: ["written_three_place_number_values"]
        ),
        const JumbleGameData(
          displayedProblem: '158 + 217 + 325 = 700', 
          multiAcceptedAnswers: [
            ['one hundred and fifty eight', "plus", 'two hundred and seventeen', 'plus ', 'three hundred and twenty five', 'equals', 'seven hundred'],
            ['one hundred and fifty eight', "plus ", 'two hundred and seventeen', 'plus', 'three hundred and twenty five', 'equals', 'seven hundred']
          ],
          optionList: ['one hundred and fifty eight', "plus ", 'twenty one and seven', 'thirty five hundred and sixty seven',
          'three hundred and twenty five', 'plus', 'seven hundred', 'two hundred and seventeen', 'equals'],
          id: "jumble.6",
          skills: ["written_three_place_number_values, multiple_operations"]
        ),
        const JumbleGameData(
          displayedProblem: '176 + 95 + 160 = 431', 
          multiAcceptedAnswers: [
            ['one hundred and seventy six', "plus", 'ninety five', 'plus ', 'one hundred and sixty', 'equals', 'four hundred and thirty one'],
            ['one hundred and seventy six', "plus ", 'ninety five', 'plus', 'one hundred and sixty', 'equals', 'four hundred and thirty one']
          ],
          optionList: ['ninety five', "plus ", 'four hundred and thirty one', 'seventeen and six',
          'one hundred and seventy six', 'plus', 'four thrity one', 'one hundred and sixty', 'equals'],
          id: "jumble.7",
          skills: ["written_two_place_number_values, multiple_operations"]
        ),
        const JumbleGameData(
          displayedProblem: '5.32 + 4.63 = 9.95', 
          multiAcceptedAnswers: [
            ['five and thirty two hundredths', "plus", 'four and sixty three hundredths', 'equals', 'nine and ninety five hundredths']
          ],
          optionList: ['five and thirty two hundredths', "plus ", 'four point sixty three', 'nine and ninety five hundredths',
          'four and sixty three hundredths', 'plus', 'five point thirty two', 'nine point ninety five', 'equals'],
          id: "jumble.8",
          writtenPrompt: "Write your answer in proper written form.",
          skills: ["written_decimals_two_number_places"]
        ),
        const JumbleGameData(
          displayedProblem: '0.293 + 1.954 = 2.247', 
          multiAcceptedAnswers: [
            ['two hundred and nintey three thousandths', "plus", 'one and nine hundred and fifty four thousandths', 'equals', 'two and two hundred and fourty seven thousandths']
          ],
          optionList: ['zero and two hundred and ninety three thousandths', "plus ", 'two hundred and nintey three thousandths', 'one point nine hundred and fifty four',
          'one and nine hundred and fifty four thousandths', 'plus', 'two and two hundred and fourty seven thousandths', 'equals'],
          id: "jumble.9",
          writtenPrompt: "Write your answer in proper written form.",
          skills: ["written_decimals_three_number_places"]
        ),
        const JumbleGameData(
          displayedProblem: '31 + 9 = 18 + 22', 
          multiAcceptedAnswers: [
            // this one has the plus with a space first, then the normal plus (equals)
            [
              "thirty-one", "plus ", "nine", "equals", "eighteen", "plus", "twenty-two"
            ],
            // this one has the normal plus first, then the plus with a space (equals)
            [
              "thirty-one", "plus", "nine", "equals", "eighteen", "plus ", "twenty-two"
            ],
            // this one has the plus with a space first, then the normal plus (is)
            [
              "thirty-one", "plus ", "nine", "is", "eighteen", "plus", "twenty-two"
            ],
            // this one has the normal plus first, then the plus with a space (is)
            [
              "thirty-one", "plus", "nine", "is", "eighteen", "plus ", "twenty-two"
            ]
            
          ],
          optionList: [
            "thirty-one", "nine", "plus ", "equals", "twenty-two", "eighteen", "plus", "is", "ten and eight"
          ],
          id: "jumble.10",
          skills: ["multiple_operations"]
        ),
        const JumbleGameData(
          displayedProblem: "To raise money for the band trip, 13 students showed up to help at the Benefit the Band Car Wash. They charged \$12 for a car wash and by the end of the day had washed a total of 68 cars. How much money did they earn?", 
          writtenPrompt: "What is the product of the following expression?",
          optionList: [
            "eight hundred and sixteen", "eight hundred and eighty four", "one hundred and fifty six", 
          ],
          multiAcceptedAnswers: [["eight hundred and sixteen"]],
          skills: ["two_place_multiplication", "money", "written_form"],
          id: "jumble.11"
        ),
      ]
    );
  }

  void initPlaybackBank() {

    playbackBank.addAll(
      [
        const PlaybackGameData(
          webAudioLink: '', 
          multiAcceptedAnswers: [
            ["six"]
          ],
          optionList: [
            "seven", "eight", "five", "three", "six", "one", "eight", "nine"
          ],
          writtenPrompt: "Listen to the audio and then create your response with the choices below. Only submit the number.", 
          audioTranscript: 'Five times what number results in thrity?',
          skills: ["single_digit_addition", "spoken_written_form"],
          id: "playback.1"
        ),
        const PlaybackGameData(
          webAudioLink: '', 
          multiAcceptedAnswers: [
            ["eight"]
          ],
          optionList: [
            "ten", "eight", "five", "three", "six", "one", "eight", "nine"
          ],
          writtenPrompt: "Listen to the audio and then create your response with the choices below.", 
          audioTranscript: 'Jack has 40 trading cards that he would like to give to his 5 friends. If he shares them equally, how many cards will he give to each?',
          skills: ["spoken_written_form", "single_digit_division"],
          id: "playback.2"
        ),
        const PlaybackGameData(
          webAudioLink: '', 
          multiAcceptedAnswers: [
            ["one"]
          ],
          optionList: [
            "ten", "eight", "five", "three", "six", "one", "eight", "nine", "two"
          ],
          writtenPrompt: "Listen to the audio and then create your response with the choices below.", 
          audioTranscript: "Lome's cat had 6 kittens that he gave equally to his 6 friends. How many kittens did each friend get?",
          skills: ["spoken_written_form", "single_digit_division"],
          id: "playback.3"
        ),
        const PlaybackGameData(
          webAudioLink: '', 
          multiAcceptedAnswers: [
            ["eight"]
          ],
          optionList: [
            "ten", "eight", "five", "three", "six", "one", "eight", "nine", "two"
          ],
          writtenPrompt: "Listen to the audio and then create your response with the choices below.", 
          audioTranscript: 'Raffle tickets sell for \$1 each. How many tickets can Thorn buy for \$8?',
          skills: ["spoken_written_form", "money", "single_digit_division"],
          id: "playback.4"
        ),
        const PlaybackGameData(
          webAudioLink: '', 
          multiAcceptedAnswers: [
            ["two"]
          ],
          optionList: [
            "ten", "eight", "five", "three", "six", "one", "eight", "nine", "two"
          ],
          writtenPrompt: "Listen to the audio and then create your response with the choices below.", 
          audioTranscript: 'Emily has \$12 and wants to buy some books. The books are \$6 each. How many books can Emily buy?',
          skills: ["spoken_written_form", "money", "single_digit_division"],
          id: "playback.5"
        ),
        const PlaybackGameData(
          webAudioLink: '', 
          multiAcceptedAnswers: [
            ["seven"]
          ],
          optionList: [
            "ten", "eight", "five", "three", "six", "one", "seven", "nine"
          ],
          writtenPrompt: "Listen to the audio and then create your response with the choices below. A 'mobile' is a a decorative structure that spins freely in the air",
          audioTranscript: "Art wants to display 35 of his origami figures by hanging an equal number on each of 5 mobiles. How many figures will Art hang from each mobile?",
          skills: ["spoken_written_form", "single_digit_division"],
          id: "playback.6"
        ),
        const PlaybackGameData(
          webAudioLink: '/audio/level_up_3h.mp3', 
          multiAcceptedAnswers: [
            ["She", "is", "forty", "years-old"]
          ],
          optionList: [
            "She", "eight", "five", "forty", "thrity-two", "is", "forty-eight", "years-old"
          ],
          writtenPrompt: "Listen to the audio and then create your response with the choices below", 
          audioTranscript: "If Sally's mother is 8 times older than her, and Sally is 5 years-old, how old is Sally's mother?",
          skills: ["spoken_written_form", "single_digit_multiplication"],
          id: "playback.7"
        ),
        const PlaybackGameData(
          webAudioLink: '/audio/level_up_3h.mp3', 
          multiAcceptedAnswers: [
            ["fourteen"]
          ],
          optionList: [
            "fifteen", "eleven", "seventeen", "fourteen", "twenty", "tweleve", "thirteen", "sixteen"
          ],
          writtenPrompt: "Listen to the audio and then create your response with the choices below", 
          audioTranscript: "Dancers are placed in groups of 4 for a square dance. There are 56 dancers. How many groups of 4 can be made?",
          skills: ["spoken_written_form", "single_digit_division"],
          id: "playback.8"
        ),
        const PlaybackGameData(
          webAudioLink: '/audio/level_up_3h.mp3', 
          multiAcceptedAnswers: [
            ["twenty eight"]
          ],
          optionList: [
            "twenty", "twenty nine", "twenty eight", "fourteen", "fourty two", "fifteen", "forty-eight"
          ],
          writtenPrompt: "Listen to the audio and then create your response with the choices below", 
          audioTranscript: "The refreshment table includes cups of fruit punch. There are 84 cups of fruit punch in one bowl. Suppose each dancer can get 3 cups of punch from the bowl. How many dancers does the bowl serve?",
          skills: ["spoken_written_form", "single_digit_division"],
          id: "playback.9"
        ),
        const PlaybackGameData(
          webAudioLink: '/audio/level_up_3h.mp3', 
          multiAcceptedAnswers: [
            ["two", "hundred"]
          ],
          optionList: [
            "one", "thousand", "three", "hundred", "two", "hundred thousand", "tenths", "four"
          ],
          writtenPrompt: "Listen to the audio and then create your response with the choices below", 
          audioTranscript: "Five medium-sized strawberries have about 1,000 seeds. About how many seeds does each strawberry contain?",
          skills: ["spoken_written_form", "single_digit_division"],
          id: "playback.10"
        )
      ]
    );
  }

  void initReadingBank() {

    readingBank.addAll(
      [
        const ReadAloudGameData(
          displayedProblem: "14 x 34 = ??", 
          writtenPrompt: "What is the product of the following expression?",
          addtionalInstructions: "Only say the product, do not repeat the expression.",
          multiAcceptedAnswers: [["four hundred seventy six"], ["four hundred and seventy six"], ["476"]],
          skills: ["two_place_multiplication", "self-spoken_written_form"],
          id: "reading.1"
        ),
        const ReadAloudGameData(
          displayedProblem: "When a number is multiplied by 8, the product is 64,000. What is that number?", 
          addtionalInstructions: "Only say the product, do not repeat the expression.",
          multiAcceptedAnswers: [["eight thousand"], ["8000"]],
          skills: ["three_or_more_place_multiplication", "self-spoken_written_form"],
          id: "reading.2"
        ),
        const ReadAloudGameData(
          displayedProblem: "Seven china-doll painters each painted 2 eyes on each of 22 doll faces a day. How many eyes in all did they paint in one day?", 
          addtionalInstructions: "Only say the answer, do not repeat the expression.",
          multiAcceptedAnswers: [["three hundred and eight"], ["three hundred eight"], ["308"]],
          skills: ["two_place_multiplication", "self-spoken_written_form"],
          id: "reading.3"
        ),
        const ReadAloudGameData(
          displayedProblem: "There are 36,200 pencils on each of 4 shelves at the office supply manufacturer's warehouse. How many pencils are there altogether?", 
          writtenPrompt: "What is the product of the following expression?",
          addtionalInstructions: "Only say the answer, do not repeat the expression.",
          multiAcceptedAnswers: [["one hundred and forty four thousand eight hundred"], ["144800"], ["one hundred and forty four thousand and eight hundred"], ["one hundred forty four thousand eight hundred"]],
          skills: ["three_or_more_place_multiplication", "self-spoken_written_form"],
          id: "reading.4"
        ),
        const ReadAloudGameData(
          displayedProblem: 'Gerald started a new collection with 325 bottle caps. He collects 158 more caps in September and 217 more in October. How many bottle caps did he have at the end of October?', 
          multiAcceptedAnswers: [
            ["seven hundred"]
          ],
          writtenPrompt: 'Answer the short-response question.',
          skills: ["three_place_addition", "self-spoken_written_form"],
          id: "reading.5"
        ),
        const ReadAloudGameData(
          displayedProblem: "Laura addresses 127 envelopes every week. Each envelope contains 4 pieces of paper. How many envelopes does Laura address in one year? (There are 52 weeks in a year)", 
          writtenPrompt: "What is the product of the following expression?",
          addtionalInstructions: "Only say the product, do not repeat the expression.",
          multiAcceptedAnswers: [["six thousand six hundred and four"], ["6604"], ["six thousand six hundred four"]],
          skills: ["three_or_more_place_multiplication", "self-spoken_written_form"],
          id: "reading.6"
        ),
        const ReadAloudGameData(
          displayedProblem: "21 x 11 = ??", 
          writtenPrompt: "What is the product of the following expression?",
          addtionalInstructions: "Only say the product, do not repeat the expression.",
          multiAcceptedAnswers: [["two hundred thirty one"], ["231"], ["two hundred and thirty one"]],
          skills: ["two_place_multiplication", "self-spoken_written_form"],
          id: "reading.7"
        ),
        const ReadAloudGameData(
          displayedProblem: "298 x 12 + 30 = 3,606", 
          writtenPrompt: "Read the result of the following expression.",
          addtionalInstructions: "Only say the answer, do not repeat the expression.",
          multiAcceptedAnswers: [["three thousand six hundred and six"], ["3606"], ["three thousand six hundred six"]],
          skills: ["three_or_more_place_multiplication", "multiple_operations", "self-spoken_written_form"],
          id: "reading.8"
        ),
        const ReadAloudGameData(
          displayedProblem: "1094 + 4098 = 5192", 
          writtenPrompt: "Read this expression in written form.",
          multiAcceptedAnswers: [["one thousand and ninety four plus four thousand and ninety eight equals five thousand one hundred and ninety two"], ["one thousand ninety four plus four thousand ninety eight equals five thousand one hundred ninety two"]],
          skills: ["four_or_more_place_addition", "self-spoken_written_form"],
          id: "reading.9"
          )
      ]
    );
  }

  void initTypingBank() {
    typingBank.addAll(
      [
        const TypingGameData(
          displayedProblem: '4153 + 3567 = 7720', 
          multiAcceptedAnswers: ["four thousand one hundred and fifty three plus three thousand five hundred and sixty seven equals seven thousand seven hundred and twenty",
          "four thousand one hundred and fifty three plus three thousand five hundred and sixty seven is seven thousand seven hundred and twenty"],
          skills: ["four_or_more_place_addition", "written_form"],
          id: "typing.1"
        ),
        const TypingGameData(
          displayedProblem: 'Patrick has filled 1,485 of 3,000 baseball cards. How many cards are left to be filled?', 
          multiAcceptedAnswers: ["one thousand five hundred and fifteen", "one thousand five hundred fifteen"],
          writtenPrompt: "Type the remaining card amount in standard written form.",
          skills: ["four_or_more_place_addition", "written_form"],
          id: "typing.2"
        ),
        const TypingGameData(
          displayedProblem: 'Elizabeth and Jeanne are covering a fireplace mantel with 4500 fancy tacks. Elisabeth has added 934 tacks to the mantel. Jeanne has added 1,093 tacks. How many tacks do they have to add to complete the mantel?', 
          multiAcceptedAnswers: ["two thousand four hundred and seventy three", "two thousand four hundred seventy three"],
          writtenPrompt: "Type the remaining tacks needed in written form",
          skills: ["four_or_more_place_addition", "written_form"],
          id: "typing.3"
        ),
        const TypingGameData(
          displayedProblem: 'Dancers are placed in groups of 4 for a square dance. There are 56 dancers. How many groups of 4 can be made?', 
          multiAcceptedAnswers: ["fourteen"],
          writtenPrompt: "Type just the answer",
          skills: ["two_place_addition", "word_problem_written_form"],
          id: "typing.4"
        ),
        const TypingGameData(
          displayedProblem: '194 + 203 + 576 = 973', 
          multiAcceptedAnswers: ["one hundred ninety four plus two hundred three plus five hundred seventy six is nine hundred seventy three",
          "one hundred and ninety four plus two hundred and three plus five hundred and seventy six is nine hundred and seventy three"],
          writtenPrompt: "Type the expression in written form. Use 'and' as needed.",
          skills: ["three_place_addition", "written_form"],
          id: "typing.5"
        ),
        const TypingGameData(
          displayedProblem: '0.294', 
          multiAcceptedAnswers: ["two hundred and ninety four thousandths", "zero and two hundred and ninety four thousandths"],
          writtenPrompt: "Type this number in written form.",
          skills: ["written_three_number_places", "written_form"],
          id: "typing.6"
        ),
        const TypingGameData(
          displayedProblem: '1/4 + 1/2 = 3/4', 
          multiAcceptedAnswers: ["one fourth plus one half is three fourths"],
          writtenPrompt: "Type out the expression in written form",
          skills: ["fractions", "written_form"],
          id: "typing.7"
        ),
        const TypingGameData(
          displayedProblem: '320.5 + 139.1 = 459.6', 
          multiAcceptedAnswers: ["three hundred twenty and five tenths plus one hundred thirty nine and one tenths"],
          writtenPrompt: "Type out the expression in written form",
          skills: ["four_or_more_place_addition", "written_form"],
          id: "typing.8"
        ),
        const TypingGameData(
          displayedProblem: 'A piece of fabric is 52 inches long. Sally cuts it into 4 equal pieces to make costumes for puppets. Each piece is 13 inches long.', 
          multiAcceptedAnswers: ["fifty two divided by four is thirteen", "fifty two over four is thirteen","fifty two divided by four equals thirteen", "fifty two over four equals thirteen"],
          writtenPrompt: "Write the number sentence (or expression) representing this problem using division in written form.",
          skills: ["two_place_division", "written_form", "number_sentences"],
          id: "typing.9"
        ),
        const TypingGameData(
          displayedProblem: 'Mary Beth has 215 stickers. She wants to fill 2 albums with the same number of stickers in each. She figures out that about 107 stickers will fit in each, with one left over.', 
          multiAcceptedAnswers: ["two hundred and fifteen divided by two is one hundred seven and five tenths", "two hundred and fifteen over two is one hundred seven and five tenths"],
          writtenPrompt: "Write the number sentence (or expression) representing this problem using division in written form.",
          skills: ["three_place_division", "written_form", "number_sentences"],
          id: "typing.10"
        ),
        const TypingGameData(
          displayedProblem: "Andy bought 7 videos at the mall. Each video cost \$14.95. How much money did he spend?", 
          writtenPrompt: "What is the answer of the following expression?",
          multiAcceptedAnswers: ["one hundred and four dollars and sixty five cents", "104.65", "\$104.65", "one hundred and four and sixty five hundreths"],
          skills: ["two_place_multiplication", "money", "written_form"],
          id: "typing.11"
        )
      ]
    );
  }

  void initFillBlanksBank() {
    fillBlanksBank.addAll(
      [
        const FillBlanksGameData(
          displayedProblem: 'Sally is 5 years old. Her mother 8 times as old as Sally is. How old is her mother?', 
          multiAcceptedAnswers: ["forty"], 
          writtenPrompt: 'Use the options below to answer the word problem.', 
          blankForm: "Sally's mother is  ____ years old", 
          optionList: [
            "eight", "five", "forty", "thrity-two", "forty-eight"
          ],
          skills: ["single_digit_addition", "written_form"],
          id: "fill.1"
        ),
        const FillBlanksGameData(
          displayedProblem: 'Archery Team A hit the target 367 times. Team B hit the target 412 times. How many times did they hit the target?', 
          multiAcceptedAnswers: ["seven hundred and seventy nine"], 
          writtenPrompt: 'Use the options below to answer the word problem.', 
          blankForm: "The teams hit the target ____ times", 
          optionList: [
            "eight hundred", "twenty one", "seven hundred and seventy nine", "four hundred and tweleve", "three hundred and sixty seven"
          ],
          skills: ["three_place_addition", "written_form"],
          id: "fill.2"
        ),
        const FillBlanksGameData(
          displayedProblem: 'Murphy has an article with 72,885 words and an article with 59,993 words. How many more words does the longer article have?', 
          multiAcceptedAnswers: ["tweleve thousand eight hundred and ninety two"], 
          writtenPrompt: 'Use the options below to answer the word problem.', 
          blankForm: "The longer article has ____ more words than the shorter one.", 
          optionList: [
            "seventy two thousand eight hundred and eighty five", "tweleve thousand eight hundred and ninety two", "fifty nine thousand nine hundred and ninrty three", "one hundred two thousand eight hundred and ninety two", "five hundred thousand nine thousand nine hundred and ninety three"
          ],
          skills: ["four_or_more_place_addition", "written_form"],
          id: "fill.3"
        ),
        const FillBlanksGameData(
          displayedProblem: 'A puppet show has three acts. Each act is 20 minutes long. There are 10-minute intermissions between the acts. How long will the show last?', 
          multiAcceptedAnswers: ["times", "plus", "equals"], 
          writtenPrompt: 'Use the options below to answer the word problem.', 
          blankForm: "twenty minutes ____ three acts ____ ten intermissions times three acts ____ ninety minutes total.", 
          optionList: [ "plus", "minus", "times", "minus ", "divided by", "equals"
          ],
          skills: ["multiple_operations", "written_form", "time"],
          id: "fill.4"
        ),
        const FillBlanksGameData(
          displayedProblem: '195,037', 
          multiAcceptedAnswers: ["hundred thousands", "hundreds", "ones", "ten thousands", "tens", "thousands"], 
          writtenPrompt: 'Use the blocks to label the place value of each number', 
          blankForm: "1: ____ , 0: ____ , 7: ____ , 9: ____ , 3: ____ , 5: ____ ", 
          optionList: [
            "ones", "tens", "hundreds", "ten thousands", "hundred thousands", "thousands"
          ],
          skills: ["four_or_more_number_places", "written_form"],
          id: "fill.5"
        ),
        const FillBlanksGameData(
          displayedProblem: '0.1294', 
          multiAcceptedAnswers: ["tenths", "ten thousandths", "hundredths", "thousandths", "ones"], 
          writtenPrompt: 'Use the options below to answer the word problem.', 
          blankForm: "1: ____ , 4: ____ , 2: ____ , 9: ____ , 0: ____", 
          optionList: [
            "ones", "hundreds", "tenths", "hundreths", "thousandths", "hundreds", "ten thousandths"
          ],
          skills: ["four_or_more_number_places", "written_form"],
          id: "fill.6"
        ),
        const FillBlanksGameData(
          displayedProblem: 'one thousand two hundred ninety-four ten-thousandths', 
          multiAcceptedAnswers: ["1", "2", "9", "2"], 
          writtenPrompt: 'Create the number form of this number written in written form', 
          blankForm: "0. ____ ____ ____ ____", 
          optionList: [
            "1", "3", "5", "7", "9", "2", "4", "6", "8"
          ],
          skills: ["four_or_more_number_places", "written_form"],
          id: "fill.7"
        ),
        const FillBlanksGameData(
          displayedProblem: 'Pupeteers rehearse 5 days a week, for a total of 4 hours and 10 minutes. Each rehearsal is the same length. How long is each rehearsal?', 
          multiAcceptedAnswers: ["four", "plus", "equals"], 
          writtenPrompt: 'Use the options below to answer the word problem.', 
          blankForm: "____ times sixty ____ ten ____ three hundred and fifty", 
          optionList: [
            "four", "five", "three", "plus", "minus", "equals", "times"
          ],
          skills: ["multiple_operations", "written_form"],
          id: "fill.8"
        ),
        const FillBlanksGameData(
          displayedProblem: 'Tickets to a puppet show cost \$5 for adults and \$3 for children under 16. How much would it cost a family of 2 adults and 3 children to attend the puppet show?', 
          multiAcceptedAnswers: ["ten", "nine", "nineteen"], 
          writtenPrompt: 'Use the options below to answer the word problem.', 
          blankForm: "2 Adult tickets cost ____ dollars and 3 child tickets cost ____ dollars, for a total of ____ dollars.", 
          optionList: [
            "ten", "twenty", "two", "nine", "six", "thirty", "fifteen", "nineteen", "twenty one"
          ],
          skills: ["multiple_operations", "written_form", "money"],
          id: "fill.9"
        ),
        const FillBlanksGameData(
          displayedProblem: 'Andy buys table-tennis balls to make eyes for puppets he is making. They cost \$0.50 a ball. He buys 4 boxes, each with 3 balls. How much does he spend in all?', 
          multiAcceptedAnswers: ["six"], 
          writtenPrompt: 'Use the options below to answer the word problem.', 
          blankForm: "Andy spent ____ dollars", 
          optionList: [
            "five", "ten", "twelve", "six", "two", "one"
          ],
          skills: ["two_place_multiplication", "written_form", "money"],
          id: "fill.10"
        )
      ]
    );
  }


  Future<void> initQuestionBank() async{
    DocumentReference gameDataQuestions = FirebaseFirestore.instance
        .collection("gameData")
        .doc("questions");

    DocumentSnapshot snapshot = await gameDataQuestions.get();

    if(!snapshot.exists){
      logger.d("No questions found in Firestore.");
      return;
    }
    Map<String, dynamic> questionsData = snapshot.data() as Map<String, dynamic>;
    List<dynamic> questions = questionsData['questions'];
  // Cache raw question documents as maps for later filtering
  rawQuestionDocs = questions.map<Map<String, dynamic>>((q) => Map<String, dynamic>.from(q)).toList();
    logger.i("Fetched ${questions.length} questions from Firestore");

    for (int i = 0; i < questions.length; i++) {
      var q = questions[i];
      try {
        if (q is! Map<String, dynamic>) continue;
        // Determine question type by id prefix when available
        String id = (q['id'] is String) ? q['id'] : '';

        if (id.startsWith('jumble')) {
          questionBank.add(JumbleGameData.fromFirestore(Map<String, dynamic>.from(q)));
        } else if (id.startsWith('playback')) {
          questionBank.add(PlaybackGameData.fromFirestore(Map<String, dynamic>.from(q)));
        } else if (id.startsWith('reading')) {
          questionBank.add(ReadAloudGameData.fromFirestore(Map<String, dynamic>.from(q)));
        } else if (id.startsWith('typing')) {
          questionBank.add(TypingGameData.fromFirestore(Map<String, dynamic>.from(q)));
        } else if (id.startsWith('fill')) {
          questionBank.add(FillBlanksGameData.fromFirestore(Map<String, dynamic>.from(q)));
        }
      } catch (e) {
        logger.e("Error processing question at index $i: $e");
      }
    }
    logger.i("Initialized question bank with ${questionBank.length} questions.");
  }


  Future<void> initEasyModeBank() async {
    print("Initializing easy mode question bank from Firestore...");
    DocumentReference gameDataQuestions = FirebaseFirestore.instance
        .collection("gameData")
        .doc("questions");

    DocumentSnapshot snapshot = await gameDataQuestions.get();

    DocumentReference  liveTagsDoc = FirebaseFirestore.instance
        .collection("gameData")
        .doc("liveTagsDoc");

    DocumentSnapshot liveTagsSnapshot = await liveTagsDoc.get();

    if(!snapshot.exists || !liveTagsSnapshot.exists){
      print("No questions found in Firestore or liveTagsDoc missing.");
      return;
    }
    Map<String, dynamic> questionsData = snapshot.data() as Map<String, dynamic>;
    Map<String, dynamic> liveTagsData = liveTagsSnapshot.data() as Map<String, dynamic>;

    List<dynamic> questions = questionsData['questions'];
    List<dynamic> liveTags = liveTagsData['liveTags'];

    print("Fetched ${questions.length} questions from Firestore");
    print("Fetched ${liveTags.length} live tags");

    // Use lowercase sets so comparisons become case-insensitive
    final Set<String> allowedDifficulties = {};
    final Set<String> allowedGameTypes = {};
    final Set<String> allowedFilters = {};

    for (var tag in liveTags){
      if (tag is! Map<String, dynamic>) continue;
      // Difficulty (may be a List)
      if (tag['difficulty'] is Iterable) {
        for (var diff in tag['difficulty']) {
          if (diff != null) allowedDifficulties.add(diff.toString().toLowerCase());
        }
      } else if (tag['difficulty'] != null) {
        allowedDifficulties.add(tag['difficulty'].toString().toLowerCase());
      }

      // Handle gameType (may be a List)
      if (tag['gameType'] is Iterable) {
        for (var gt in tag['gameType']) {
          if (gt != null) allowedGameTypes.add(gt.toString().toLowerCase());
        }
      } else if (tag['gameType'] != null) {
        allowedGameTypes.add(tag['gameType'].toString().toLowerCase());
      }

      // Handle filters safely (must be Iterable)
      if (tag['filters'] is Iterable) {
        for (var f in tag['filters']) {
          if (f != null) allowedFilters.add(f.toString().toLowerCase());
        }
      }
    }
    print("Allowed difficulties: $allowedDifficulties");
    print("Allowed game types: $allowedGameTypes");
    print("Allowed filters: $allowedFilters");

    for (int i = 0; i < questions.length; i++) {
      var q = questions[i];
      try {
        if (q is! Map<String, dynamic>) continue;
        final qDifficulty = q['difficulty'];
        final qGameType = q['gameType'];
        final qTags = q['tags'];

        // Local helper: match qValue against allowed set case-insensitively.
        bool matchesAllowed(dynamic qValue, Set<String> allowed) {
          if (allowed.isEmpty) return true; // accept any when allowed set is empty
          if (qValue == null) return false;
          if (qValue is Iterable) {
            for (var e in qValue) {
              if (e != null && allowed.contains(e.toString().toLowerCase())) return true;
            }
            return false;
          }
          return allowed.contains(qValue.toString().toLowerCase());
        }

        if (!matchesAllowed(qDifficulty, allowedDifficulties)) {
          print('Skipping question index $i (id=${q['id'] ?? '<no id>'}) due to difficulty mismatch: $qDifficulty');
          continue;
        }
        if (!matchesAllowed(qGameType, allowedGameTypes)) {
          continue;
        }


        bool filterMatch = true; // assume true, prove false if any missing
        if (allowedFilters.isNotEmpty) {
          if (qTags is List) {
            for (var requiredFilter in allowedFilters) {
              // If any required filter is NOT in qTags, mark false and break
              if (!qTags.contains(requiredFilter)) {
                filterMatch = false;
                break;
              }
            }
          } else {
            // If tags is not a list, just check if that single tag matches all filters (impossible unless 1 filter)
            filterMatch = allowedFilters.length == 1 && allowedFilters.contains(qTags.toString());
          }
        }

        // If filters exist but question doesn’t match them all, skip it
        if (!filterMatch) continue;


        // Determine question type by id prefix when available
        String id = (q['id'] is String) ? q['id'] : '';

        if (id.startsWith('jumble')) {
          easyModeBank.add(JumbleGameData.fromFirestore(Map<String, dynamic>.from(q)));
        } else if (id.startsWith('playback')) {
          easyModeBank.add(PlaybackGameData.fromFirestore(Map<String, dynamic>.from(q)));
        } else if (id.startsWith('reading')) {
          easyModeBank.add(ReadAloudGameData.fromFirestore(Map<String, dynamic>.from(q)));
        } else if (id.startsWith('typing')) {
          easyModeBank.add(TypingGameData.fromFirestore(Map<String, dynamic>.from(q)));
        } else if (id.startsWith('fill')) {
          easyModeBank.add(FillBlanksGameData.fromFirestore(Map<String, dynamic>.from(q)));
        } else {
          // Fallback heuristics based on keys
          if (q.containsKey('webAudioLink')) {
            easyModeBank.add(PlaybackGameData.fromFirestore(Map<String, dynamic>.from(q)));
          } else if (q.containsKey('blankForm')) {
            easyModeBank.add(FillBlanksGameData.fromFirestore(Map<String, dynamic>.from(q)));
          } else if (q.containsKey('displayedProblem') && q.containsKey('optionList')) {
            // assume jumble-like
            easyModeBank.add(JumbleGameData.fromFirestore(Map<String, dynamic>.from(q)));
          } else if (q.containsKey('displayedProblem') && q.containsKey('multiAcceptedAnswers')) {
            // default to ReadAloud if unsure
            easyModeBank.add(ReadAloudGameData.fromFirestore(Map<String, dynamic>.from(q)));
          } else {
            print('Skipping unknown question format at index $i: $q');
          }
        }
      } catch (e, st) {
        // Log and continue so one malformed entry doesn't stop loading
        print('Failed to load question at index $i: $e');
        print(q);
        print(st);
        continue;
      }
    }

    print("Loaded ${easyModeBank.length} easy questions");
  }

  Future<void> initIntermediateModeBank() async {
    intermediateModeBank.addAll(
      [
        const JumbleGameData(
          displayedProblem: 'Archery Team A hit the target 367 times. Team B hit the target 412 times. Did the two teams hit the target 800 times? If not, by how much did they miss?', 
          multiAcceptedAnswers: [
            ["They", "missed", "twenty-one", "times"]
          ],
          writtenPrompt: 'Answer the short-response question using the blocks below.',
          optionList: [
            "seven hundred and seventy nine", "They", "twenty-one", "missed", "seven hundred seventy", "times"
          ],
          id: "jumble.3",
          skills: ["word_problem_written_form", "multiple_operations", "three_place_subtraction"]
        ),
        const JumbleGameData(
          displayedProblem: '375 + 109 = 484', 
          multiAcceptedAnswers: [
            ['three hundred seventy five', "plus", 'one hundred and nine', 'equals', 'four hundred eighty four']
          ],
          optionList: ['three hundred seventy five', "minus", 'one o nine', 'three seven five',
          'one hundred and nine', 'plus', 'thirty seven and five', 'four hundred eighty four', 'equals'],
          id: "jumble.5",
          skills: ["written_three_place_number_values"]
        ),
        const PlaybackGameData(
          webAudioLink: '', 
          multiAcceptedAnswers: [
            ["one"]
          ],
          optionList: [
            "ten", "eight", "five", "three", "six", "one", "eight", "nine", "two"
          ],
          writtenPrompt: "Listen to the audio and then create your response with the choices below.", 
          audioTranscript: "Lome's cat had 6 kittens that he gave equally to his 6 friends. How many kittens did each friend get?",
          skills: ["spoken_written_form", "single_digit_division"],
          id: "playback.3"
        ),
        const PlaybackGameData(
          webAudioLink: '', 
          multiAcceptedAnswers: [
            ["eight"]
          ],
          optionList: [
            "ten", "eight", "five", "three", "six", "one", "eight", "nine", "two"
          ],
          writtenPrompt: "Listen to the audio and then create your response with the choices below.", 
          audioTranscript: 'Raffle tickets sell for \$1 each. How many tickets can Thorn buy for \$8?',
          skills: ["spoken_written_form", "money", "single_digit_division"],
          id: "playback.4"
        ),
        const PlaybackGameData(
          webAudioLink: '', 
          multiAcceptedAnswers: [
            ["two"]
          ],
          optionList: [
            "ten", "eight", "five", "three", "six", "one", "eight", "nine", "two"
          ],
          writtenPrompt: "Listen to the audio and then create your response with the choices below.", 
          audioTranscript: 'Emily has \$12 and wants to buy some books. The books are \$6 each. How many books can Emily buy?',
          skills: ["spoken_written_form", "money", "single_digit_division"],
          id: "playback.5"
        ),
        const ReadAloudGameData(
          displayedProblem: "14 x 34 = ??", 
          writtenPrompt: "What is the product of the following expression?",
          addtionalInstructions: "Only say the product, do not repeat the expression.",
          multiAcceptedAnswers: [["four hundred seventy six"], ["four hundred and seventy six"], ["476"]],
          skills: ["two_place_multiplication", "self-spoken_written_form"],
          id: "reading.1"
        ),
        const ReadAloudGameData(
          displayedProblem: "When a number is multiplied by 8, the product is 64,000. What is that number?", 
          addtionalInstructions: "Only say the product, do not repeat the expression.",
          multiAcceptedAnswers: [["eight thousand"], ["8000"]],
          skills: ["three_or_more_place_multiplication", "self-spoken_written_form"],
          id: "reading.2"
        ),
        const TypingGameData(
          displayedProblem: 'Elizabeth and Jeanne are covering a fireplace mantel with 4500 fancy tacks. Elisabeth has added 934 tacks to the mantel. Jeanne has added 1,093 tacks. How many tacks do they have to add to complete the mantel?', 
          multiAcceptedAnswers: ["two thousand four hundred and seventy three", "two thousand four hundred seventy three"],
          writtenPrompt: "Type the remaining tacks needed in written form",
          skills: ["four_or_more_place_addition", "written_form"],
          id: "typing.3"
        ),
        const TypingGameData(
          displayedProblem: 'Dancers are placed in groups of 4 for a square dance. There are 56 dancers. How many groups of 4 can be made?', 
          multiAcceptedAnswers: ["fourteen"],
          writtenPrompt: "Type just the answer",
          skills: ["two_place_addition", "word_problem_written_form"],
          id: "typing.4"
        ),
        const TypingGameData(
          displayedProblem: '194 + 203 + 576 = 973', 
          multiAcceptedAnswers: ["one hundred ninety four plus two hundred three plus five hundred seventy six is nine hundred seventy three",
          "one hundred and ninety four plus two hundred and three plus five hundred and seventy six is nine hundred and seventy three"],
          writtenPrompt: "Type the expression in written form. Use 'and' as needed.",
          skills: ["three_place_addition", "written_form"],
          id: "typing.5"
        ),
        const FillBlanksGameData(
          displayedProblem: 'A puppet show has three acts. Each act is 20 minutes long. There are 10-minute intermissions between the acts. How long will the show last?', 
          multiAcceptedAnswers: ["times", "plus", "equals"], 
          writtenPrompt: 'Use the options below to answer the word problem.', 
          blankForm: "twenty minutes ____ three acts ____ ten intermissions times three acts ____ ninety minutes total.", 
          optionList: [ "plus", "minus", "times", "minus ", "divided by", "equals"
          ],
          skills: ["multiple_operations", "written_form", "time"],
          id: "fill.4"
        ),
        const FillBlanksGameData(
          displayedProblem: '195,037', 
          multiAcceptedAnswers: ["hundred thousands", "hundreds", "ones", "ten thousands", "tens", "thousands"], 
          writtenPrompt: 'Use the blocks to label the place value of each number', 
          blankForm: "1: ____ , 0: ____ , 7: ____ , 9: ____ , 3: ____ , 5: ____ ", 
          optionList: [
            "ones", "tens", "hundreds", "ten thousands", "hundred thousands", "thousands"
          ],
          skills: ["four_or_more_number_places", "written_form"],
          id: "fill.5"
        ),
        const TypingGameData(
          displayedProblem: 'Mary Beth has 215 stickers. She wants to fill 2 albums with the same number of stickers in each. She figures out that about 107 stickers will fit in each, with one left over.', 
          multiAcceptedAnswers: ["two hundred and fifteen divided by two is one hundred seven and five tenths", "two hundred and fifteen over two is one hundred seven and five tenths"],
          writtenPrompt: "Write the number sentence (or expression) representing this problem using division in written form.",
          skills: ["three_place_division", "written_form", "number_sentences"],
          id: "typing.10"
        ),
        const PlaybackGameData(
          webAudioLink: '/audio/level_up_3h.mp3', 
          multiAcceptedAnswers: [
            ["twenty eight"]
          ],
          optionList: [
            "twenty", "twenty nine", "twenty eight", "fourteen", "fourty two", "fifteen", "forty-eight"
          ],
          writtenPrompt: "Listen to the audio and then create your response with the choices below", 
          audioTranscript: "The refreshment table includes cups of fruit punch. There are 84 cups of fruit punch in one bowl. Suppose each dancer can get 3 cups of punch from the bowl. How many dancers does the bowl serve?",
          skills: ["spoken_written_form", "single_digit_division"],
          id: "playback.9"
        ),
      ]
    );
  }

  Future<void> initHardModeBank() async {
    hardModeBank.addAll(
      [
        const FillBlanksGameData(
          displayedProblem: '0.1294', 
          multiAcceptedAnswers: ["tenths", "ten thousandths", "hundredths", "thousandths", "ones"], 
          writtenPrompt: 'Use the options below to answer the word problem.', 
          blankForm: "1: ____ , 4: ____ , 2: ____ , 9: ____ , 0: ____", 
          optionList: [
            "ones", "hundreds", "tenths", "hundreths", "thousandths", "hundreds", "ten thousandths"
          ],
          skills: ["four_or_more_number_places", "written_form"],
          id: "fill.6"
        ),
        const FillBlanksGameData(
          displayedProblem: 'one thousand two hundred ninety-four ten-thousandths', 
          multiAcceptedAnswers: ["1", "2", "9", "2"], 
          writtenPrompt: 'Create the number form of this number written in written form', 
          blankForm: "0. ____ ____ ____ ____", 
          optionList: [
            "1", "3", "5", "7", "9", "2", "4", "6", "8"
          ],
          skills: ["four_or_more_number_places", "written_form"],
          id: "fill.7"
        ),
        const TypingGameData(
          displayedProblem: '0.294', 
          multiAcceptedAnswers: ["two hundred and ninety four thousandths", "zero and two hundred and ninety four thousandths"],
          writtenPrompt: "Type this number in written form.",
          skills: ["written_three_number_places", "written_form"],
          id: "typing.6"
        ),
        const TypingGameData(
          displayedProblem: '1/4 + 1/2 = 3/4', 
          multiAcceptedAnswers: ["one fourth plus one half is three fourths"],
          writtenPrompt: "Type out the expression in written form",
          skills: ["fractions", "written_form"],
          id: "typing.7"
        ),
        const ReadAloudGameData(
          displayedProblem: "Seven china-doll painters each painted 2 eyes on each of 22 doll faces a day. How many eyes in all did they paint in one day?", 
          addtionalInstructions: "Only say the answer, do not repeat the expression.",
          multiAcceptedAnswers: [["three hundred and eight"], ["three hundred eight"], ["308"]],
          skills: ["two_place_multiplication", "self-spoken_written_form"],
          id: "reading.3"
        ),
        const ReadAloudGameData(
          displayedProblem: "There are 36,200 pencils on each of 4 shelves at the office supply manufacturer's warehouse. How many pencils are there altogether?", 
          writtenPrompt: "What is the product of the following expression?",
          addtionalInstructions: "Only say the answer, do not repeat the expression.",
          multiAcceptedAnswers: [["one hundred and forty four thousand eight hundred"], ["144800"], ["one hundred and forty four thousand and eight hundred"], ["one hundred forty four thousand eight hundred"]],
          skills: ["three_or_more_place_multiplication", "self-spoken_written_form"],
          id: "reading.4"
        ),
        const ReadAloudGameData(
          displayedProblem: 'Gerald started a new collection with 325 bottle caps. He collects 158 more caps in September and 217 more in October. How many bottle caps did he have at the end of October?', 
          multiAcceptedAnswers: [
            ["seven hundred"]
          ],
          writtenPrompt: 'Answer the short-response question.',
          skills: ["three_place_addition", "self-spoken_written_form"],
          id: "reading.5"
        ),
        const PlaybackGameData(
          webAudioLink: '', 
          multiAcceptedAnswers: [
            ["seven"]
          ],
          optionList: [
            "ten", "eight", "five", "three", "six", "one", "seven", "nine"
          ],
          writtenPrompt: "Listen to the audio and then create your response with the choices below. A 'mobile' is a a decorative structure that spins freely in the air",
          audioTranscript: "Art wants to display 35 of his origami figures by hanging an equal number on each of 5 mobiles. How many figures will Art hang from each mobile?",
          skills: ["spoken_written_form", "single_digit_division"],
          id: "playback.6"
        ),
        const PlaybackGameData(
          webAudioLink: '/audio/level_up_3h.mp3', 
          multiAcceptedAnswers: [
            ["She", "is", "forty", "years-old"]
          ],
          optionList: [
            "She", "eight", "five", "forty", "thrity-two", "is", "forty-eight", "years-old"
          ],
          writtenPrompt: "Listen to the audio and then create your response with the choices below", 
          audioTranscript: "If Sally's mother is 8 times older than her, and Sally is 5 years-old, how old is Sally's mother?",
          skills: ["spoken_written_form", "single_digit_multiplication"],
          id: "playback.7"
        ),
        const PlaybackGameData(
          webAudioLink: '/audio/level_up_3h.mp3', 
          multiAcceptedAnswers: [
            ["fourteen"]
          ],
          optionList: [
            "fifteen", "eleven", "seventeen", "fourteen", "twenty", "tweleve", "thirteen", "sixteen"
          ],
          writtenPrompt: "Listen to the audio and then create your response with the choices below", 
          audioTranscript: "Dancers are placed in groups of 4 for a square dance. There are 56 dancers. How many groups of 4 can be made?",
          skills: ["spoken_written_form", "single_digit_division"],
          id: "playback.8"
        ),
        const ReadAloudGameData(
          displayedProblem: "Laura addresses 127 envelopes every week. Each envelope contains 4 pieces of paper. How many envelopes does Laura address in one year? (There are 52 weeks in a year)", 
          writtenPrompt: "What is the product of the following expression?",
          addtionalInstructions: "Only say the product, do not repeat the expression.",
          multiAcceptedAnswers: [["six thousand six hundred and four"], ["6604"], ["six thousand six hundred four"]],
          skills: ["three_or_more_place_multiplication", "self-spoken_written_form"],
          id: "reading.6"
        ),
        const ReadAloudGameData(
          displayedProblem: "21 x 11 = ??", 
          writtenPrompt: "What is the product of the following expression?",
          addtionalInstructions: "Only say the product, do not repeat the expression.",
          multiAcceptedAnswers: [["two hundred thirty one"], ["231"]],
          skills: ["two_place_multiplication", "self-spoken_written_form"],
          id: "reading.7"
        ),
        const TypingGameData(
          displayedProblem: '320.5 + 139.1 = 459.6', 
          multiAcceptedAnswers: ["three hundred twenty and five tenths plus one hundred thirty nine and one tenths"],
          writtenPrompt: "Type out the expression in written form",
          skills: ["four_or_more_place_addition", "written_form"],
          id: "typing.8"
        ),
        const TypingGameData(
          displayedProblem: 'A piece of fabric is 52 inches long. Sally cuts it into 4 equal pieces to make costumes for puppets. Each piece is 13 inches long.', 
          multiAcceptedAnswers: ["fifty two divided by four is thirteen", "fifty two over four is thirteen","fifty two divided by four equals thirteen", "fifty two over four equals thirteen"],
          writtenPrompt: "Write the number sentence (or expression) representing this problem using division in written form.",
          skills: ["two_place_division", "written_form", "number_sentences"],
          id: "typing.9"
        ),
      ]
    );
  }
  
  FillBlanksGameData getRandomFillBlanksElement() {
    if (fillBlanksBank.isNotEmpty) {
      int randomIndex = random.nextInt(fillBlanksBank.length);
      return fillBlanksBank[randomIndex];
    } else {
      throw Exception('The fillBlanksBank data bank is empty');
    }
  }

  JumbleGameData getRandomJumbleElement() {
    if (jumbleBank.isNotEmpty) {
      int randomIndex = random.nextInt(jumbleBank.length);
      return jumbleBank[randomIndex];
    } else {
      throw Exception('The jumbleBank data bank is empty');
    }
  }

  ReadAloudGameData getRandomReadingElement() {
    if (readingBank.isNotEmpty) {
      int randomIndex = random.nextInt(readingBank.length);
      return readingBank[randomIndex];
    } else {
      throw Exception('The readingBank data bank is empty');
    }
  }

  PlaybackGameData getRandomPlaybackElement() {
    if (playbackBank.isNotEmpty) {
      int randomIndex = random.nextInt(playbackBank.length);
      return playbackBank[randomIndex];
    } else {
      throw Exception('The playbackBank data bank is empty');
    }
  }

  TypingGameData getRandomTypingElement() {
    if (typingBank.isNotEmpty) {
      int randomIndex = random.nextInt(typingBank.length);
      return typingBank[randomIndex];
    } else {
      throw Exception('The typingBank data bank is empty');
    }
  }

  List<GameData> getSeriesByDifficulty(DifficultyType type) {
    switch(type) {
      case DifficultyType.random:
      case DifficultyType.easy:
        return getEasyModeSeries();
      case DifficultyType.intermediate:
        return getIntermediateModeSeries();
      case DifficultyType.hard:
        return getHardModeSeries();
    }
  }

  List<GameData> getEasyModeSeries() {
    if (easyModeBank.isEmpty) {
      initEasyModeBank();
    }
      
    return easyModeBank;
  }

  List<GameData> getIntermediateModeSeries() {
    if (intermediateModeBank.isEmpty) {
      initIntermediateModeBank();
    }

    return intermediateModeBank;
  }

  List<GameData> getHardModeSeries() {
    if (hardModeBank.isEmpty) {
      initHardModeBank();
    } 
    
    return hardModeBank;
  }

  List<GameData> getAllQuestions(){
    if (questionBank.isEmpty) {
      initQuestionBank();
    }
    return questionBank;
  }

  List<GameData> getFilteredQuestions(SequenceData sequenceData){
    // Prefer using cached raw Firestore docs (populated by initQuestionBank)
    final List<Map<String, dynamic>> sourceDocs = rawQuestionDocs.isNotEmpty
        ? rawQuestionDocs
        : (getAllQuestions().isNotEmpty ? rawQuestionDocs : <Map<String, dynamic>>[]);

    if (sourceDocs.isEmpty) {
      print('No raw question docs available for filtering. Ensure initQuestionBank() ran.');
      return <GameData>[];
    }

    // Build lowercase allowed sets
    final Set<String> allowedDifficulties = sequenceData.difficulty.map((e) => e.toString().toLowerCase()).toSet();
    final Set<String> allowedGameTypes = sequenceData.gameType.map((e) => e.toString().toLowerCase()).toSet();
    final Set<String> allowedFilters = sequenceData.filters.map((e) => e.toString().toLowerCase()).toSet();

    final List<GameData> results = [];

    for (int i = 0; i < sourceDocs.length; i++) {
      final q = sourceDocs[i];
      try {
        final qDifficulty = q['difficulty'];
        final qGameType = q['gameType'];
        final qTags = q['tags'];

        bool matchesAllowed(dynamic qValue, Set<String> allowed) {
          if (allowed.isEmpty) return true;
          if (qValue == null) return false;
          if (qValue is Iterable) {
            for (var e in qValue) {
              if (e != null && allowed.contains(e.toString().toLowerCase())) return true;
            }
            return false;
          }
          return allowed.contains(qValue.toString().toLowerCase());
        }

        if (!matchesAllowed(qDifficulty, allowedDifficulties)) continue;
        if (!matchesAllowed(qGameType, allowedGameTypes)) continue;

        bool filterMatch = true;
        if (allowedFilters.isNotEmpty) {
          if (qTags is Iterable) {
            final Set<String> qTagSet = qTags.map((e) => e.toString().toLowerCase()).toSet();
            for (var required in allowedFilters) {
              if (!qTagSet.contains(required)) {
                filterMatch = false;
                break;
              }
            }
          } else if (qTags != null) {
            filterMatch = allowedFilters.length == 1 && allowedFilters.contains(qTags.toString().toLowerCase());
          } else {
            filterMatch = false;
          }
        }
        if (!filterMatch) continue;

        // Convert to GameData subtype and add to results
        final String id = (q['id'] is String) ? q['id'] as String : '';
        if (id.startsWith('jumble')) {
          results.add(JumbleGameData.fromFirestore(Map<String, dynamic>.from(q)));
        } else if (id.startsWith('playback')) {
          results.add(PlaybackGameData.fromFirestore(Map<String, dynamic>.from(q)));
        } else if (id.startsWith('reading')) {
          results.add(ReadAloudGameData.fromFirestore(Map<String, dynamic>.from(q)));
        } else if (id.startsWith('typing')) {
          results.add(TypingGameData.fromFirestore(Map<String, dynamic>.from(q)));
        } else if (id.startsWith('fill')) {
          results.add(FillBlanksGameData.fromFirestore(Map<String, dynamic>.from(q)));
        } else {
          if (q.containsKey('webAudioLink')) {
            results.add(PlaybackGameData.fromFirestore(Map<String, dynamic>.from(q)));
          } else if (q.containsKey('blankForm')) {
            results.add(FillBlanksGameData.fromFirestore(Map<String, dynamic>.from(q)));
          } else if (q.containsKey('displayedProblem') && q.containsKey('optionList')) {
            results.add(JumbleGameData.fromFirestore(Map<String, dynamic>.from(q)));
          } else if (q.containsKey('displayedProblem') && q.containsKey('multiAcceptedAnswers')) {
            results.add(ReadAloudGameData.fromFirestore(Map<String, dynamic>.from(q)));
          }
        }
      } catch (e, st) {
        print('Failed to load question at index $i: $e');
        print(q);
        print(st);
        continue;
      }
    }

    print('Loaded ${results.length} filtered questions for sequence "${sequenceData.name}"');
    return results;
  }
}