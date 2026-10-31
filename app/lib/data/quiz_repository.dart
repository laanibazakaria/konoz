import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';

/// واجهة الوصول إلى البيانات. الشاشات لا تعرف إن كان المصدر Supabase أو بيانات تجريبية.
abstract class QuizRepository {
  Future<MapData> loadMap();
  Future<List<QuizQuestion>> loadQuestions(int levelId);

  /// [answers]: اختيار اللاعب لكل سؤال بالترتيب، من 1 إلى 3.
  Future<AttemptResult> submitAttempt(int levelId, List<int> answers);
}

// ═══════════════════════════ Supabase ═══════════════════════════
class SupabaseQuizRepository implements QuizRepository {
  SupabaseQuizRepository(this._db);
  final SupabaseClient _db;

  /// دخول مجهول: الطفل يلعب دون بريد إلكتروني، ويمكن ربط الحساب لاحقاً.
  Future<void> ensureSignedIn() async {
    if (_db.auth.currentSession == null) {
      await _db.auth.signInAnonymously();
    }
  }

  @override
  Future<MapData> loadMap() async {
    await ensureSignedIn();
    final uid = _db.auth.currentUser!.id;

    final results = await Future.wait([
      _db.from('worlds').select().order('sort_order'),
      _db.from('levels').select('id, world_id, number, title, coins_per_correct').order('number'),
      _db.from('level_progress').select('level_id, best_stars, best_correct'),
      _db.from('profiles').select('coins').eq('id', uid).maybeSingle(),
    ]);

    final progress = <int, LevelProgress>{
      for (final row in results[2] as List)
        (row['level_id'] as int): LevelProgress.fromJson(row as Map<String, dynamic>),
    };
    final profile = results[3] as Map<String, dynamic>?;

    return MapData(
      worlds: (results[0] as List).map((e) => World.fromJson(e as Map<String, dynamic>)).toList(),
      levels: (results[1] as List).map((e) => Level.fromJson(e as Map<String, dynamic>)).toList(),
      progress: progress,
      coins: (profile?['coins'] as int?) ?? 0,
    );
  }

