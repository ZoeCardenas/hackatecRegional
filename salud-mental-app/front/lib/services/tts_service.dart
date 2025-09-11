import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  static final TtsService _i = TtsService._();
  factory TtsService() => _i;
  TtsService._();

  final FlutterTts _tts = FlutterTts();
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;

    // Recomendado: completar antes de disparar siguiente speak
    await _tts.awaitSpeakCompletion(true);

    // Idioma base (ajusta a tu preferencia)
    await _tts.setLanguage("es-MX"); // "es-ES", "es-US", etc.
    await _tts.setSpeechRate(0.45); // 0.0 - 1.0
    await _tts.setPitch(1.0); // 0.5 - 2.0
    await _tts.setVolume(1.0); // 0.0 - 1.0

    // En web, elegir voz disponible en el navegador
    if (kIsWeb) {
      final voices = await _tts.getVoices;
      // Busca una voz española si existe
      final es = voices?.firstWhere(
        (v) =>
            "${v['name']}".toLowerCase().contains('span') ||
            "${v['locale']}".toLowerCase().startsWith('es'),
        orElse: () => null,
      );
      if (es != null) {
        await _tts.setVoice({"name": es["name"], "locale": es["locale"]});
      }
    }

    // En Android, modo cola para no cortar frases
    if (!kIsWeb && Platform.isAndroid) {
      await _tts.setQueueMode(1); // 0=interrupt, 1=enqueue
    }

    _ready = true;
  }

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    await init();
    // Evita leer etiquetas internas como <think>…</think>
    final sanitized = text
        .replaceAll(RegExp(r'<think>.*?</think>', dotAll: true), '')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .trim();
    await _tts.speak(sanitized);
  }

  Future<void> stop() => _tts.stop();
}
