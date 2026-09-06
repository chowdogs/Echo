import 'package:flutter_tts/flutter_tts.dart';

/// Wraps the platform Text-to-Speech engine.
///
/// This is the app's single seam to spoken audio: [TileState] calls [speak] and
/// nothing else needs to know how speech is produced. Every call is guarded so a
/// TTS failure (or an unsupported platform) can never break the UI — it simply
/// stays silent.
class TtsService {
  TtsService() {
    _init();
  }

  final FlutterTts _tts = FlutterTts();

  Future<void> _init() async {
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.5); // calm, intelligible default
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
    } catch (_) {
      // Engine unavailable on this platform — speak() will no-op.
    }
  }

  /// Speaks [phrase] aloud, interrupting anything already playing so rapid taps
  /// don't queue up a backlog.
  Future<void> speak(String phrase) async {
    if (phrase.trim().isEmpty) return;
    try {
      await _tts.stop();
      await _tts.speak(phrase);
    } catch (_) {
      // Never let a speech failure surface to the user.
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
