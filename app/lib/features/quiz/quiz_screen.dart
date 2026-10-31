import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
        children: [
          Positioned.fill(
            child: GameBackground(asset: world.quizBackground, fallback: fallbackGradient(world.id, quiz: true)),
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
      if (ok) _coins += widget.coinsPerCorrect;
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
        return Column(
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
              explanation: explanation,
              maxHeight: h * .28,
            ),

            // ── أسفل الشاشة: تقدّم المستوى ──
            _LevelProgress(current: answered, total: total),
          ],
        );
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
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: .85, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.elasticOut,
      builder: (_, s, child) => Transform.scale(scale: s, child: child),
      child: Container(
        constraints: const BoxConstraints(minHeight: 130),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.parchment,
          image: AppAssets.has(AssetPaths.parchment)
              ? const DecorationImage(image: AssetImage(AssetPaths.parchment), fit: BoxFit.fill)
              : null,
          borderRadius: BorderRadius.circular(4),
          boxShadow: const [BoxShadow(color: Color(0xFF6B4A35), offset: Offset(0, 6))],
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: text.length > 60 ? 21 : 26,
            height: 1.7,
            fontWeight: FontWeight.w700,
            color: AppColors.purpleText,
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
      _ => AppColors.brown,
    };
    final highlighted = s == ChoiceState.correct || s == ChoiceState.wrong;

    return Semantics(
      button: true,
      label: widget.text,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 140),
          scale: _pressed ? .93 : (s == ChoiceState.correct ? 1.06 : 1),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: s == ChoiceState.dimmed ? .5 : 1,
            child: AspectRatio(
              aspectRatio: .86,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.wood,
                        image: AppAssets.has(AssetPaths.woodCard)
                            ? const DecorationImage(image: AssetImage(AssetPaths.woodCard), fit: BoxFit.fill)
                            : null,
                        border: Border.all(color: borderColor, width: 4),
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: [
                          const BoxShadow(color: Colors.black26, offset: Offset(0, 5)),
                          if (highlighted)
                            BoxShadow(color: borderColor.withValues(alpha: .7), blurRadius: 18, spreadRadius: 2),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        widget.text,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: _fontSize,
                          height: 1.6,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkBrown,
                        ),
                      ),
                    ),
                  ),
                  if (highlighted)
                    Positioned(
                      top: -14,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: CircleAvatar(
                          radius: 15,
                          backgroundColor: borderColor,
                          child:
                              Icon(s == ChoiceState.correct ? Icons.check : Icons.close, color: Colors.white, size: 20),
                        ),
                      ),
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

// ═══════════════════════════ المشهد السفلي ═══════════════════════════
class _BottomScene extends StatelessWidget {
  const _BottomScene({
    required this.controller,
    required this.feedback,
    required this.coins,
    this.explanation,
    this.maxHeight = double.infinity,
  });

  final AnimationController controller;
  final _Feedback feedback;
  final int coins;
  final String? explanation;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final mascotSize = math.min(math.min(w * .42, 190.0), maxHeight / 1.25);
      return SizedBox(
        height: mascotSize * 1.25,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // الشخصية: تقفز عند الصواب وتهتزّ عند الخطأ
            Positioned(
              left: 0,
              bottom: 0,
              child: AnimatedBuilder(
                animation: controller,
                builder: (_, child) {
                  final t = controller.value;
                  final dy = feedback == _Feedback.correct ? -math.sin(t * math.pi) * 34 : 0.0;
                  final dx = feedback == _Feedback.wrong ? math.sin(t * math.pi * 6) * 10 * (1 - t) : 0.0;
                  return Transform.translate(offset: Offset(dx, dy), child: child);
                },
                child: Mascot(size: mascotSize),
              ),
            ),
            // صندوق الكنز
            Positioned(
              left: w * .40,
              bottom: 0,
              child: AnimatedScale(
                scale: feedback == _Feedback.correct ? 1.1 : 1,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutBack,
                child: AppAssets.has(AssetPaths.chest)
                    ? Image.asset(AssetPaths.chest, height: w * .30)
                    : Icon(Icons.inventory_2_rounded, size: w * .26, color: const Color(0xFF8B5A2B)),
              ),
            ),
            // فقاعة القطع
            Positioned(right: 10, bottom: 6, child: CoinBubble(coins: coins)),

            // فقاعة الشرح فوق الشخصية بعد الإجابة الخاطئة
            if (explanation != null)
              Positioned(
                left: mascotSize * .55,
                right: 12,
                top: -40,
                child: _SpeechBubble(text: explanation!),
              ),
          ],
        ),
      );
    });
  }
}

class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      builder: (_, v, child) => Transform.scale(scale: v, alignment: Alignment.bottomLeft, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.purpleText, width: 2),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))],
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, height: 1.5, fontWeight: FontWeight.w700, color: AppColors.darkBrown),
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
      color: const Color(0xFFE0922E),
      padding: EdgeInsets.fromLTRB(16, 10, 16, 12 + MediaQuery.paddingOf(context).bottom),
      child: Row(
        children: [
          // في RTL أول عنصر يظهر يميناً → «4/14» على اليمين كما في التصميم
          Text(
            '$current/$total',
            textDirection: TextDirection.ltr,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              shadows: [Shadow(color: Colors.black38, offset: Offset(0, 2))],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: StripedProgressBar(value: total == 0 ? 0 : current / total)),
        ],
      ),
    );
  }
}
