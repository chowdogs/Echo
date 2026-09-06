import 'dart:convert';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;

/// Turns a phrase into spoken audio.
///
/// Prefers the ElevenLabs API (natural, multilingual voices — it reads Tagalog
/// far better than the device engine), and falls back to the platform TTS
/// engine when no key is set or the network call fails. Every path is guarded
/// so a speech failure can never break the UI.
class TtsService {
  TtsService({
    this.elevenLabsApiKey,
    this.voiceId = _defaultVoiceId,
    this.modelId = _defaultModelId,
    http.Client? client,
  }) : _client = client ?? http.Client() {
    _initFallback();
  }

  /// A pre-made ElevenLabs voice ("Rachel") available on the shared voice
  /// library. Change it in main.dart to any voice id from your account.
  static const String _defaultVoiceId = '21m00Tcm4TlvDq8ikWAM';

  /// Multilingual model — auto-detects the language of the text (incl. Tagalog).
  static const String _defaultModelId = 'eleven_multilingual_v2';

  final String? elevenLabsApiKey;
  final String voiceId;
  final String modelId;
  final http.Client _client;

  final AudioPlayer _player = AudioPlayer();
  final FlutterTts _fallback = FlutterTts();

  Future<void> _initFallback() async {
    try {
      await _fallback.setLanguage('en-US');
      await _fallback.setSpeechRate(0.5);
      await _fallback.setPitch(1.0);
      await _fallback.setVolume(1.0);
    } catch (_) {
      // Engine unavailable on this platform.
    }
  }

  bool get _hasElevenLabs =>
      elevenLabsApiKey != null && elevenLabsApiKey!.trim().isNotEmpty;

  /// Speaks [phrase] aloud, interrupting anything already playing.
  Future<void> speak(String phrase) async {
    final String text = phrase.trim();
    if (text.isEmpty) return;

    if (_hasElevenLabs) {
      try {
        final Uint8List audio = await _synthesize(text);
        await _player.stop();
        await _player.play(BytesSource(audio, mimeType: 'audio/mpeg'));
        return;
      } catch (_) {
        // ElevenLabs unreachable / quota / offline — fall back to device TTS.
      }
    }

    try {
      await _fallback.stop();
      await _fallback.speak(text);
    } catch (_) {
      // Never let a speech failure surface to the user.
    }
  }

  /// POSTs the text to ElevenLabs and returns the MP3 bytes.
  Future<Uint8List> _synthesize(String text) async {
    final Uri url = Uri.parse(
      'https://api.elevenlabs.io/v1/text-to-speech/$voiceId',
    );
    final http.Response resp = await _client
        .post(
          url,
          headers: <String, String>{
            'xi-api-key': elevenLabsApiKey!,
            'Content-Type': 'application/json',
            'Accept': 'audio/mpeg',
          },
          body: jsonEncode(<String, dynamic>{
            'text': text,
            'model_id': modelId,
            'voice_settings': <String, dynamic>{
              'stability': 0.5,
              'similarity_boost': 0.75,
            },
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (resp.statusCode != 200) {
      throw Exception('ElevenLabs error (${resp.statusCode}).');
    }
    return resp.bodyBytes;
  }

  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {}
    try {
      await _fallback.stop();
    } catch (_) {}
  }
}
