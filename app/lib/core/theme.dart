import 'package:flutter/material.dart';

/// ألوان اللعبة.
abstract final class AppColors {
  static const purpleText = Color(0xFF8E1F8E);
  static const brown = Color(0xFF5A2E1A);
  static const darkBrown = Color(0xFF3B2314);
  static const wood = Color(0xFFF5C042);
  static const parchment = Color(0xFFFBEEDF);
  static const green = Color(0xFF3BD16F);
  static const red = Color(0xFFE5484D);
  static const blue = Color(0xFF1BA3D6);
  static const lightBlue = Color(0xFF7FE3FF);
  static const gold = Color(0xFFFFC928);
  static const mascot = Color(0xFFA62BA0);
}

/// Police de lecture (questions, réponses) : très lisible, avec les voyelles (تشكيل).
const kFont = 'Tajawal';

/// Police des titres et des récompenses : ronde et ludique, pour les enfants.
const kDisplayFont = 'Lalezar';

/// Largeur maximale du jeu (format téléphone), même sur un grand écran.
const kMaxGameWidth = 480.0;

ThemeData buildTheme() => ThemeData(
      useMaterial3: true,
      fontFamily: kFont,
      colorScheme: ColorScheme.fromSeed(seedColor: AppColors.purpleText),
      scaffoldBackgroundColor: const Color(0xFF55D8F2),
    );
