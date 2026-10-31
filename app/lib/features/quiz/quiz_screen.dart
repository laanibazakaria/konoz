import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/art/coin.dart';
import '../../core/art/confetti.dart';
import '../../core/art/paper_wood.dart';
import '../../core/assets.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../result/result_screen.dart';

/// شاشة المستوى: تحمّل الأسئلة ثم تعرض اللعبة.
class QuizScreen extends ConsumerWidget {
  const QuizScreen({super.key, required this.level, required this.world, required this.startCoins});

  final Level level;
  final World world;
  final int startCoins;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questions = ref.watch(questionsProvider(level.id));
    return Scaffold(
      body: Stack(
        fit: StackFit.expand, // l'écran est toujours rempli, quel que soit le contenu
        children: [
          Positioned.fill(
            child: GameBackground(asset: world.quizBackground, scene: sceneForWorld(world.id)),
          ),
          questions.when(
            loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
            error: (e, _) => _ErrorView(onRetry: () => ref.invalidate(questionsProvider(level.id))),
            data: (qs) => qs.isEmpty
                ? const Center(child: Text('لا توجد أسئلة في هذا المستوى بعد', style: TextStyle(fontSize: 22)))
                : QuizGame(
                    questions: qs,
                    coinsPerCorrect: level.coinsPerCorrect,
                    startCoins: startCoins,
                    onFinished: (answers) => _submit(context, ref, answers),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit(BuildContext context, WidgetRef ref, List<int> answers) async {
    final nav = Navigator.of(context);
    try {
      final result = await ref.read(repositoryProvider).submitAttempt(level.id, answers);
      ref.invalidate(mapDataProvider); // تحديث النجوم والقطع على الخريطة
      nav.pushReplacement(MaterialPageRoute(
        builder: (_) => ResultScreen(level: level, world: world, result: result),
      ));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر حفظ النتيجة، تحقّق من الاتصال بالإنترنت')),
      );
      nav.pop();
    }
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('تعذّر تحميل الأسئلة', style: TextStyle(fontSize: 22, color: Colors.white)),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
        ]),
      );
}

// ═══════════════════════════ اللعبة ═══════════════════════════

enum _Feedback { none, correct, wrong }

enum ChoiceState { idle, correct, wrong, dimmed }

class QuizGame extends StatefulWidget {
  const QuizGame({
    super.key,
    required this.questions,
    required this.onFinished,
    this.coinsPerCorrect = 10,
    this.startCoins = 0,
  });

  final List<QuizQuestion> questions;

  /// تُستدعى بإجابات اللاعب (من 1 إلى 3) — تُرسل كما هي إلى submit_attempt.
  final ValueChanged<List<int>> onFinished;
  final int coinsPerCorrect;
  final int startCoins;

  @override
  State<QuizGame> createState() => _QuizGameState();
}

class _QuizGameState extends State<QuizGame> with SingleTickerProviderStateMixin {
  int _index = 0;
  late int _coins = widget.startCoins;
  int? _selected;
  bool _finished = false;
  _Feedback _feedback = _Feedback.none;
  final List<int> _answers = [];
  int _celebrations = 0; // déclenche les confettis
  String? _praise;

  static const _praises = ['أحسنت!', 'ممتاز!', 'رائع!', 'بارك الله فيك!', 'أنت بطل!'];

  late final AnimationController _mascot =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 650));

  QuizQuestion get _q => widget.questions[_index];
  bool get _locked => _selected != null;

  @override
  void dispose() {
    _mascot.dispose();
    super.dispose();
  }

