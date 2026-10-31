import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/art/coin.dart';
import '../../core/art/confetti.dart';
import '../../core/art/paper_wood.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../quiz/quiz_screen.dart';

class ResultScreen extends ConsumerWidget {
  const ResultScreen({super.key, required this.level, required this.world, required this.result});

  final Level level;
  final World world;
  final AttemptResult result;

  String get _message => switch (result.stars) {
        3 => 'ممتاز! بارك الله فيك',
        2 => 'أحسنت! أنت قريب من الكمال',
        1 => 'جيّد! حاول مرة أخرى لتحصل على نجوم أكثر',
        _ => 'لا بأس، حاول مرة أخرى',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final map = ref.watch(mapDataProvider).valueOrNull;
    final idx = map?.levels.indexWhere((l) => l.id == level.id) ?? -1;
    final next =
        (map != null && idx >= 0 && idx + 1 < map.levels.length && result.stars > 0) ? map.levels[idx + 1] : null;

    void play(Level l) => Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => QuizScreen(
            level: l,
            world: map?.worldOf(l) ?? world,
            startCoins: result.coinsBalance,
          ),
        ));

    final mood = result.stars >= 2 ? MascotMood.happy : (result.stars == 1 ? MascotMood.idle : MascotMood.sad);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand, // l'écran est toujours rempli, quel que soit le contenu
        children: [
          Positioned.fill(child: GameBackground(asset: world.quizBackground, scene: sceneForWorld(world.id))),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Mascot(size: 110, mood: mood),
                    CustomPaint(
                      painter: ParchmentPainter(seed: level.number),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            OutlinedTitle('المستوى ${level.number}', size: 34),
                            const SizedBox(height: 8),
                            _AnimatedStars(stars: result.stars),
                            const SizedBox(height: 10),
                            Text(_message,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontFamily: kDisplayFont, fontSize: 24, height: 1.4, color: AppColors.purpleText)),
                            const SizedBox(height: 6),
                            Text('${result.correct} / ${result.total} إجابات صحيحة',
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.darkBrown)),
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF3C4),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(color: AppColors.gold, width: 3),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const CoinIcon(size: 32),
                                  const SizedBox(width: 6),
                                  Text('+${result.coinsEarned}',
                                      textDirection: TextDirection.ltr,
                                      style: const TextStyle(
                                          fontFamily: kDisplayFont, fontSize: 30, color: AppColors.darkBrown)),
                                ],
                              ),
                            ),
                            if (result.coinsEarned == 0 && result.stars > 0)
                              const Padding(
                                padding: EdgeInsets.only(top: 6),
                                child: Text('تحصل على القطع عندما تحسّن نتيجتك',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black54)),
                              ),
                            const SizedBox(height: 22),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                RoundIconButton(icon: Icons.map_rounded, onTap: () => Navigator.of(context).pop()),
                                const SizedBox(width: 16),
                                RoundIconButton(icon: Icons.replay_rounded, onTap: () => play(level)),
                                if (next != null) ...[
                                  const SizedBox(width: 16),
                                  // arrow_forward ينعكس تلقائياً في RTL فيشير إلى اليسار = «التالي»
                                  RoundIconButton(icon: Icons.arrow_forward_rounded, size: 72, onTap: () => play(next)),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (result.stars >= 2) Positioned.fill(child: ConfettiBurst(trigger: 1, count: result.stars * 30)),
        ],
      ),
    );
  }
}

class _AnimatedStars extends StatelessWidget {
  const _AnimatedStars({required this.stars});
  final int stars;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 3; i++)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              // تظهر النجوم واحدة تلو الأخرى
              duration: Duration(milliseconds: 500 + i * 350),
              curve: Interval(i * .25, 1, curve: Curves.elasticOut),
              builder: (_, v, child) => Transform.scale(scale: v, child: child),
              child: Padding(
                padding: EdgeInsets.only(bottom: i == 1 ? 20 : 0),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // contour plus foncé derrière l'étoile
                    Icon(Icons.star_rounded,
                        size: (i == 1 ? 84 : 66) + 12,
                        color: i < stars ? const Color(0xFFC77D0A) : const Color(0xFFB5A99A)),
                    Icon(
                      Icons.star_rounded,
                      size: i == 1 ? 84 : 66,
                      color: i < stars ? AppColors.gold : const Color(0xFFE2DAD0),
                      shadows: const [Shadow(color: Color(0x66FFFFFF), offset: Offset(-2, -2))],
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
