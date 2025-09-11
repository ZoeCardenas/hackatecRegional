// front/lib/pages/first.dart
import 'dart:convert';
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
  // ----------------- Controllers / State -----------------
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _eeaController = TextEditingController();
  final ScrollController _scroll = ScrollController();

  final List<String> messages = [];
  bool _isLoading = false;

  // API bases
  static const String _apiBaseAi = 'http://127.0.0.1:8000/ai';
  static const String _apiBaseFlows = 'http://127.0.0.1:8000/flows';

  // Sesión/Flujos
  String? _sessionId;

  // DASS-21 (inline en el chat)
  int _dassIndex = 0;
  String? _dassQuestion;
  bool _inDass = false;

  // Negociación (se envía como mensajes, sin tarjeta)
  bool _inNegotiation = false;
  String? _negotiationCommitQ; // pregunta de compromiso
  bool _commitAccepted = false; // <- NUEVO: ya aceptó los 30 min

  // 🎤 STT
  late final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;

  // 🔊 TTS
  final FlutterTts _tts = FlutterTts();
  bool _ttsReady = false;
  bool _voiceEnabled = false;

  // ----------------- Init -----------------
  @override
  void initState() {
    super.initState();
    _initTTS();

    // Mensaje fijo
    messages.add(
        "🤖 IA: Hola, soy Coralia. Si estás en peligro inmediato, toca SOS para llamar a emergencias.");

    // Primero creamos sesión para tener sid, luego saludamos con contexto
    _startFirstContact().then((_) => _bienvenida());
  }

  // ----------------- HTTP helpers -----------------
  Future<Map<String, dynamic>> _get(
      String base, String path, Map<String, String> q) async {
    final uri = Uri.parse("$base/$path").replace(queryParameters: q);
    final r = await http.get(uri);
    if (r.statusCode != 200) {
      throw Exception('GET $path → HTTP ${r.statusCode}: ${r.body}');
    }
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _post(
      String base, String path, Map<String, dynamic> body) async {
    final uri = Uri.parse("$base/$path");
    final r = await http.post(uri,
        headers: {'Content-Type': 'application/json'}, body: jsonEncode(body));
    if (r.statusCode != 200) {
      throw Exception('POST $path → HTTP ${r.statusCode}: ${r.body}');
    }
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  // ----------------- TTS / Typing -----------------
  Future<void> _initTTS() async {
    try {
      await _tts.awaitSpeakCompletion(true);
      await _tts.setLanguage('es-MX');
      await _tts.setSpeechRate(0.45);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      setState(() => _ttsReady = true);
    } catch (_) {
      setState(() => _ttsReady = false);
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

  String _sanitize(String text) {
    final noThink =
        text.replaceAll(RegExp(r'<think>.*?</think>', dotAll: true), '');
    return noThink.replaceAll(RegExp(r'<[^>]+>'), '').trim();
  }

  void _typeAndSpeak(String fullText) {
    final text = _sanitize(fullText);
    messages.add("🤖 IA: ");
    final int idx = messages.length - 1;
    _scrollToBottom();
    _speak(text);
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
        _scroll.position.maxScrollExtent + 180,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  // ----------------- IA (saludo / chat) -----------------
  Future<void> _bienvenida() async {
    try {
      final data = await _get(_apiBaseAi, 'saludos', {
        'name': 'Zoe',
        if (_sessionId != null) 'sid': _sessionId!,
      });
      final saludo = _sanitize(data['respuesta']?.toString() ?? '');
      if (saludo.isNotEmpty) _typeAndSpeak(saludo);
    } catch (e) {
      messages.add("⚠️ Error saludo: $e");
      setState(() {});
    }
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
      final data = await _get(_apiBaseAi, 'respuestas', {
        'name': 'Zoe',
        'interaccion': message,
        if (_sessionId != null) 'sid': _sessionId!,
      });
      final iaRaw = (data['respuesta'] ?? '').toString();
      final ia = _sanitize(iaRaw);

      // si back marca crisis=true, muestra SOS
      final isCrisis = data['crisis'] == true;
      if (isCrisis) _showSOSDialog();

      if (ia.isNotEmpty) {
        _typeAndSpeak(ia);
      } else {
        messages.add("🤖 IA: (sin contenido)");
        setState(() {});
      }
    } catch (e) {
      messages.add("⚠️ Error de red: $e");
      setState(() {});
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  // ----------------- FLOWS: DASS-21 inline -----------------
  Future<void> _startFirstContact() async {
    try {
      final data = await _post(
        _apiBaseFlows,
        'first-contact/start',
        {"user_id": null, "channel": "web"},
      );
      _sessionId = data['session_id']?.toString();
      _dassIndex = (data['question_index'] ?? 0) as int;
      _dassQuestion = data['question_text']?.toString();
      _inDass = true;

      // Introducción al DASS como mensaje del bot
      messages.add(
          "🩺 Empecemos con DASS-21. Responde según la última semana (0=Nada, 1=Un poco, 2=Bastante, 3=Mucho).");
      setState(() {});
      _scrollToBottom();
    } catch (e) {
      messages.add("⚠️ No pude iniciar DASS-21: $e");
      setState(() {});
    }
  }

  Future<void> _dassAnswer(int value) async {
    if (_sessionId == null) return;
    try {
      final data = await _post(_apiBaseFlows, 'dass21/answer', {
        "session_id": _sessionId,
        "index": _dassIndex,
        "value": value,
      });

      if (data['done'] == true) {
        final scores = data['scores'];
        final resumen =
            "🩺 Resultados DASS-21 → Depresión: ${scores['depresion']['severity']} (${scores['depresion']['score']}), "
            "Ansiedad: ${scores['ansiedad']['severity']} (${scores['ansiedad']['score']}), "
            "Estrés: ${scores['estres']['severity']} (${scores['estres']['score']}).";
        messages.add("🤖 IA: $resumen");
        setState(() {});
        _speak(resumen);

        // Cierra bloque DASS e inicia negociación como continuación del chat
        _inDass = false;
        _inNegotiation = true;
        _negotiationIntro();
      } else {
        // Siguiente pregunta
        _dassIndex = data['next_index'] as int;
        _dassQuestion = data['next_text']?.toString();
        setState(() {});
        _scrollToBottom();
      }
    } catch (e) {
      messages.add("⚠️ Error guardando respuesta DASS-21: $e");
      setState(() {});
    }
  }

  // ----------------- Negociación como chat -----------------
  Future<void> _negotiationIntro() async {
    await _negotiationSend("Gracias por acompañarme.");
  }

  Future<void> _negotiationSend(String userMsg) async {
    if (_sessionId == null) return;
    try {
      final data = await _post(_apiBaseFlows, 'negotiation/message', {
        "session_id": _sessionId,
        "user_message": userMsg,
      });

      final bot = (data['message'] ?? '').toString();
      final ask = data['ask_commitment'] == true;
      final q = data['commitment_question']?.toString();

      if (bot.isNotEmpty) {
        messages.add("🤖 IA: $bot");
        setState(() {});
        _speak(bot);
      }

      // Solo mostramos el compromiso si NO se ha aceptado previamente
      if (!_commitAccepted && ask && q != null) {
        _negotiationCommitQ = q;
        messages.add("🤖 IA: $q");
        setState(() {});
      }
    } catch (e) {
      messages.add("⚠️ Error en negociación: $e");
      setState(() {});
    }
  }

  Future<void> _acceptCommitment() async {
    // Oculta el banner de compromiso y marca como aceptado permanentemente
    _commitAccepted = true;
    _negotiationCommitQ = null;
    setState(() {});

    // Registramos la aceptación como mensaje del usuario para mantener el hilo
    messages.add("🧑: Sí, acepto el plan de 30 minutos seguros.");
    setState(() {});
    _scrollToBottom();

    // Enviamos al backend, pero si vuelve a preguntar, ya no lo mostraremos
    await _negotiationSend("Acepto el plan de 30 minutos seguros.");
  }

  // ----------------- Mindfulness rápido -----------------
  Future<void> _quickMindfulness() async {
    setState(() => _isLoading = true);
    try {
      final data = await _get(_apiBaseAi, 'mindfullness', {
        'name': 'Zoe',
        'interaccion': 'Necesito relajarme',
        if (_sessionId != null) 'sid': _sessionId!,
      });
      final txt = _sanitize(data['respuesta']?.toString() ?? '');
      if (txt.isNotEmpty) _typeAndSpeak(txt);
    } catch (e) {
      messages.add("⚠️ Error mindfulness: $e");
      setState(() {});
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  // ----------------- STT -----------------
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

  // ----------------- SOS -----------------
  void _showSOSDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: const Center(
          child: Text(
            'LLAMARÉ AL\n911',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 26, fontWeight: FontWeight.bold, color: Colors.red),
          ),
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

  // ----------------- UI -----------------
  @override
  void dispose() {
    _messageController.dispose();
    _eeaController.dispose();
    _scroll.dispose();
    _tts.stop();
    super.dispose();
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

            // Panel principal
            Expanded(
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('CORALIA',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                  ),

                  // ------ Chat scroller con DASS inline al final ------
                  Expanded(
                    child: ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: messages.length + (_inDass ? 1 : 0),
                      itemBuilder: (context, index) {
                        // Último item: UI de DASS-21
                        if (_inDass && index == messages.length) {
                          return _buildDassInlineCard();
                        }

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
                              child: Text(messages[index],
                                  textAlign: TextAlign.left),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Banner de compromiso (solo si no se aceptó)
                  if (_negotiationCommitQ != null && !_commitAccepted)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Row(
                        children: [
                          Expanded(child: Text(_negotiationCommitQ!)),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _acceptCommitment,
                            child: const Text('Sí, acepto'),
                          ),
                        ],
                      ),
                    ),

                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(),
                    ),

                  // ------ Input fila ------
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
                                  borderRadius: BorderRadius.circular(20)),
                            ),
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Mindfulness',
                          icon: const Icon(Icons.self_improvement),
                          onPressed: _quickMindfulness,
                        ),
                        IconButton(
                          icon: Icon(
                            _isListening ? Icons.mic_none : Icons.mic,
                            color: _isListening
                                ? const Color.fromARGB(255, 255, 255, 255)
                                : Colors.black,
                          ),
                          onPressed: _startListening,
                        ),
                        IconButton(
                          icon: const Icon(Icons.send),
                          onPressed: _sendMessage,
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

  // ----------------- Widgets auxiliares -----------------
  Widget _buildDassInlineCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 720),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.lightBlue[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('DASS-21 (${_dassIndex + 1}/21)',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(_dassQuestion ?? '...'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  _dassBtn(0, '0 Nada'),
                  _dassBtn(1, '1 Un poco'),
                  _dassBtn(2, '2 Bastante'),
                  _dassBtn(3, '3 Mucho'),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _dassBtn(int val, String label) {
    return ElevatedButton(
      onPressed: () => _dassAnswer(val),
      child: Text(label),
    );
  }
}