  Future<void> _onChoice(int i) async {
    if (_locked || _finished) return;
    final ok = i == _q.correctIndex;
    ok ? HapticFeedback.lightImpact() : HapticFeedback.heavyImpact();

    setState(() {
      _selected = i;
      _answers.add(i + 1);
      _feedback = ok ? _Feedback.correct : _Feedback.wrong;
      if (ok) {
        _coins += widget.coinsPerCorrect;
        _celebrations++;
        _praise = _praises[_celebrations % _praises.length];
      }
    });
    _mascot.forward(from: 0);

    // وقت أطول عند الخطأ ليرى الطفل الإجابة الصحيحة والشرح.
    final hasExplanation = !ok && (_q.explanation?.isNotEmpty ?? false);
    await Future.delayed(Duration(milliseconds: ok ? 900 : (hasExplanation ? 3200 : 1700)));
    if (!mounted) return;

    if (_index == widget.questions.length - 1) {
      setState(() => _finished = true);
      widget.onFinished(List.unmodifiable(_answers));
      return;
    }
    setState(() {
      _index++;
      _selected = null;
      _feedback = _Feedback.none;
      _praise = null;
    });
  }

  ChoiceState _stateFor(int i) {
    if (!_locked) return ChoiceState.idle;
    if (i == _q.correctIndex) return ChoiceState.correct; // نُظهر الإجابة الصحيحة دائماً
    if (i == _selected) return ChoiceState.wrong;
    return ChoiceState.dimmed;
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.questions.length;
    final answered = _index + (_locked ? 1 : 0);
    final explanation = _feedback == _Feedback.wrong ? _q.explanation : null;

    return SafeArea(
      bottom: false,
      // نوزّع الارتفاع المتاح حتى لا يحدث تجاوز على الشاشات الصغيرة
      child: LayoutBuilder(builder: (context, c) {
        final h = c.maxHeight;
        return Stack(children: [
          Column(
            children: [
              // ── الأعلى: الرّق + زر القائمة ──
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: QuestionBoard(key: ValueKey(_q.id), text: _q.text)),
                    const SizedBox(width: 8),
                    RoundIconButton(icon: Icons.apps_rounded, onTap: () => _confirmQuit(context)),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // ── الوسط: 3 خيارات بالضبط ──
              Container(
                constraints: BoxConstraints(maxHeight: h * .30),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder: (child, a) => FadeTransition(
                    opacity: a,
                    child: SlideTransition(
                      position: Tween(begin: const Offset(0, -.15), end: Offset.zero).animate(a),
                      child: child,
                    ),
                  ),
                  child: Row(
                    key: ValueKey(_index),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < 3; i++)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: ChoiceCard(
                              text: _q.choices[i],
                              state: _stateFor(i),
                              onTap: () => _onChoice(i),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const Spacer(),

              // ── الأسفل: الشخصية + الصندوق + القطع ──
              _BottomScene(
                controller: _mascot,
                feedback: _feedback,
                coins: _coins,
                gained: widget.coinsPerCorrect,
                praise: _feedback == _Feedback.correct ? _praise : null,
                explanation: explanation,
                maxHeight: h * .28,
              ),

              // ── أسفل الشاشة: تقدّم المستوى ──
              _LevelProgress(current: answered, total: total),
            ],
          ),
          Positioned.fill(child: ConfettiBurst(trigger: _celebrations)),
        ]);
      }),
    );
  }

  Future<void> _confirmQuit(BuildContext context) async {
    final quit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('الخروج من المستوى؟'),
        content: const Text('لن تُحفظ إجاباتك في هذا المستوى.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('متابعة اللعب')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('خروج')),
        ],
      ),
    );
    if (quit == true && context.mounted) Navigator.of(context).pop();
  }
}

