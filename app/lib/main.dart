import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/assets.dart';
import 'core/theme.dart';
import 'data/providers.dart';
import 'data/quiz_repository.dart';
import 'features/home/home_screen.dart';

/// التشغيل مع Supabase:
///   flutter run --dart-define=SUPABASE_URL=https://xxx.supabase.co --dart-define=SUPABASE_ANON_KEY=xxx
/// بدون هذه القيم يعمل التطبيق في الوضع التجريبي (بيانات محلية).
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await AppAssets.load(); // قائمة الصور المضمّنة، مرة واحدة

  QuizRepository repo = DemoQuizRepository();
  if (_supabaseUrl.isNotEmpty && _supabaseKey.isNotEmpty) {
    await Supabase.initialize(url: _supabaseUrl, publishableKey: _supabaseKey);
    repo = SupabaseQuizRepository(Supabase.instance.client);
  }

  runApp(ProviderScope(
    overrides: [repositoryProvider.overrideWithValue(repo)],
    child: const QuizApp(),
  ));
}

class QuizApp extends StatelessWidget {
  const QuizApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'كنوز', // nom affiché dans l'onglet et sous l'icône
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      // واجهة عربية بالكامل، من اليمين إلى اليسار
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Le jeu est conçu pour un téléphone : sur un écran large (ordinateur, tablette
      // en paysage), on garde une colonne au format téléphone, centrée.
      builder: (context, child) => ColoredBox(
        color: const Color(0xFF2B1D14),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kMaxGameWidth),
            child: child,
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
