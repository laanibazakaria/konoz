import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quiz_islami/core/install/install.dart';
import 'package:quiz_islami/core/widgets.dart';
import 'package:quiz_islami/data/models.dart';
import 'package:quiz_islami/features/home/install_button.dart';
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

/// Écran en arabe, avec le réglage système « réduire les animations » :
/// la mascotte et le décor restent immobiles, donc pumpAndSettle peut se terminer.
Widget rtl(Widget child) => MaterialApp(
      builder: (context, c) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: c!),
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
    expect(find.byIcon(Icons.check_rounded), findsOneWidget); // الإجابة الصحيحة مُظهرة
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
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
    expect(find.text('المستوى 1'), findsWidgets); // titre en contour : 2 couches de texte
    expect(find.text('ممتاز! بارك الله فيك'), findsOneWidget);
    expect(find.text('+50'), findsOneWidget);
  });

  testWidgets('sans images fournies, l écran de question ne demande aucune image', (tester) async {
    phone(tester);
    await tester.pumpWidget(rtl(QuizGame(questions: [q('1', 0)], onFinished: (_) {})));
    await tester.pump(const Duration(milliseconds: 300)); // pendant l'animation du parchemin

    expect(find.byType(Image), findsNothing); // ni mascotte, ni coffre, ni fond
    final images = tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .where((d) => d.image != null);
    expect(images, isEmpty); // ni parchemin, ni cartes en bois
    await tester.pumpAndSettle();
  });

  testWidgets('bouton d installation : caché si installée, instructions sur iPhone', (tester) async {
    await tester.pumpWidget(rtl(const InstallButton(stateOverride: InstallState.installed)));
    expect(find.byType(TextButton), findsNothing);

    await tester.pumpWidget(rtl(const InstallButton(stateOverride: InstallState.available)));
    expect(find.text('ثبّت التطبيق على هاتفك'), findsOneWidget);

    await tester.pumpWidget(rtl(const InstallButton(key: ValueKey('ios'), stateOverride: InstallState.ios)));
    await tester.tap(find.text('ثبّت التطبيق على هاتفك'));
    await tester.pumpAndSettle();
    expect(find.text('اختر «إضافة إلى الشاشة الرئيسية»'), findsOneWidget);
  });

  // Petit téléphone → grand écran, dont 1366×650 (ordinateur portable, la taille signalée).
  for (final size in const [
    Size(360, 640),
    Size(390, 844),
    Size(412, 915),
    Size(768, 1024),
    Size(1024, 600),
    Size(1366, 650),
    Size(1920, 1080),
  ]) {
    testWidgets('${size.width.toInt()}×${size.height.toInt()} : les 3 réponses sont visibles et cliquables',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const ProviderScope(child: QuizApp()));
      await tester.tap(find.text('ابدأ اللعب'));
      await steps(tester, 2);
      await tester.tap(find.text('1').first);
      await steps(tester, 2);

      expect(tester.takeException(), isNull); // aucun débordement de mise en page
      expect(tester.getSize(find.byType(QuizGame)).width, lessThanOrEqualTo(480));

      final screen = Offset.zero & size;
      final cards = find.byType(ChoiceCard);
      expect(cards, findsNWidgets(3));
      for (var i = 0; i < 3; i++) {
        final card = cards.at(i);
        final rect = tester.getRect(card);
        expect(screen.intersect(rect), rect, reason: 'carte $i hors écran'); // entièrement visible
        // rien ne recouvre la carte : un toucher en son centre l'atteint bien
        final hit = HitTestResult();
        tester.binding.hitTestInView(hit, rect.center, tester.view.viewId);
        expect(hit.path.any((e) => e.target == tester.renderObject(card)), isTrue, reason: 'carte $i recouverte');
      }
    });
  }

  testWidgets('accueil : le décor et le contenu occupent toute la largeur', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ProviderScope(child: QuizApp()));
    await steps(tester, 1);
    expect(tester.getSize(find.byType(GameBackground)).width, 390);
  });
}
