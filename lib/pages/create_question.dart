import 'package:flutter/material.dart';
import 'package:onwards/pages/constants.dart';
import 'package:onwards/pages/game_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum QuestionGameType { jumble, playback, typing, fillBlanks, readAloud }
enum Difficulty { Easy, Medium, Hard }

class CustomQuestionPage extends StatefulWidget {
  const CustomQuestionPage({super.key});

  @override
  State<CustomQuestionPage> createState() => _CustomQuestionPageState();
}

class _CustomQuestionPageState extends State<CustomQuestionPage> {
  final TextEditingController _displayProblemController = TextEditingController();
  final TextEditingController _optionListController = TextEditingController();
  final TextEditingController _acceptedAnswersController = TextEditingController();
  final TextEditingController _skillsController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();

  // Playback specific controllers
  final TextEditingController _audioTranscriptController = TextEditingController();
  final TextEditingController _webAudioLinkController = TextEditingController();

  // Typing
  final TextEditingController _multiAcceptedAnswersController = TextEditingController();

  // FillBlanks
  final TextEditingController _blankFormController = TextEditingController();

  QuestionGameType? _selectedGameType;
  Difficulty _selectedDifficulty = Difficulty.Easy;

  bool _hasText(TextEditingController c) =>
    c.text.trim().isNotEmpty;

  bool _requireAll(List<TextEditingController> fields) =>
    fields.every(_hasText);

