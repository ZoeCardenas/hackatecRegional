import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class ChatVoz extends StatelessWidget {
  final String mensaje;

  const ChatVoz({super.key, required this.mensaje});

  Future<void> _hablar(String texto) async {
    final FlutterTts flutterTts = FlutterTts();

    await flutterTts.setLanguage("es-MX");
    await flutterTts.setPitch(1.0);
    await flutterTts.setSpeechRate(0.4); // Velocidad más cómoda
    await flutterTts.speak(texto);
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => _hablar(mensaje),
      icon: const Icon(Icons.volume_up),
      label: const Text("Escuchar diagnóstico"),
    );
  }
}
