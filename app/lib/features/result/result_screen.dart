import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: GameBackground(asset: world.quizBackground, fallback: fallbackGradient(world.id, quiz: true)),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                  decoration: BoxDecoration(
                    color: AppColors.parchment,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.brown, width: 4),
                    boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 12, offset: Offset(0, 6))],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('المستوى ${level.number}',
                          style:
                              const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.purpleText)),
                      const SizedBox(height: 16),
                      _AnimatedStars(stars: result.stars),
                      const SizedBox(height: 12),
                      Text(_message,
                          textAlign: TextAlign.center,
                          style:
                              const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.darkBrown)),
                      const SizedBox(height: 8),
                      Text('${result.correct} / ${result.total} إجابات صحيحة',
                          style: const TextStyle(fontSize: 18, color: AppColors.darkBrown)),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.monetization_on_rounded, color: AppColors.gold, size: 32),
                          const SizedBox(width: 6),
                          Text('+${result.coinsEarned}',
                              textDirection: TextDirection.ltr,
                              style: const TextStyle(
                                  fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.darkBrown)),
                        ],
                      ),
                      if (result.coinsEarned == 0 && result.stars > 0)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text('تحصل على القطع عندما تحسّن نتيجتك',
                              style: TextStyle(fontSize: 14, color: Colors.black54)),
                        ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          RoundIconButton(icon: Icons.map_rounded, onTap: () => Navigator.of(context).pop()),
                          const SizedBox(width: 16),
                          RoundIconButton(icon: Icons.replay_rounded, onTap: () => play(level)),
                          if (next != null) ...[
                            const SizedBox(width: 16),
                            // arrow_forward ينعكس تلقائياً في RTL فيشير إلى اليسار = «التالي»
                            RoundIconButton(icon: Icons.arrow_forward_rounded, size: 68, onTap: () => play(next)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
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
                child: Icon(
                  Icons.star_rounded,
                  size: i == 1 ? 84 : 66,
                  color: i < stars ? AppColors.gold : const Color(0xFFD0C8BC),
                  shadows: const [Shadow(color: Color(0xFF9A6A00), offset: Offset(0, 3))],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
