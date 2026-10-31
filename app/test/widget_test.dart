import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_islami/data/models.dart';
import 'package:quiz_islami/data/quiz_repository.dart';
import 'package:quiz_islami/features/map/map_screen.dart';
import 'package:quiz_islami/features/quiz/quiz_screen.dart';
import 'package:quiz_islami/main.dart';

QuizQuestion q(String id, int correct) => QuizQuestion(
      id: id,
      text: 'سؤال $id',
      choices: ['أ$id', 'ب$id', 'ج$id'],
      correctIndex: correct,
      explanation: 'شرح $id',
    );

Widget rtl(Widget child) => MaterialApp(
      home: Directionality(textDirection: TextDirection.rtl, child: Scaffold(body: child)),
    );

void phone(WidgetTester t) {
  t.view.physicalSize = const Size(1080, 2340); // 360×780 dp
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
}

/// La mascotte de la carte s'anime en boucle : on avance le temps par pas fixes.
Future<void> steps(WidgetTester t, int seconds) async {
  for (var i = 0; i < seconds * 4; i++) {
    await t.pump(const Duration(milliseconds: 250));
  }
}

void main() {
  test('حساب النجوم مطابق لقواعد الخادم', () {
    expect(DemoQuizRepository.starsFor(5, 5), 3);
    expect(DemoQuizRepository.starsFor(4, 5), 2);
    expect(DemoQuizRepository.starsFor(2, 5), 1);
    expect(DemoQuizRepository.starsFor(1, 5), 0);
  });

  test('القطع تُمنح فقط عند تحسين النتيجة، والمستوى التالي يُفتح', () async {
    final repo = DemoQuizRepository();
    var r = await repo.submitAttempt(1, [1, 2, 3, 1, 1]); // 4/5
    expect((r.stars, r.coinsEarned, r.coinsBalance), (2, 40, 40));
    r = await repo.submitAttempt(1, [2, 2, 2, 2, 2]); // أسوأ
    expect((r.stars, r.coinsEarned, r.coinsBalance), (1, 0, 40));
    final map = await repo.loadMap();
    expect(map.starsOf(1), 2);
    expect(map.isUnlocked(1), isTrue);
    expect(map.isUnlocked(2), isFalse);
    expect(map.currentIndex, 1);
  });

  testWidgets('شاشة السؤال: 3 خيارات، القطع، التقدّم، والإجابات المرسلة', (tester) async {
    phone(tester);
    List<int>? sent;
    await tester.pumpWidget(rtl(QuizGame(
      questions: [q('1', 0), q('2', 2)],
      startCoins: 20,
      onFinished: (a) => sent = a,
    )));
    await tester.pumpAndSettle();

    expect(find.byType(ChoiceCard), findsNWidgets(3));
    expect(find.text('0/2'), findsOneWidget);
    expect(find.text('20'), findsOneWidget);

    await tester.tap(find.text('أ1')); // صحيح
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('30'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('سؤال 2'), findsOneWidget);
    await tester.tap(find.text('أ2')); // خطأ → يظهر الشرح
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('شرح 2'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget); // الإجابة الصحيحة مُظهرة
    expect(find.byIcon(Icons.close), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 4));

    expect(sent, [1, 1]);
  });

  testWidgets('النقر المتكرر لا يسجّل إجابتين', (tester) async {
    List<int>? sent; // taille par défaut (800×600, paysage) : pas de débordement
    await tester.pumpWidget(rtl(QuizGame(questions: [q('1', 0)], onFinished: (a) => sent = a)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('أ1'));
    await tester.tap(find.text('ب1'));
    await tester.pumpAndSettle(const Duration(seconds: 4));
    expect(sent, [1]);
  });

  testWidgets('الخريطة تعرض المستويات وتفتح مستوى ثم تعرض النتيجة', (tester) async {
    phone(tester);

    await tester.pumpWidget(const ProviderScope(child: QuizApp()));
    await tester.tap(find.text('ابدأ اللعب'));
    await steps(tester, 2);
    expect(find.byType(MapScreen), findsOneWidget);
    expect(find.text('1'), findsWidgets);

    await tester.tap(find.text('1').first);
    await steps(tester, 2);
    expect(find.byType(ChoiceCard), findsNWidgets(3));

    // نجيب على الأسئلة الخمسة بالإجابة الصحيحة
    for (final answer in [
      'الحمدُ للهِ الذي أحياني بعدَ ما أماتني وإليه النُّشورُ',
      'ركعتان',
      'بسمِ الله',
      'خمسُ صلوات',
      'ثلاثُ ركعات'
    ]) {
      await tester.tap(find.text(answer));
      await steps(tester, 3);
    }
    expect(find.text('المستوى 1'), findsOneWidget);
    expect(find.text('ممتاز! بارك الله فيك'), findsOneWidget);
    expect(find.text('+50'), findsOneWidget);
  });
}