// ═══════════════════════════ الرّق (لوحة السؤال) ═══════════════════════════
class QuestionBoard extends StatelessWidget {
  const QuestionBoard({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final image = AppAssets.has(AssetPaths.parchment);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: .8, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut,
      builder: (_, s, child) => Transform.scale(scale: s, child: child),
      child: CustomPaint(
        painter: image ? null : ParchmentPainter(seed: text.hashCode & 0xffff),
        child: Container(
          constraints: const BoxConstraints(minHeight: 130),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
          decoration: image
              ? const BoxDecoration(image: DecorationImage(image: AssetImage(AssetPaths.parchment), fit: BoxFit.fill))
              : null,
          alignment: Alignment.center,
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: text.length > 60 ? 21 : 26,
              height: 1.7,
              fontWeight: FontWeight.w800,
              color: AppColors.purpleText,
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════ بطاقة الإجابة (خشب) ═══════════════════════════
class ChoiceCard extends StatefulWidget {
  const ChoiceCard({super.key, required this.text, required this.state, required this.onTap});
  final String text;
  final ChoiceState state;
  final VoidCallback onTap;

  @override
  State<ChoiceCard> createState() => _ChoiceCardState();
}

class _ChoiceCardState extends State<ChoiceCard> {
  bool _pressed = false;

  /// الأذكار الطويلة يجب أن تتّسع داخل البطاقة.
  double get _fontSize {
    final n = widget.text.length;
    if (n <= 12) return 22;
    if (n <= 24) return 18;
    if (n <= 45) return 15;
    return 13;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final borderColor = switch (s) {
      ChoiceState.correct => AppColors.green,
      ChoiceState.wrong => AppColors.red,
      _ => const Color(0xFF4A2410),
    };
    final highlighted = s == ChoiceState.correct || s == ChoiceState.wrong;
    final image = AppAssets.has(AssetPaths.woodCard);

    Widget card = AspectRatio(
      aspectRatio: .86,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: image ? null : WoodCardPainter(border: borderColor, glow: highlighted ? borderColor : null),
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 16, 8, 10),
                decoration: image
                    ? BoxDecoration(
                        image: const DecorationImage(image: AssetImage(AssetPaths.woodCard), fit: BoxFit.fill),
                        border: Border.all(color: borderColor, width: 4),
                      )
                    : null,
                alignment: Alignment.center,
                child: Text(
                  widget.text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: _fontSize, height: 1.6, fontWeight: FontWeight.w800, color: AppColors.darkBrown),
                ),
              ),
            ),
          ),
          if (highlighted)
            Positioned(
              top: -16,
              left: 0,
              right: 0,
              child: Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.elasticOut,
                  builder: (_, v, child) => Transform.scale(scale: v, child: child),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: borderColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                    ),
                    child: Icon(s == ChoiceState.correct ? Icons.check_rounded : Icons.close_rounded,
                        color: Colors.white, size: 22),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    // Une mauvaise réponse tremble brièvement.
    if (s == ChoiceState.wrong) {
      card = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 500),
        builder: (_, v, child) =>
            Transform.translate(offset: Offset(math.sin(v * math.pi * 6) * 7 * (1 - v), 0), child: child),
        child: card,
      );
    }