  @override
  Future<List<QuizQuestion>> loadQuestions(int levelId) async {
    final rows = await _db
        .from('questions')
        .select('id, text_ar, choice_1, choice_2, choice_3, correct_choice, explanation, source_ref')
        .eq('level_id', levelId)
        .eq('status', 'published')
        .order('position')
        .order('id'); // نفس ترتيب submit_attempt على الخادم
    return (rows as List).map((e) => QuizQuestion.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<AttemptResult> submitAttempt(int levelId, List<int> answers) async {
    final rows = await _db.rpc('submit_attempt', params: {
      'p_level_id': levelId,
      'p_answers': answers,
    });
    return AttemptResult.fromJson((rows as List).first as Map<String, dynamic>);
  }
}

// ═══════════════════ وضع تجريبي (دون اتصال / دون Supabase) ═══════════════════
/// يعيد نفس قواعد الحساب الموجودة في submit_attempt على الخادم.
class DemoQuizRepository implements QuizRepository {
  int _coins = 0;
  final Map<int, LevelProgress> _progress = {};

  static const _worlds = [
    World(
        id: 1,
        name: 'الوادي',
        mapBackground: 'assets/backgrounds/map_canyon.png',
        quizBackground: 'assets/backgrounds/quiz_forest_day.png',
        sortOrder: 1),
    World(
        id: 2,
        name: 'الأدغال الليلية',
        mapBackground: 'assets/backgrounds/map_purple.png',
        quizBackground: 'assets/backgrounds/quiz_jungle_night.png',
        sortOrder: 2),
    World(
        id: 3,
        name: 'الصحراء',
        mapBackground: 'assets/backgrounds/map_desert.png',
        quizBackground: 'assets/backgrounds/quiz_desert.png',
        sortOrder: 3),
  ];

  static final Map<int, List<QuizQuestion>> _questions = {
    1: [
      QuizQuestion(
          id: '1-1',
          text: 'ماذا تقولُ إذا استيقظتَ من نومِك؟',
          choices: const [
            'الحمدُ للهِ الذي أحياني بعدَ ما أماتني وإليه النُّشورُ',
            'باسمِكَ اللهمَّ أموتُ وأحيا',
            'بسمِ الله',
          ],
          correctIndex: 0,
          explanation: '«باسمك اللهم أموت وأحيا» نقولها قبل النوم.',
          sourceRef: 'صحيح البخاري 6312'),
      QuizQuestion(
          id: '1-2',
          text: 'كم عددُ ركعاتِ صلاةِ الصُّبح؟',
          choices: const ['أربعُ ركعات', 'ركعتان', 'ثلاثُ ركعات'],
          correctIndex: 1,
          explanation: 'فريضة الصبح (الفجر) ركعتان.'),
      QuizQuestion(
          id: '1-3',
          text: 'ماذا تقولُ قبلَ أن تبدأَ الطعام؟',
          choices: const ['الحمدُ لله', 'سبحانَ الله', 'بسمِ الله'],
          correctIndex: 2,
          explanation: 'قال النبي ﷺ: «يا غلام، سمِّ الله، وكُلْ بيمينك».',
          sourceRef: 'صحيح البخاري 5376'),
      QuizQuestion(
          id: '1-4',
          text: 'كم عددُ الصلواتِ المفروضةِ في اليومِ والليلة؟',
          choices: const ['خمسُ صلوات', 'ثلاثُ صلوات', 'سبعُ صلوات'],
          correctIndex: 0),
      QuizQuestion(
          id: '1-5',
          text: 'كم عددُ ركعاتِ صلاةِ المغرب؟',
          choices: const ['ركعتان', 'ثلاثُ ركعات', 'أربعُ ركعات'],
          correctIndex: 1),
    ],
    2: [
      QuizQuestion(
          id: '2-1',
          text: 'كم عددُ أركانِ الإسلام؟',
          choices: const ['ثلاثة', 'ستة', 'خمسة'],
          correctIndex: 2,
          explanation: 'الشهادتان، الصلاة، الزكاة، صوم رمضان، الحج.'),
      QuizQuestion(
          id: '2-2',
          text: 'ما هو الركنُ الأولُ من أركانِ الإسلام؟',
          choices: const ['الشهادتان', 'الصلاة', 'الصوم'],
          correctIndex: 0),
      QuizQuestion(
          id: '2-3', text: 'في أيِّ شهرٍ يصومُ المسلمون؟', choices: const ['شعبان', 'رمضان', 'شوّال'], correctIndex: 1),
      QuizQuestion(
          id: '2-4',
          text: 'إلى أينَ نتّجهُ في الصلاة؟',
          choices: const ['إلى المسجد الأقصى', 'إلى جبل عرفات', 'إلى الكعبة المشرّفة'],
          correctIndex: 2),
      QuizQuestion(
          id: '2-5',
          text: 'كم عددُ أركانِ الإيمان؟',
          choices: const ['ستة', 'خمسة', 'أربعة'],
          correctIndex: 0,
          explanation: 'الإيمان بالله وملائكته وكتبه ورسله واليوم الآخر والقدر خيره وشره.'),
    ],
    3: [
      QuizQuestion(
          id: '3-1',
          text: 'ما هي أولُ سورةٍ في المصحف؟',
          choices: const ['سورة البقرة', 'سورة الفاتحة', 'سورة الناس'],
          correctIndex: 1),
      QuizQuestion(
          id: '3-2',
          text: 'كم عددُ سورِ القرآنِ الكريم؟',
          choices: const ['114 سورة', '100 سورة', '120 سورة'],
          correctIndex: 0),
      QuizQuestion(
          id: '3-3',
          text: 'مَن هو خاتمُ الأنبياءِ والمرسلين؟',
          choices: const ['عيسى عليه السلام', 'إبراهيم عليه السلام', 'محمد ﷺ'],
          correctIndex: 2),
      QuizQuestion(
          id: '3-4',
          text: 'ما هي أطولُ سورةٍ في القرآن؟',
          choices: const ['سورة آل عمران', 'سورة البقرة', 'سورة النساء'],
          correctIndex: 1),
      QuizQuestion(
          id: '3-5',
          text: 'في أيِّ مدينةٍ وُلِدَ النبيُّ ﷺ؟',
          choices: const ['مكة المكرّمة', 'المدينة المنوّرة', 'الطائف'],
          correctIndex: 0),
    ],
  };

  // 3 مستويات فيها أسئلة + مستويات مقفلة لعرض شكل الخريطة
  static final _levels = [
    for (var n = 1; n <= 24; n++) Level(id: n, worldId: n <= 8 ? 1 : (n <= 16 ? 2 : 3), number: n, coinsPerCorrect: 10),
  ];

  @override
  Future<MapData> loadMap() async => MapData(
        worlds: _worlds,
        levels: _levels,
        progress: Map.of(_progress),
        coins: _coins,
      );

  @override
  Future<List<QuizQuestion>> loadQuestions(int levelId) async =>
      _questions[levelId] ?? _questions[((levelId - 1) % 3) + 1]!;

  @override
  Future<AttemptResult> submitAttempt(int levelId, List<int> answers) async {
    final qs = await loadQuestions(levelId);
    if (answers.length != qs.length) throw StateError('invalid answers');
    var correct = 0;
    for (var i = 0; i < qs.length; i++) {
      if (answers[i] == qs[i].correctIndex + 1) correct++;
    }
    final stars = starsFor(correct, qs.length);
    final prev = _progress[levelId];
    final coins = stars > (prev?.bestStars ?? 0) ? correct * 10 : 0;
    _coins += coins;
    _progress[levelId] = LevelProgress(
      levelId: levelId,
      bestStars: math.max(stars, prev?.bestStars ?? 0),
      bestCorrect: math.max(correct, prev?.bestCorrect ?? 0),
    );
    return AttemptResult(stars: stars, coinsEarned: coins, correct: correct, total: qs.length, coinsBalance: _coins);
  }

  /// نفس العتبات الموجودة في SQL: 100% → 3، ‏70% → 2، ‏40% → 1.
  static int starsFor(int correct, int total) {
    if (correct == total) return 3;
    if (correct >= (total * 0.7).ceil()) return 2;
    if (correct >= (total * 0.4).ceil()) return 1;
    return 0;
  }
}
