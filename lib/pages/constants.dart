import 'package:flutter/material.dart';

const darkStyle = TextStyle(color: Colors.white);
const lightStyle = TextStyle(color: Colors.black);

const ColorProfile greenFlavor = ColorProfile(
    backgroundColor: Color.fromARGB(255, 121, 156, 84),
    headerColor: Color.fromARGB(255, 102, 132, 70),
    buttonColor: Color.fromARGB(255, 96, 198, 216), 
    textColor: Colors.black,
    contrastTextColor: Colors.white,
    checkAnswerButtonColor: Color.fromARGB(255, 111, 216, 0),
    clearAnswerButtonColor: Color.fromARGB(255, 224, 68, 68),
    backBoxDecoration: BoxDecoration(
      image: DecorationImage(
        image: AssetImage("assets/images/green_flavor.png"),
        fit: BoxFit.cover
      ),
      color: Color.fromARGB(255, 18, 165, 170),
    ),
    backgroundImage: AssetImage("assets/images/green_flavor.png"),
    idKey: "green flavor"
  );

const ColorProfile blueFlavor = ColorProfile(
    backgroundColor: Color.fromARGB(255, 110, 166, 189),
    headerColor: Color.fromARGB(255, 96, 135, 150),
    buttonColor: Color.fromARGB(255, 157, 217, 228), 
    textColor: Colors.black,
    contrastTextColor: Colors.white,
    checkAnswerButtonColor: Color.fromARGB(255, 111, 216, 0),
    clearAnswerButtonColor: Color.fromARGB(255, 224, 68, 68),
    backBoxDecoration: BoxDecoration(
      image: DecorationImage(
        image: AssetImage("assets/images/blue_flavor.jpg"),
        fit: BoxFit.cover
      ),
      color: Color.fromARGB(255, 18, 165, 170),
    ),
    backgroundImage: AssetImage("assets/images/blue_flavor.jpg"),
    idKey: "blue flavor"
  );

  const ColorProfile lightFlavor = ColorProfile(
    backgroundColor: Colors.white,
    headerColor: Colors.lightBlue,
    buttonColor: Colors.blueGrey, 
    textColor: Colors.black,
    contrastTextColor: Colors.black,
    checkAnswerButtonColor: Colors.green,
    clearAnswerButtonColor: Colors.red,
    backBoxDecoration: BoxDecoration(
      image: DecorationImage(
        image: AssetImage("assets/images/blank.png"), 
        repeat: ImageRepeat.repeat,
        scale: 0.4
      )
    ),
    backgroundImage: AssetImage("assets/images/blank.png"),
    idKey: "light flavor"
  );

  const ColorProfile darkFlavor = ColorProfile(
    backgroundColor: Color.fromARGB(255, 0, 0, 0),
    headerColor: Color.fromARGB(255, 112, 112, 112),
    buttonColor: Colors.grey, 
    textColor: Color.fromARGB(255, 255, 255, 255),
    contrastTextColor: Color.fromARGB(255, 255, 255, 255),
    checkAnswerButtonColor: Colors.green,
    clearAnswerButtonColor: Colors.red,
    backBoxDecoration: BoxDecoration(
      image: DecorationImage(
        image: AssetImage("assets/images/blank.png"), 
        fit: BoxFit.cover,
        invertColors: true
      ),
      color: Color.fromARGB(255, 0, 0, 0),
    ),
    backgroundImage: AssetImage("assets/images/blank.png"),
    idKey: "dark flavor"
  );

// Color profiles for the screens
class ColorProfile {
  const ColorProfile({
    required this.backgroundColor,
    required this.headerColor,
    required this.buttonColor,
    required this.textColor,
    required this.contrastTextColor,
    required this.checkAnswerButtonColor,
    required this.clearAnswerButtonColor,
    required this.backBoxDecoration,
    required this.backgroundImage,
    this.disabledButtonColor = Colors.grey,
    this.idKey = "color profile"
  });


  final String idKey;
  final Color backgroundColor;
  final Color headerColor;
  final Color buttonColor;
  final Color textColor;
  final Color contrastTextColor;
  final Color checkAnswerButtonColor;
  final Color clearAnswerButtonColor;
  final AssetImage backgroundImage;
  final BoxDecoration backBoxDecoration;
  final Color disabledButtonColor;
}