import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:onwards/pages/constants.dart';

class ThemeController {

  static final ValueNotifier<ColorProfile> current =
      ValueNotifier(greenFlavor);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    int index = prefs.getInt('theme_id') ?? 0;

    current.value = _getProfileByIndex(index);
  }

  static Future<void> set(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_id', index);

    current.value = _getProfileByIndex(index);
  }

  static ColorProfile _getProfileByIndex(int index) {
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
}