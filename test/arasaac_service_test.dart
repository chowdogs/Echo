import 'dart:convert';

import 'package:echo/models/pictogram.dart';
import 'package:echo/services/arasaac_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A trimmed-down sample of what the ARASAAC search endpoint returns.
const String _sampleJson = '''
[
  {"_id": 2248, "keywords": [{"keyword": "water"}]},
  {"_id": 3418, "keywords": [{"keyword": "drink water"}]}
]
''';

void main() {
  group('ArasaacService', () {
    test('parses pictograms from a 200 JSON response', () async {
      final client = MockClient((http.Request request) async {
        // Sanity-check the request the service builds.
        expect(request.method, 'GET');
        expect(request.url.host, 'api.arasaac.org');
        expect(request.url.path, contains('/search/water'));
        return http.Response(_sampleJson, 200);
      });

      final service = ArasaacService(client: client);
      final List<Pictogram> results = await service.searchPictograms('water');

      expect(results, hasLength(2));
      expect(results.first.id, 2248);
      expect(results.first.keyword, 'water');
      expect(results.first.imageUrl, contains('2248'));
    });

    test('returns an empty list when the word has no matches (404)', () async {
      final client = MockClient(
        (http.Request request) async => http.Response('Not found', 404),
      );

      final service = ArasaacService(client: client);
      expect(await service.searchPictograms('zzzznotaword'), isEmpty);
    });

    test('throws a friendly error on a server failure (500)', () async {
      final client = MockClient(
        (http.Request request) async => http.Response('boom', 500),
      );

      final service = ArasaacService(client: client);
      expect(
        () => service.searchPictograms('water'),
        throwsA(isA<ArasaacException>()),
      );
    });

    test('an empty query does not hit the network', () async {
      var called = false;
      final client = MockClient((http.Request request) async {
        called = true;
        return http.Response('[]', 200);
      });

      final service = ArasaacService(client: client);
      expect(await service.searchPictograms('   '), isEmpty);
      expect(called, isFalse);
    });
  });

  test('Pictogram builds a 300px image URL from its id', () {
    const Pictogram p = Pictogram(id: 2248, keyword: 'water');
    expect(
      p.imageUrl,
      'https://static.arasaac.org/pictograms/2248/2248_300.png',
    );
  });

  test('Pictogram.fromJson tolerates a missing id', () {
    expect(
      Pictogram.fromJson(<String, dynamic>{'keywords': <dynamic>[]}),
      isNull,
    );
    final Pictogram? p = Pictogram.fromJson(
      jsonDecode('{"_id": 7, "keywords": [{"keyword": "eat"}]}')
          as Map<String, dynamic>,
    );
    expect(p?.id, 7);
    expect(p?.keyword, 'eat');
  });
}
