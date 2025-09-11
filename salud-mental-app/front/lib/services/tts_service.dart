import 'dart:convert';
import 'dart:io';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

class TtsService {
  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _player = AudioPlayer();

  Future<void> init() async {
    await _tts.awaitSpeakCompletion(true);
    await _tts.setLanguage("es-MX");
    await _tts.setSpeechRate(0.40);
    await _tts.setPitch(1.05);
  }

  Future<void> speak(String text, {String lang = "es-MX"}) async {
    if (lang == "nah") {
      await _speakNahuatl(text);
    } else {
      await _tts.speak(text);
    }
  }

  Future<void> _speakNahuatl(String text) async {
    try {
      final uri = Uri.parse("http://127.0.0.1:8000/ai/genera_voz")
          .replace(queryParameters: {"prompt": text, "lang": "shimmer"});
      final r = await http.get(uri);

      if (r.statusCode != 200) throw Exception("Error TTS OpenAI");

      final data = jsonDecode(r.body);
      final b64 = data["audio_b64"] as String;
      final bytes = base64Decode(b64);

      final dir = await getTemporaryDirectory();
      final file = File("${dir.path}/tts_nahuatl.mp3");
      await file.writeAsBytes(bytes);

      await _player.play(DeviceFileSource(file.path));
    } catch (e) {
      print("⚠️ Error en TTS Náhuatl: $e");
    }
  }
}
