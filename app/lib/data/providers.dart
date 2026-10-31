import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models.dart';
import 'quiz_repository.dart';

/// يُستبدل في main() حسب الإعداد (Supabase أو الوضع التجريبي).
final repositoryProvider = Provider<QuizRepository>((ref) => DemoQuizRepository());

/// بيانات الخريطة. نستدعي ref.invalidate(mapDataProvider) بعد كل مستوى لتحديث النجوم والقطع.
final mapDataProvider = FutureProvider<MapData>((ref) => ref.watch(repositoryProvider).loadMap());

final questionsProvider = FutureProvider.family<List<QuizQuestion>, int>(
  (ref, levelId) => ref.watch(repositoryProvider).loadQuestions(levelId),
);
