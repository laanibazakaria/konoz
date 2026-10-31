import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quiz_islami/data/quiz_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Faux serveur Supabase : enregistre les requêtes et renvoie des données minimales.
({SupabaseClient client, List<Uri> requests}) fakeSupabase() {
  final requests = <Uri>[];
  final mock = MockClient((req) async {
    requests.add(req.url);
    final path = req.url.path;
    Object body = [];
    if (path.startsWith('/auth/v1/')) {
      body = {
        'access_token': 'token',
        'token_type': 'bearer',
        'expires_in': 3600,
        'expires_at': DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
        'refresh_token': 'refresh',
        'user': {
          'id': 'u1',
          'aud': 'authenticated',
          'role': 'authenticated',
          'app_metadata': {},
          'user_metadata': {},
          'created_at': '2026-01-01T00:00:00Z',
          'is_anonymous': true,
        },
      };
    } else if (path.endsWith('/worlds')) {
      body = [
        {'id': 1, 'name': 'الوادي', 'map_background': 'm', 'quiz_background': 'q', 'sort_order': 1},
      ];
    } else if (path.endsWith('/levels')) {
      body = [
        for (final n in [1, 2, 3, 4]) {'id': n, 'world_id': 1, 'number': n, 'title': null, 'coins_per_correct': 10},
      ];
    } else if (path.endsWith('/profiles')) {
      body = {'coins': 30};
    }
    return http.Response(jsonEncode(body), 200,
        request: req, headers: {'content-type': 'application/json; charset=utf-8'});
  });
  final client = SupabaseClient(
    'https://demo.supabase.co',
    'sb_publishable_test',
    httpClient: mock,
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  return (client: client, requests: requests);
}

void main() {
  // Régression : le client Dart trie en ordre DÉCROISSANT par défaut ; la carte
  // s'affichait à l'envers (niveau 4 en bas) et les questions dans le mauvais ordre.
  test('carte : mondes et niveaux demandés en ordre croissant', () async {
    final fake = fakeSupabase();
    final map = await SupabaseQuizRepository(fake.client).loadMap();

    final orders = {
      for (final u in fake.requests)
        if (u.queryParameters['order'] != null) u.pathSegments.last: u.queryParameters['order']!,
    };
    expect(orders['worlds'], startsWith('sort_order.asc'));
    expect(orders['levels'], startsWith('number.asc'));
    expect(map.levels.map((l) => l.number), [1, 2, 3, 4]);
    expect(map.isUnlocked(0), isTrue); // le niveau 1 est bien le premier, ouvert
    expect(map.coins, 30);
  });

  test('questions demandées dans le même ordre que le calcul du score sur le serveur', () async {
    final fake = fakeSupabase();
    await SupabaseQuizRepository(fake.client).loadQuestions(1);

    final order = fake.requests.singleWhere((u) => u.path.endsWith('/questions')).queryParameters['order']!;
    // SQL côté serveur : order by position, id (croissant)
    expect(order.split(','), [startsWith('position.asc'), startsWith('id.asc')]);
  });
}
