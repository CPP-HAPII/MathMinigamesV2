import 'package:flutter/material.dart';
import 'package:onwards/pages/constants.dart';
import 'package:onwards/pages/game_data.dart';

class CustomSequencePage extends StatefulWidget {
  const CustomSequencePage({super.key});

  @override
  State<CustomSequencePage> createState() => _CustomeSequencePage();
}

class _CustomeSequencePage extends State<CustomSequencePage> {
  final TextEditingController _questionController = TextEditingController();
  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  void _onSave() {
    final question = _questionController.text.trim();
    // TODO: persist value (SharedPreferences / Firestore)
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
            TextField(
              controller: _questionController,
              maxLines: 6,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter new question...',
              ),
            ),
            const SizedBox(height: 12),
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