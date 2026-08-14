import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/pictogram.dart';

/// A friendly, already-explained failure the UI can show as-is.
class ArasaacException implements Exception {
  const ArasaacException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Talks to the ARASAAC pictogram API — a free, open library of AAC
/// communication symbols (https://arasaac.org). No API key is required.
///
/// This is the app's single seam to that service: the widget layer calls
/// [searchPictograms] and only ever deals with a list of [Pictogram] or an
/// [ArasaacException] with a message ready to display.
class ArasaacService {
  ArasaacService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _host = 'api.arasaac.org';

  /// Searches ARASAAC for [query] and returns matching pictograms.
  ///
  /// [language] is a two-letter code (defaults to English). Throws an
  /// [ArasaacException] with a human-readable message on any network, server,
  /// or parsing problem, so callers have one thing to catch.
  Future<List<Pictogram>> searchPictograms(
    String query, {
    String language = 'en',
  }) async {
    final String trimmed = query.trim();
    if (trimmed.isEmpty) return <Pictogram>[];

    final Uri url = Uri.https(
      _host,
      '/api/pictograms/$language/search/$trimmed',
    );

    final http.Response response;
    try {
      response = await _client.get(url).timeout(const Duration(seconds: 12));
    } on SocketException {
      throw const ArasaacException(
        'No internet connection. Check your network and try again.',
      );
    } on TimeoutException {
      throw const ArasaacException('The request timed out. Please try again.');
    } catch (_) {
      throw const ArasaacException('Could not reach the symbol library.');
    }

    // ARASAAC returns 404 when a word has no matches — treat that as "empty",
    // not an error.
    if (response.statusCode == 404) return <Pictogram>[];
    if (response.statusCode != 200) {
      throw ArasaacException(
        'The symbol library returned an error (${response.statusCode}).',
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw const ArasaacException('Received an unexpected response.');
    }

    if (decoded is! List) return <Pictogram>[];

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(Pictogram.fromJson)
        .whereType<Pictogram>()
        .take(30) // keep the grid light
        .toList();
  }

  void dispose() => _client.close();
}
