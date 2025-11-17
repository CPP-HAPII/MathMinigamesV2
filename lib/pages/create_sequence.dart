import 'package:flutter/material.dart';
import 'package:onwards/pages/constants.dart';
import 'package:onwards/pages/game_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


enum GameType { jumble, playback, typing, fillBlanks, readaloud }
enum Difficulty { easy, medium, hard }

class CustomSequencePage extends StatefulWidget {
  const CustomSequencePage({super.key});

  @override
  State<CustomSequencePage> createState() => _CustomSequencePageState();
}

class _CustomSequencePageState extends State<CustomSequencePage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _filterController = TextEditingController();
  SequenceData? sequenceData;

  // selections
  final Set<GameType> _selectedGameTypes = <GameType>{};
  final Set<Difficulty> _selectedDifficulties = <Difficulty>{};

  // TODO: implement:
  // difficulty 3 selections
  // filters list of strings
  // gameType 5 selections
  // difficulty 3 selections
  // name string

  Future<void> _onSave() async {
    final seqName = _nameController.text.trim();
    final rawFilters = _filterController.text.trim();
    final seqFilters = rawFilters.isEmpty
        ? <String>[]
        : rawFilters.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

    // Map selected enums to the string shape expected by SequenceData
    final gameTypeStrings = _selectedGameTypes.map((gt) {
      switch (gt) {
        case GameType.jumble:
          return 'jumble';
        case GameType.playback:
          return 'playback';
        case GameType.typing:
          return 'typing';
        case GameType.fillBlanks:
          return 'fill';
        case GameType.readaloud:
          return 'reading';
      }
    }).toList();

    final difficultyStrings = _selectedDifficulties.map((d) {
      switch (d) {
        case Difficulty.easy:
          return 'Easy';
        case Difficulty.medium:
          return 'Intermediate';
        case Difficulty.hard:
          return 'Hard';
      }
    }).toList();

    final seqMap = <String, dynamic>{
      'difficulty': difficultyStrings,
      'filters': seqFilters,
      'gameType': gameTypeStrings,
      'name': seqName,
    };

    final docRef = FirebaseFirestore.instance.collection('gameData').doc('sequenceDoc');

    try {
      await docRef.set({
        'sequences': FieldValue.arrayUnion([seqMap])
      }, SetOptions(merge: true));

      // Notify user and close
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sequence saved')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save sequence: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const ColorProfile profile = lightFlavor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Custom Sequence'),
        backgroundColor: profile.headerColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Enter new sequence for a filtered learning session:',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 12),
            // Name field
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter name for Sequence...',
              ),
            ),
            const SizedBox(height: 12),

            // Filters (comma-separated)
            TextField(
              controller: _filterController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter comma-separated filters (e.g. addition, subtraction)',
              ),
            ),
            const SizedBox(height: 12),

            // Game type multi-select (checkboxes)
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(top: 8.0, bottom: 4.0),
                child: Text('Select game types:', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            Wrap(
              spacing: 8.0,
              children: GameType.values.map((gt) {
                final label = () {
                  switch (gt) {
                    case GameType.jumble:
                      return 'Jumble';
                    case GameType.playback:
                      return 'Playback';
                    case GameType.typing:
                      return 'Typing';
                    case GameType.fillBlanks:
                      return 'Fill Blanks';
                    case GameType.readaloud:
                      return 'Read Aloud';
                  }
                }();
                return FilterChip(
                  label: Text(label),
                  selected: _selectedGameTypes.contains(gt),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedGameTypes.add(gt);
                      } else {
                        _selectedGameTypes.remove(gt);
                      }
                    });
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 12),

            // Difficulty multi-select
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                child: Text('Select difficulty levels:', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            Wrap(
              spacing: 8.0,
              children: Difficulty.values.map((d) {
                final label = () {
                  switch (d) {
                    case Difficulty.easy:
                      return 'Easy';
                    case Difficulty.medium:
                      return 'Intermediate';
                    case Difficulty.hard:
                      return 'Hard';
                  }
                }();
                return FilterChip(
                  label: Text(label),
                  selected: _selectedDifficulties.contains(d),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedDifficulties.add(d);
                      } else {
                        _selectedDifficulties.remove(d);
                      }
                    });
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 12),

            // Save button
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _onSave,
                  child: const Text('Save'),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}