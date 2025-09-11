import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt; // 🎤 Voz a texto
import 'package:flutter_tts/flutter_tts.dart'; // 🔊 Texto a voz
import '../components/navbar.dart';

class First extends StatefulWidget {
  const First({Key? key}) : super(key: key);
  @override
  State<First> createState() => _FirstState();
}

class _FirstState extends State<First> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scroll = ScrollController();

  final List<String> messages = [];
  bool _isLoading = false;

  // 🌐 URL del backend
  // - Web: localhost
  // - Emulador Android: 10.0.2.2:8000
  // - Dispositivo físico: CAMBIA POR LA IP DE TU PC en la misma red (ej. 192.168.1.80:8000)
  static const String _lanPcIp = '192.168.1.80:8000'; // <-- AJUSTA
  String get _apiBase {
    if (kIsWeb) return 'http://127.0.0.1:8000';
    // Si estás en emulador Android, usa 10.0.2.2; en físico, tu IP LAN
    return 'http://10.0.2.2:8000'; // cambia a 'http://$_lanPcIp' si es teléfono físico
  }

  // 🎤 STT
  late final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;

  // 🔊 TTS
  final FlutterTts _tts = FlutterTts();
  bool _ttsReady = false;
  bool _voiceEnabled = false; // usuario debe activarla (especialmente en Web)

  @override
  void initState() {
    super.initState();
    _initTTS();
    // Mensaje de bienvenida
    messages.add(
        "🤖 IA: Hola, soy Coralia. Si estás en peligro inmediato, toca SOS para llamar a emergencias.");
  }

  Future<void> _initTTS() async {
    try {
      await _tts.awaitSpeakCompletion(true);
      await _tts.setLanguage('es-MX'); // 'es-ES' si prefieres
      await _tts.setSpeechRate(0.45);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      setState(() => _ttsReady = true);
    } catch (_) {
      setState(() => _ttsReady = false);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scroll.dispose();
    _tts.stop();
    super.dispose();
  }

  String _sanitize(String text) {
    // Oculta <think>...</think> y cualquier etiqueta HTML/XML
    final noThink =
        text.replaceAll(RegExp(r'<think>.*?</think>', dotAll: true), '');
    return noThink.replaceAll(RegExp(r'<[^>]+>'), '').trim();
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() {
      _isLoading = true;
      messages.add("🧑: $message");
      _messageController.clear();
    });
    _scrollToBottom();

    try {
      final response = await http.post(
        Uri.parse("$_apiBase/chat/chat"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'message': message}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> steps =
            (data['first_aid_steps'] ?? []) as List<dynamic>;
        final String iaRaw = (data['assist_response'] ?? '').toString();
        final String ia = _sanitize(iaRaw);

        if (steps.isNotEmpty) {
          final pasos =
              "🩺 Pasos recomendados:\n• ${steps.map((e) => _sanitize(e.toString())).join("\n• ")}";
          messages.add(pasos);
        }

        if (ia.isNotEmpty) {
          _typeAndSpeak(ia);
        } else {
          messages.add("🤖 IA: (sin contenido)");
        }
      } else {
        messages.add("❌ Error del servidor: ${response.statusCode}");
      }
    } catch (e) {
      messages.add("⚠️ Error de red: $e");
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  Future<void> _speak(String text) async {
    if (!_ttsReady || !_voiceEnabled) return;
    if (text.isEmpty) return;
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {}
  }

  void _typeAndSpeak(String fullText) {
    final text = _sanitize(fullText);

    // Arranca burbuja vacía
    messages.add("🤖 IA: ");
    final int idx = messages.length - 1;
    _scrollToBottom();

    // Hablar ya
    _speak(text);

    // Efecto de tipeo
    const int chunk = 3;
    const int ms = 18;
    int i = 0;

    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: ms));
      if (!mounted) return false;
      setState(() {
        i = (i + chunk).clamp(0, text.length);
        messages[idx] = "🤖 IA: ${text.substring(0, i)}";
      });
      _scrollToBottom();
      return i < text.length;
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  // 🎤 Iniciar/detener STT
  Future<void> _startListening() async {
    if (!_isListening) {
      final available = await _speech.initialize(
        onStatus: (val) => debugPrint('🔊 onStatus: $val'),
        onError: (val) => debugPrint('⚠️ onError: $val'),
      );
      if (available) {
        setState(() => _isListening = true);
        await _speech.listen(
          localeId: 'es-MX',
          onResult: (val) =>
              setState(() => _messageController.text = val.recognizedWords),
        );
      }
    } else {
      await _speech.stop();
      setState(() => _isListening = false);
    }
  }

  void _showSOSDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: const Center(
          child: Text('LLAMARÉ AL\n911',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.red)),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              debugPrint('📞 Llamando al 911');
              // TODO: url_launcher -> launchUrl(Uri.parse('tel:911'));
            },
            child: const Text('ACEPTAR', style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.lightBlue),
            onPressed: () => Navigator.pop(context),
            child:
                const Text('CANCELAR', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      drawer: const CustomNavBar(),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 187, 196, 189),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Logo opcional (no truena si no existe)
            Image.asset(
              'assets/imagenes/2.png',
              height: 40,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
            Row(
              children: [
                IconButton(
                  tooltip: _voiceEnabled ? 'Voz activada' : 'Activar voz',
                  onPressed: !_ttsReady
                      ? null
                      : () async {
                          // En Web, requerimos un gesto; aquí lo obtenemos.
                          setState(() => _voiceEnabled = true);
                          await _speak('Voz activada');
                        },
                  icon: Icon(
                    _voiceEnabled ? Icons.volume_up : Icons.volume_off,
                    color: _voiceEnabled ? Colors.green[700] : Colors.black54,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Row(
          children: [
// Barra SOS
            Container(
              width: 80,
              color: Colors.red,
              child: Center(
                child: RotatedBox(
                  quarterTurns: 1,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: _showSOSDialog,
                    child: const Text(
                      'SOS',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ),

            // Chat
            Expanded(
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('CORALIA',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final isUser = messages[index].startsWith("🧑");
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: Align(
                            alignment: isUser
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 720),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isUser
                                    ? Colors.green[100]
                                    : Colors.lightBlue[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                messages[index],
                                textAlign: TextAlign.left,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(),
                    ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            minLines: 1,
                            maxLines: 4,
                            decoration: InputDecoration(
                              hintText: 'Escribe tu mensaje',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            _isListening ? Icons.mic_none : Icons.mic,
                            color: _isListening
                                ? const Color.fromARGB(255, 255, 255, 255)
                                : Colors.black,
                          ),
                          onPressed: _startListening, // 🎤 Voz a texto
                        ),
                        IconButton(
                          icon: const Icon(Icons.send),
                          onPressed: _sendMessage, // 📩 Enviar
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
