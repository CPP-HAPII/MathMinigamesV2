import 'package:flutter/material.dart';
import 'package:onwards/pages/constants.dart';
import 'package:onwards/pages/game_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class CustomQuestionPage extends StatefulWidget {
  const CustomQuestionPage({super.key});

  @override
  State<CustomQuestionPage> createState() => _CustomQuestionPageState();
}

class _CustomQuestionPageState extends State<CustomQuestionPage> {
  final TextEditingController _nameController = TextEditingController();

  Future<void> _onSave() async {
    final docRef = FirebaseFirestore.instance.collection('gameData').doc('questions');

    try {
      await docRef.set({
        'sequences': FieldValue.arrayUnion([])
      }, SetOptions(merge: true));

      // Notify user and close
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Question saved')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save question: $e')));
      }
    }
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
            // Name field
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter name for Question...',
              ),
            ),
            const SizedBox(height: 12),
            
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