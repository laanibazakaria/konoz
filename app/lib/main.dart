import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme.dart';
import 'core/widgets.dart';
import 'data/providers.dart';
import 'data/quiz_repository.dart';
import 'features/map/map_screen.dart';

/// التشغيل مع Supabase:
///   flutter run --dart-define=SUPABASE_URL=https://xxx.supabase.co --dart-define=SUPABASE_ANON_KEY=xxx
/// بدون هذه القيم يعمل التطبيق في الوضع التجريبي (بيانات محلية).
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

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
      title: 'مسابقة المسلم الصغير',
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
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: GameBackground(
              asset: 'assets/backgrounds/home.png',
              fallback: fallbackGradient(1, quiz: true),
            ),
          ),
          SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'مسابقة المسلم الصغير',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      shadows: [Shadow(color: AppColors.purpleText, offset: Offset(0, 3), blurRadius: 2)],
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Mascot(size: 170),
                  const SizedBox(height: 36),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MapScreen())),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFFFFE27A), Color(0xFFF2A81D)],
                        ),
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 4))],
                      ),
                      child: const Text('ابدأ اللعب',
                          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.darkBrown)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
