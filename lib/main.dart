import 'package:flutter/material.dart';
import 'package:onwards/pages/home.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Ensure question banks are loaded before starting the app
  await gameDataBank.initBanks();

  runApp(const HomeApp());
}