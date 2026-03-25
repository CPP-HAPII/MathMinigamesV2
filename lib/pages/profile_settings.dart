import 'dart:collection';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:onwards/pages/constants.dart';
import 'package:onwards/pages/components/lang_assist.dart';
import 'package:onwards/pages/create_sequence.dart';
import 'package:onwards/pages/create_question.dart';
import 'package:onwards/pages/home.dart';
import 'package:onwards/pages/components/assist_controller.dart';
import 'package:onwards/pages/components/lang_assist.dart';
import 'package:onwards/pages/components/theme_controller.dart';

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
  

  final List<LanguageAssistLevel> levels = LanguageAssistLevel.values;

  int selected = 0;
  int themeIndex = 0;
  final int maxThemes = 4;

  @override
  void initState() {
    super.initState();

    AssistController.load();
    ThemeController.load();

    currentProfile = ThemeController.current.value;

    final assist = AssistController.current.value;

    selected = assist.index;
    currentLangAssist = assist;

    ThemeController.current.addListener(() {
      setState(() {
        currentProfile = ThemeController.current.value;
      });
    });
  }

  Future<void> _setLangAssistLevel(int index) async {
    if (index < 0 || index >= levels.length) return;

    final level = levels[index];
    await AssistController.set(level);

    setState(() {
      selected = index;
      currentLangAssist = level;
    });

    debugPrint('Language Assist level set to ${level.label}');
  }


  Future<void> _incrementTheme() async {
    themeIndex++;

    if (themeIndex >= maxThemes) {
      themeIndex = 0;
    }

    await ThemeController.set(themeIndex);
  }

  Future<void> _decrementTheme() async {
    themeIndex--;

    if (themeIndex < 0) {
      themeIndex = maxThemes - 1;
    }

    await ThemeController.set(themeIndex);
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
                        onPressed: _decrementTheme,
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
                        onPressed: _incrementTheme,
                        child: Icon(Icons.arrow_right, color: currentProfile.textColor),
                      ),
                    )
                  ],
                ),
                Text(
                  'Current theme: ${currentProfile.idKey}',
                  style: TextStyle(
                    color: currentProfile.textColor,
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}