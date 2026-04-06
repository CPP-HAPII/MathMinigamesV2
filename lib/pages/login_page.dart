import 'package:flutter/material.dart';
import 'package:onwards/pages/components/theme_controller.dart';
import 'package:onwards/pages/constants.dart';
import 'home.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _userIdController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  ColorProfile currentProfile = greenFlavor;

  void _handleThemeChanged() {
    setState(() {
      currentProfile = ThemeController.current.value;
    });
  }

  @override
  void initState() {
    super.initState();
    ThemeController.load();
    currentProfile = ThemeController.current.value;
    ThemeController.current.addListener(_handleThemeChanged);
  }

  void _navigateToHome(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HomePage(userId: userId),
      ),
    );
  }

  @override
  void dispose() {
    ThemeController.current.removeListener(_handleThemeChanged);
    _userIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        backgroundColor: currentProfile.headerColor,
        foregroundColor: currentProfile.textColor,
      ),
      body: Container(
        decoration: currentProfile.backBoxDecoration,
        child: Center(
          child: Container(
            width: 380,
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: currentProfile.headerColor.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Welcome Back',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: currentProfile.textColor,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: 300,
                    child: TextFormField(
                      controller: _userIdController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: currentProfile.textColor),
                      decoration: InputDecoration(
                        labelText: 'Enter 3-digit User ID',
                        labelStyle: TextStyle(color: currentProfile.textColor),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: currentProfile.textColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: currentProfile.buttonColor,
                            width: 2,
                          ),
                        ),
                        border: const OutlineInputBorder(),
                        fillColor: currentProfile.backgroundColor.withValues(alpha: 0.75),
                        filled: true,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your User ID';
                        }
                        if (value.length != 3 || int.tryParse(value) == null) {
                          return 'User ID must be exactly 3 digits';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: currentProfile.buttonColor,
                      foregroundColor: currentProfile.textColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                    ),
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        _navigateToHome(_userIdController.text);
                      }
                    },
                    child: const Text('Submit'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