  Future<void> _onSave() async {
    final gameType = _selectedGameType;
    if (gameType == null) return;
    bool isValid = false;

    switch (gameType) {
      case QuestionGameType.jumble:
        isValid = _requireAll([
          _displayProblemController,
          _optionListController,
          _acceptedAnswersController,
        ]);
        break;

      case QuestionGameType.playback:
        isValid = _requireAll([
          _audioTranscriptController,
          _webAudioLinkController,
          _optionListController,
          _acceptedAnswersController,
        ]);
        break;

      case QuestionGameType.typing:
        isValid = _requireAll([
          _displayProblemController,
          _multiAcceptedAnswersController,
        ]);
        break;

      case QuestionGameType.fillBlanks:
        isValid = _requireAll([
          _displayProblemController,
          _blankFormController,
          _optionListController,
          _acceptedAnswersController,
        ]);
        break;

      case QuestionGameType.readAloud:
        isValid = _requireAll([
          _displayProblemController,
          _multiAcceptedAnswersController,
        ]);
        break;
    }

    if (!isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    final docRef =
        FirebaseFirestore.instance.collection('gameData').doc('questions');

    // Fields
    final optionList = _optionListController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final acceptedAnswers = _acceptedAnswersController.text
        .split(' ')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final skills = _skillsController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final tags = _tagsController.text
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

    // Typing
    final multiAcceptedAnswers = _multiAcceptedAnswersController.text
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

    // FILLBLANKS
    final blankForm = _blankFormController.text.trim();

    // Base fields
    final String id =
        FirebaseFirestore.instance.collection('_').doc().id;

    late final Map<String, dynamic> question;

    // JUMBLE
    if (_selectedGameType == QuestionGameType.jumble) {
      question = {
        'id': id,
        'gameType': 'Jumble',
        'type': 'JumbleGameData',
        'displayedProblem': _displayProblemController.text.trim(),
        'writtenPrompt': _displayProblemController.text.trim(),
        'optionList': optionList,
        'multiAcceptedAnswers': acceptedAnswers,
        'skills': skills,
        'tags': tags,
        'difficulty': _selectedDifficulty.name,
        'score': 10,
      };
    }

    //  PLAYBACK 
    else if (_selectedGameType == QuestionGameType.playback) {
      question = {
        'id': id,
        'gameType': 'Playback',
        'type': 'PlaybackGameData',
        'audioTranscript': _audioTranscriptController.text.trim(),
        'webAudioLink': _webAudioLinkController.text.trim(),
        'writtenPrompt': 'Listen to the audio and then create your response with the choices below.',
        'optionList': optionList,
        'multiAcceptedAnswers': acceptedAnswers,
        'skills': skills,
        'tags': tags,
        'difficulty': _selectedDifficulty.name,
      };
    }

    // TYPING
    else if (_selectedGameType == QuestionGameType.typing){
      question = {
        'id': id,
        'gameType': 'Typing',
        'type': 'TypingGameData',
        'displayedProblem': _displayProblemController.text.trim(),
        'multiAcceptedAnswers': multiAcceptedAnswers,
        'skills': skills,
        'tags': tags,
        'difficulty': _selectedDifficulty.name,
      };
    }

    // FILLBLANKS
    else if (_selectedGameType == QuestionGameType.fillBlanks) {
      question = {
        'id': id,
        'gameType': 'FillBlanks',
        'type': 'FillBlanksGameData',
        'blankform': blankForm,
        'displayedProblem': _displayProblemController.text.trim(),
        'writtenPrompt': "Use the options below to answer the word problem.",
        'multiAcceptedAnswers': acceptedAnswers,
        'optionList': optionList,
        'skills': skills,
        'tags': tags,
        'difficulty': _selectedDifficulty.name,
      };
    }

    // READALOUD
    else if (_selectedGameType == QuestionGameType.readAloud) {
      question = {
        'id': id,
        'gameType': 'ReadAloud',
        'type': 'ReadAloudGameData',
        'additionalInstructions': 'Only say the product, do not repeat the expression.',
        'writtenPrompt': 'What is the product of the following expression?',
        'displayedProblem': _displayProblemController.text.trim(),
        'optionList': optionList,
        'multiAcceptedAnswers': multiAcceptedAnswers,
        'skills': skills,
        'tags': tags,
        'difficulty': _selectedDifficulty.name,
      };
    }

    try {
      await docRef.set(
        {
          'questions': FieldValue.arrayUnion([question]),
        },
        SetOptions(merge: true),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Question saved')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save question: $e')),
        );
      }
    }
  }

  Widget _buildDifficultySelector() {
    return Wrap(
      spacing: 10,
      children: Difficulty.values.map((difficulty) {
        final isSelected = _selectedDifficulty == difficulty;

        return ChoiceChip(
          label: Text(
            difficulty.name.toUpperCase(),
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black,
              fontWeight: FontWeight.w600,
            ),
          ),
          selected: isSelected,
          selectedColor: Colors.blue,
          backgroundColor: Colors.grey.shade300,
          onSelected: (_) {
            setState(() {
              _selectedDifficulty = difficulty;
            });
          },
        );
      }).toList(),
    );
  }



  @override
  Widget build(BuildContext context) {
    const ColorProfile profile = lightFlavor;

  return Scaffold(
      appBar: AppBar(
        title: const Text('Custom Question'),
        backgroundColor: profile.headerColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Enter new question for the Database:',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 12),

            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(top: 8.0, bottom: 4.0),
                child: Text('Select question type:', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            Wrap(
              spacing: 8.0,
              children: QuestionGameType.values.map((gt) {
                final label = () {
                  switch (gt) {
                    case QuestionGameType.jumble:
                      return 'Jumble';
                    case QuestionGameType.playback:
                      return 'Playback';
                    case QuestionGameType.typing:
                      return 'Typing';
                    case QuestionGameType.fillBlanks:
                      return 'Fill Blanks';
                    case QuestionGameType.readAloud:
                      return 'Read Aloud';
                  }
                }();
                return ChoiceChip(
                  label: Text(label,
                      style: TextStyle(
                      color: _selectedGameType == gt ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  selected: _selectedGameType == gt,
                  selectedColor: Colors.blue,
                  backgroundColor: Colors.grey.shade300,
                  onSelected: (selected) {
                    setState(() {
                      _selectedGameType = selected ? gt : null;
                    });
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 12),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Difficulty',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 6),

            _buildDifficultySelector(),

            // Jumble Question Inputs -----------------------------
            if (_selectedGameType == QuestionGameType.jumble) ...[
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Jumble Question Setup', style: TextStyle(fontWeight: FontWeight.bold)),
              ),

              const SizedBox(height: 8),

              TextField(
                controller: _displayProblemController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Displayed Problem',
                  hintText: 'Sally is 5 years old...',
                ),
                maxLines: 3,
              ),

              const SizedBox(height: 8),

              TextField(
                controller: _optionListController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Option List (comma-separated)',
                  hintText: 'She, eight, five, forty, is, old, years',
                ),
              ),

              const SizedBox(height: 8),

              TextField(
                controller: _acceptedAnswersController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Accepted Answers (space-separated)',
                  hintText: 'She is forty years old',
                ),
              ),

              const SizedBox(height: 8),

              TextField(
                controller: _skillsController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Skills (comma-separated)',
                  hintText: 'single_digit_addition, word_problem_written_form',
                ),
              ),

              const SizedBox(height: 8),

              TextField(
                controller: _tagsController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Tags (comma-separated)',
                  hintText: 'multiplication, word-problem',
                ),
              ),
            ],

            // Playback Question Input -----------------------------
            if (_selectedGameType == QuestionGameType.playback) ...[
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Playback Question Setup',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),

              const SizedBox(height: 8),

              TextField(
                controller: _audioTranscriptController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Audio Transcript',
                  hintText: 'Five times what number results in thirty?',
                ),
                maxLines: 2,
              ),

              const SizedBox(height: 8),

              TextField(
                controller: _optionListController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Option List (comma-separated)',
                  hintText: 'seven, eight, five',
                ),
              ),

              const SizedBox(height: 8),

              TextField(
                controller: _acceptedAnswersController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Accepted Answers (space-separated)',
                  hintText: 'six',
                ),
              ),

              const SizedBox(height: 8),

              TextField(
                controller: _skillsController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Skills (comma-separated)',
                  hintText: 'single_digit_addition, spoken_written_form',
                ),
              ),

              const SizedBox(height: 8),

              TextField(
                controller: _tagsController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Tags (comma-separated)',
                  hintText: 'multiplication, audio, listening',
                ),
              ),
            ],
            
            // Typing Question Input -----------------------------
            if (_selectedGameType == QuestionGameType.typing) ...[
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Typing Question Setup', style: TextStyle(fontWeight: FontWeight.bold)),
              ),

              const SizedBox(height: 8),

              TextField(
                controller: _displayProblemController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Displayed Problem',
                  hintText: '4153 + 3567 = 7720',
                ),
                maxLines: 3,
              ),

              const SizedBox(height: 8),

              TextField(
                controller: _multiAcceptedAnswersController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Accepted Answers (comma-separated)',
                  hintText: 'four thousand one hundred and fifty three plus three thousand five hundred and sixty seven equals seven thousand seven hundred and twenty',
                ),
              ),

              const SizedBox(height: 8),

              TextField(
                controller: _skillsController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Skills (comma-separated)',
                  hintText: 'single_digit_addition, word_problem_written_form',
                ),
              ),

              const SizedBox(height: 8),

              TextField(
                controller: _tagsController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Tags (comma-separated)',
                  hintText: 'multiplication, word-problem',
                ),
              ),
            ],
            
            // Fillblanks Question Input -----------------------------
            if (_selectedGameType == QuestionGameType.fillBlanks) ...[
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Fill Blank Question Setup', style: TextStyle(fontWeight: FontWeight.bold)),
              ),

              const SizedBox(height: 8),

              TextField(
                controller: _displayProblemController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Displayed Problem',
                  hintText: 'Archery Team A hit the target 367 times. Team B hit the target 412 times. How many times did they hit the target?',
                ),
                maxLines: 3,
              ),

              const SizedBox(height: 8),

              TextField(
                controller: _blankFormController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Blank Form',
                  hintText: 'The teams hit the target ____ times',
                ),
              ),

              const SizedBox(height: 8),

              TextField(
                controller: _optionListController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Option List (comma-separated)',
                  hintText: 'eight hundred, twenty one, seven hundred and seventy nine',
                ),
              ),

              const SizedBox(height: 8),

              TextField(
                controller: _acceptedAnswersController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Accepted Answer (space-separated)',
                  hintText: 'seven hundred and seventy nine',
                ),
              ),

              const SizedBox(height: 8),

              TextField(
                controller: _skillsController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Skills (comma-separated)',
                  hintText: 'single_digit_addition, written_form',
                ),
              ),

              const SizedBox(height: 8),

              TextField(
                controller: _tagsController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Tags (comma-separated)',
                  hintText: 'addition, fill-blank',
                ),
              ),
            ],

            // ReadAloud Question Input -----------------------------
            if (_selectedGameType == QuestionGameType.readAloud) ...[
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Read Aloud Question Setup', style: TextStyle(fontWeight: FontWeight.bold)),
              ),

              const SizedBox(height: 8),

              TextField(
                controller: _displayProblemController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Displayed Problem',
                  hintText: 'What is the product of 7 and 8?',
                ),
                maxLines: 3,
              ),

              const SizedBox(height: 8),

              TextField(
                controller: _multiAcceptedAnswersController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Accepted Answers (comma-separated)',
                  hintText: 'fifty six, fifty-six, 56',
                ),
              ),

              const SizedBox(height: 8),

              TextField(
                controller: _skillsController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Skills (comma-separated)',
                  hintText: 'multiplication, spoken_written_form',
                ),
              ),

              const SizedBox(height: 8),

              TextField(
                controller: _tagsController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Tags (comma-separated)',
                  hintText: 'multiplication, read-aloud, nums-to-words, spoken-response',
                ),
              ),
            ],

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _onSave,
                  child: const Text('Save Question'),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}