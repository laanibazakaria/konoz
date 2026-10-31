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

const kFont = 'Tajawal';

ThemeData buildTheme() => ThemeData(
      useMaterial3: true,
      fontFamily: kFont,
      colorScheme: ColorScheme.fromSeed(seedColor: AppColors.purpleText),
      scaffoldBackgroundColor: const Color(0xFF55D8F2),
    );

/// خلفيات بديلة (تدرّجات) تُستخدم إذا لم تُضف الصور بعد — مفهرسة برقم العالم.
List<Color> fallbackGradient(int worldId, {bool quiz = false}) {
  const map = {
    1: [Color(0xFFE9A15B), Color(0xFFC9733A)], // وادٍ
    2: [Color(0xFF8C6A9E), Color(0xFF5E4370)], // بنفسجي
    3: [Color(0xFFF3D98B), Color(0xFFE4B95B)], // صحراء
  };
  const quizColors = {
    1: [Color(0xFF55D8F2), Color(0xFF8EE3F5), Color(0xFF9BE15D)], // غابة نهارية
    2: [Color(0xFF1F5E6B), Color(0xFF2E8C8C), Color(0xFF3A6B4A)], // أدغال ليلية
    3: [Color(0xFF7FD3F7), Color(0xFFFCE3A1), Color(0xFFE4B95B)], // صحراء
  };
  final table = quiz ? quizColors : map;
  return table[((worldId - 1) % 3) + 1]!;
}
