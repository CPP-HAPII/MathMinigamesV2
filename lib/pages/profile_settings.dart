import 'dart:collection';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:onwards/pages/constants.dart';
import 'package:onwards/pages/components/lang_assist.dart';
import 'package:onwards/pages/create_sequence.dart';
import 'package:onwards/pages/create_question.dart';

import 'package:shared_preferences/shared_preferences.dart';

class ProfileSettingsPage extends StatefulWidget {
  final ColorProfile colorProfile;

  const ProfileSettingsPage({
    super.key,
    required this.colorProfile,
  });

  @override
  State<ProfileSettingsPage> createState() => _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends State<ProfileSettingsPage> {
  late ColorProfile currentProfile;
  late LanguageAssistLevel? currentLangAssist;
  late Future<int> themeId;
  
  final Future<SharedPreferencesWithCache> _prefs =
      SharedPreferencesWithCache.create(
        cacheOptions: const SharedPreferencesWithCacheOptions(
          allowList: <String>{'theme_id', 'sequence_id', 'lang_assist_level', 'correct', 'missed', 'mastered_topics', 'weak_topics', 'score'}
        )
      );

  final List<LanguageAssistLevel> levels = LanguageAssistLevel.values;
  int selected = 0;

  @override
  void initState() {
    super.initState();
    themeId = _prefs.then((SharedPreferencesWithCache prefs) {
      return prefs.getInt('theme_id') ?? 0;
    });
    // sequenceId = _loadSequenceIndex();
    _loadAssistLevel();
    loadTheme();
  }

  final maxThemes = 6;
  Future<void> loadTheme() async {
    final SharedPreferencesWithCache prefs = await _prefs;
    int? themeIndex = (prefs.getInt('theme_id') ?? 0);

    setState(() {
      currentProfile = _getProfileByIndex(themeIndex);
    });
  }

  Future<void> _setLangAssistLevel(int index) async {
    if (index < 0 || index >= levels.length) return;

    final prefs = await _prefs;
    await prefs.setInt('lang_assist_level', index);

    setState(() {
      selected = index;
      currentLangAssist = levels[index]; // update langAssist value
    });

    debugPrint('Language Assist level set to ${levels[index].label}');
  }

  void _loadAssistLevel() async {
    final saved = await AssistLevelService.load();
    setState(() {
      selected = saved.index;
      currentLangAssist = saved;
    });
  }

  Future<void> _incrementCounter() async {
    final SharedPreferencesWithCache prefs = await _prefs;
    if ((prefs.getInt('theme_id') ?? 0) >= maxThemes) {
      return;
    }
    final int counter = (prefs.getInt('theme_id') ?? 0) + 1;
    setState(() {
      themeId = prefs.setInt('theme_id', counter).then((_) {
        print('Updating theme...');
        currentProfile = _getProfileByIndex(counter);
        return counter;
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
        print('Updating theme...');
        currentProfile = _getProfileByIndex(counter);
        return counter;
      });
    });
  }

  ColorProfile _getProfileByIndex(int index) {
    switch (index) {
      case 0:
        return greenFlavor;
      case 1:
        return blueFlavor;
      case 2:
        return lightFlavor;
      case 3:
        return darkFlavor;
      default:
        return lightFlavor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile Settings"),
        backgroundColor: currentProfile.headerColor,
      ),
      body: Container(
        decoration: currentProfile.backBoxDecoration,
        child: Center(
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: currentProfile.buttonColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                        style: ButtonStyle(backgroundColor: MaterialStateProperty.all(currentProfile.buttonColor)),
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
                  future: _prefs.then((prefs) => prefs.getInt('theme_id') ?? 0),
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
                            'Current theme: ${_getProfileByIndex(snapshot.data ?? 0).idKey}',
                            style: TextStyle(
                              color: currentProfile.textColor,
                            ),
                          );
                        }
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}