    return Semantics(
      button: true,
      label: widget.text,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutBack,
          scale: _pressed ? .92 : (s == ChoiceState.correct ? 1.07 : 1),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            opacity: s == ChoiceState.dimmed ? .45 : 1,
            child: card,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════ المشهد السفلي ═══════════════════════════
class _BottomScene extends StatelessWidget {
  const _BottomScene({
    required this.controller,
    required this.feedback,
    required this.coins,
    required this.gained,
    this.praise,
    this.explanation,
    this.maxHeight = double.infinity,
  });

  final AnimationController controller;
  final _Feedback feedback;
  final int coins;

  /// Pièces gagnées à la dernière bonne réponse (affichées « +10 »).
  final int gained;
  final String? praise;
  final String? explanation;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final mascotSize = math.min(math.min(w * .38, 170.0), maxHeight / 1.25);
      final mood = switch (feedback) {
        _Feedback.correct => MascotMood.happy,
        _Feedback.wrong => MascotMood.sad,
        _Feedback.none => MascotMood.idle,
      };
      return SizedBox(
        height: mascotSize * 1.25,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // الشخصية: تقفز عند الصواب وتهتزّ عند الخطأ
            Positioned(
              left: 4,
              bottom: 0,
              child: AnimatedBuilder(
                animation: controller,
                builder: (_, child) {
                  final t = controller.value;
                  final dy = feedback == _Feedback.correct ? -math.sin(t * math.pi) * 40 : 0.0;
                  final dx = feedback == _Feedback.wrong ? math.sin(t * math.pi * 6) * 8 * (1 - t) : 0.0;
                  return Transform.translate(offset: Offset(dx, dy), child: child);
                },
                child: Mascot(size: mascotSize, mood: mood),
              ),
            ),
            // فقاعة القطع + «+10» الذي يطير
            Positioned(right: 10, bottom: 6, child: CoinBubble(coins: coins)),
            if (feedback == _Feedback.correct && gained > 0)
              Positioned(right: 18, bottom: 70, child: _FloatingGain(key: ValueKey(coins), amount: gained)),

            // تشجيع عند الصواب، وشرح عند الخطأ
            if (praise != null)
              Positioned(
                left: mascotSize * .9,
                top: 0,
                child: _Bubble(key: ValueKey(praise), text: praise!, praise: true),
              ),
            if (explanation != null)
              Positioned(
                left: mascotSize * .7,
                right: 12,
                top: -40,
                child: _Bubble(text: explanation!),
              ),
          ],
        ),
      );
    });
  }
}

/// Bulle qui sort de la mascotte : encouragement (grand, coloré) ou explication.
class _Bubble extends StatelessWidget {
  const _Bubble({super.key, required this.text, this.praise = false});
  final String text;
  final bool praise;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: praise ? 500 : 300),
      curve: praise ? Curves.elasticOut : Curves.easeOutBack,
      builder: (_, v, child) => Transform.scale(scale: v, alignment: Alignment.bottomLeft, child: child),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: praise ? 18 : 14, vertical: praise ? 6 : 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: praise ? AppColors.green : AppColors.purpleText, width: 3),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))],
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: praise
              ? const TextStyle(fontFamily: kDisplayFont, fontSize: 26, color: Color(0xFF2B8A3E))
              : const TextStyle(fontSize: 15, height: 1.5, fontWeight: FontWeight.w800, color: AppColors.darkBrown),
        ),
      ),
    );
  }
}

class _FloatingGain extends StatelessWidget {
  const _FloatingGain({super.key, required this.amount});
  final int amount;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1100),
        curve: Curves.easeOut,
        builder: (_, v, child) => Opacity(
          opacity: v < .7 ? 1 : (1 - v) / .3,
          child: Transform.translate(offset: Offset(0, -50 * v), child: child),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('+$amount',
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  fontFamily: kDisplayFont,
                  fontSize: 28,
                  color: AppColors.gold,
                  shadows: [Shadow(color: Color(0xFF8A5A00), offset: Offset(0, 2))],
                )),
            const CoinIcon(size: 26),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════ تقدّم المستوى ═══════════════════════════
class _LevelProgress extends StatelessWidget {
  const _LevelProgress({required this.current, required this.total});
  final int current, total;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE9A13C), Color(0xFFC9772A)],
        ),
        border: Border(top: BorderSide(color: Color(0xFF8A4A1F), width: 3)),
      ),
      padding: EdgeInsets.fromLTRB(16, 10, 16, 12 + MediaQuery.paddingOf(context).bottom),
      child: Row(
        children: [
          // في RTL أول عنصر يظهر يميناً → «4/14» على اليمين كما في التصميم
          Text(
            '$current/$total',
            textDirection: TextDirection.ltr,
            style: const TextStyle(
              fontFamily: kDisplayFont,
              fontSize: 28,
              color: Colors.white,
              shadows: [Shadow(color: Color(0xFF6B3A12), offset: Offset(0, 2))],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: StripedProgressBar(value: total == 0 ? 0 : current / total)),
        ],
      ),
    );
  }
}
