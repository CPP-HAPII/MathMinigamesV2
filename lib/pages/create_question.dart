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
  final TextEditingController _writtenPromptController = TextEditingController();

  QuestionGameType? _selectedGameType;
  Difficulty _selectedDifficulty = Difficulty.Easy;

  Future<void> _onSave() async {
    if (_selectedGameType == null) return;

    final docRef =
        FirebaseFirestore.instance.collection('gameData').doc('questions');

    // Shared fields
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
        'writtenPrompt': _writtenPromptController.text.trim(),
        'optionList': optionList,
        'multiAcceptedAnswers': acceptedAnswers,
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
                return FilterChip(
                  label: Text(label),
                  selected: _selectedGameType == gt,
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

            // Jumble Question Inputs
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
                  hintText: 'she, eight, five, forty, thirty-two',
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

            // Playback Question Input
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
                controller: _webAudioLinkController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Web Audio Link (optional)',
                  hintText: 'https://...',
                ),
              ),

              const SizedBox(height: 8),

              TextField(
                controller: _writtenPromptController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Written Prompt',
                  hintText:
                      'Listen to the audio and then create your response with the choices below.',
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