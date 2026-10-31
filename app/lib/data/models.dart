/// نماذج البيانات — تطابق جداول Supabase.
library;

class World {
  const World({
    required this.id,
    required this.name,
    required this.mapBackground,
    required this.quizBackground,
    required this.sortOrder,
  });

  final int id;
  final String name;
  final String mapBackground;
  final String quizBackground;
  final int sortOrder;

  factory World.fromJson(Map<String, dynamic> j) => World(
        id: j['id'] as int,
        name: j['name'] as String,
        mapBackground: j['map_background'] as String,
        quizBackground: j['quiz_background'] as String,
        sortOrder: j['sort_order'] as int,
      );
}

class Level {
  const Level({
    required this.id,
    required this.worldId,
    required this.number,
    required this.coinsPerCorrect,
    this.title,
  });

  final int id;
  final int worldId;
  final int number;
  final int coinsPerCorrect;
  final String? title;

  factory Level.fromJson(Map<String, dynamic> j) => Level(
        id: j['id'] as int,
        worldId: j['world_id'] as int,
        number: j['number'] as int,
        coinsPerCorrect: j['coins_per_correct'] as int,
        title: j['title'] as String?,
      );
}

class QuizQuestion {
  QuizQuestion({
    required this.id,
    required this.text,
    required this.choices,
    required this.correctIndex,
    this.explanation,
    this.sourceRef,
  })  : assert(choices.length == 3, 'يجب أن يكون للسؤال 3 خيارات بالضبط'),
        assert(correctIndex >= 0 && correctIndex < 3);

  final String id;
  final String text;
  final List<String> choices;

  /// من 0 إلى 2 في التطبيق (من 1 إلى 3 في قاعدة البيانات).
  final int correctIndex;
  final String? explanation;
  final String? sourceRef;

  factory QuizQuestion.fromJson(Map<String, dynamic> j) => QuizQuestion(
        id: j['id'] as String,
        text: j['text_ar'] as String,
        choices: [j['choice_1'] as String, j['choice_2'] as String, j['choice_3'] as String],
        correctIndex: (j['correct_choice'] as int) - 1,
        explanation: j['explanation'] as String?,
        sourceRef: j['source_ref'] as String?,
      );
}

class LevelProgress {
  const LevelProgress({required this.levelId, required this.bestStars, required this.bestCorrect});

  final int levelId;
  final int bestStars;
  final int bestCorrect;

  factory LevelProgress.fromJson(Map<String, dynamic> j) => LevelProgress(
        levelId: j['level_id'] as int,
        bestStars: j['best_stars'] as int,
        bestCorrect: j['best_correct'] as int,
      );
}

/// ما يرسله الخادم بعد submit_attempt.
class AttemptResult {
  const AttemptResult({
    required this.stars,
    required this.coinsEarned,
    required this.correct,
    required this.total,
    required this.coinsBalance,
  });

  final int stars;
  final int coinsEarned;
  final int correct;
  final int total;
  final int coinsBalance;

  factory AttemptResult.fromJson(Map<String, dynamic> j) => AttemptResult(
        stars: j['stars'] as int,
        coinsEarned: j['coins_earned'] as int,
        correct: j['correct'] as int,
        total: j['total'] as int,
        coinsBalance: j['coins_balance'] as int,
      );
}

/// كل ما تحتاجه شاشة الخريطة دفعة واحدة.
class MapData {
  const MapData({
    required this.worlds,
    required this.levels,
    required this.progress,
    required this.coins,
  });

  final List<World> worlds;
  final List<Level> levels; // مرتّبة حسب number
  final Map<int, LevelProgress> progress; // levelId → التقدّم
  final int coins;

  int starsOf(int levelId) => progress[levelId]?.bestStars ?? 0;

  /// المستوى مفتوح إذا كان الأول، أو إذا حصل اللاعب على نجمة واحدة على الأقل في السابق.
  bool isUnlocked(int index) => index == 0 || starsOf(levels[index - 1].id) >= 1;

  /// المستوى الحالي = أول مستوى مفتوح لم يُنجز بعد.
  int get currentIndex {
    for (var i = 0; i < levels.length; i++) {
      if (isUnlocked(i) && starsOf(levels[i].id) == 0) return i;
    }
    return levels.isEmpty ? 0 : levels.length - 1;
  }

  int get totalStars => levels.fold(0, (s, l) => s + starsOf(l.id));
  double get globalProgress => levels.isEmpty ? 0 : totalStars / (levels.length * 3);

  World worldOf(Level l) => worlds.firstWhere((w) => w.id == l.worldId, orElse: () => worlds.first);
}
