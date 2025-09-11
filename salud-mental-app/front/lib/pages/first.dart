// front/lib/pages/first.dart
import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html; // usado solo en Web para redirigir tras rechazo

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt; // 🎤 Voz a texto
import 'package:audioplayers/audioplayers.dart'; // 🔊 Reproducir TTS OpenAI

import '../components/navbar.dart';
import '../components/AvatarAnimado.dart';

enum AppLanguage { esMX, nah } // Náhuatl (experimental)

class First extends StatefulWidget {
  const First({Key? key}) : super(key: key);
  @override
  State<First> createState() => _FirstState();
}

class _FirstState extends State<First> {
  // ----------------- i18n -----------------
  AppLanguage _lang = AppLanguage.esMX;

  final Map<String, Map<String, String>> _i18n = {
    'es-MX': {
      'app_title': 'CORALIA',
      'voice_on': 'Voz activada',
      'voice_enable': 'Activar voz',
      'type_hint': 'Escribe tu mensaje',
      'sos': 'SOS',
      'calling_911': 'LLAMARÉ AL\n911',
      'accept': 'ACEPTAR',
      'cancel': 'CANCELAR',
      'mindfulness': 'Mindfulness',
      'bot_safety':
          '🤖 IA: Hola, soy Coralia. Si estás en peligro inmediato, toca SOS para llamar a emergencias.',
      'dass_intro':
          '🩺 Empecemos con DASS-21. Responde según la última semana (0=Nada, 1=Un poco, 2=Bastante, 3=Mucho).',
      'dass': 'DASS-21',
      'dass_opt0': '0 Nada',
      'dass_opt1': '1 Un poco',
      'dass_opt2': '2 Bastante',
      'dass_opt3': '3 Mucho',
      'bot_empty': '🤖 IA: (sin contenido)',
      'net_error': '⚠ Error de red: ',
      'dass_start_error': '⚠ No pude iniciar DASS-21: ',
      'dass_save_error': '⚠ Error guardando respuesta DASS-21: ',
      'mind_error': '⚠ Error mindfulness: ',
      'nego_error': '⚠ Error en negociación: ',
      'saludo_error': '⚠ Error saludo: ',
      'results_prefix': '🩺 Resultados DASS-21 → ',
      'depresion': 'Depresión',
      'ansiedad': 'Ansiedad',
      'estres': 'Estrés',
      'commit_yes': 'Sí, acepto',
      'commit_msg_user': 'Sí, acepto el plan de 30 minutos seguros.',
    },
    'nah': {
      'app_title': 'CORALIA',
      'voice_on': 'Tlahtol okichiuh',
      'voice_enable': 'Kichiwa tlahtol',
      'type_hint': 'Xijkuilo motlahtōl',
      'sos': 'SOS',
      'calling_911': 'Nijkonetzas 911',
      'accept': 'Kema',
      'cancel': 'Amo',
      'mindfulness': 'Kualli yolmelahualiztli',
      'bot_safety':
          '🤖 IA: Nehuatl ni Coralia. Tla ok itech moneki niman, xitlākan SOS para tlapotōni 911.',
      'dass_intro':
          '🩺 DASS-21. Xiknanquili ika semana tlen panok (0=Ahmo, 1=Mani kīxtzin, 2=Miek, 3=Yolik miek).',
      'dass': 'DASS-21',
      'dass_opt0': '0 Ahmo',
      'dass_opt1': '1 Kīxtzin',
      'dass_opt2': '2 Miek',
      'dass_opt3': '3 Yolik miek',
      'bot_empty': '🤖 IA: (ahmo nimitzitta tlajtoli)',
      'net_error': '⚠ Tlatlākatilis tlen red: ',
      'dass_start_error': '⚠ Ahmo ok pehua DASS-21: ',
      'dass_save_error': '⚠ Tlatlākatilis tlen DASS-21: ',
      'mind_error': '⚠ Tlatlākatilis tlen yolmelahualiztli: ',
      'nego_error': '⚠ Tlatlākatilis tlen tlātlapōhualli: ',
      'saludo_error': '⚠ Tlatlākatilis tlen salutōlo: ',
      'results_prefix': '🩺 DASS-21 → ',
      'depresion': 'Kualli xokotiliztli',
      'ansiedad': 'Tetzauhtli',
      'estres': 'Kokoliztli',
      'commit_yes': 'Kema, nimitzki',
      'commit_msg_user': 'Kema, nimitzki plan de 30 minutos seguros.',
    }
  };

  String tr(String key) {
    final l = _localeCode();
    return _i18n[l]?[key] ?? _i18n['es-MX']![key] ?? key;
  }

  String _localeCode() => _lang == AppLanguage.esMX ? 'es-MX' : 'nah';
  String _sttLocaleId() => 'es-MX'; // STT estable

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

  // DASS-21
  int _dassIndex = 0;
  String? _dassQuestion;
  bool _inDass = false;

  // Negociación
  bool _inNegotiation = false;
  String? _negotiationCommitQ;
  bool _commitAccepted = false;

  // 🎤 STT
  late final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;

  // 🔊 OpenAI TTS (único camino)
  final AudioPlayer _player = AudioPlayer();
  final String _voice = "alloy"; // 👈 misma voz para ES y NAH
  bool _voiceEnabled = false;

  // 🐢 Avatar
  bool _isTalking = false;

  // ---- Consentimiento (overlay) ----
  bool _consentAccepted = false;
  bool _consentDenied = false;
  int _denyCountdown = 5;
  Timer? _denyTimer;

  // ----------------- Init -----------------
  @override
  void initState() {
    super.initState();
    _setupAudioPlayerListener();
    messages.add(tr('bot_safety'));
    _startFirstContact().then((_) => _bienvenida());
    if (kIsWeb) {
      _consentAccepted = html.window.localStorage['coralia_consent'] == '1';
    }
  }

  // ----------------- Audio/Avatar -----------------
  void _setupAudioPlayerListener() {
    _player.onPlayerStateChanged.listen((state) {
      final playing = state == PlayerState.playing;
      if (mounted) {
        setState(() => _isTalking = _voiceEnabled && playing);
      }
    });
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
    final r = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (r.statusCode != 200) {
      throw Exception('POST $path → HTTP ${r.statusCode}: ${r.body}');
    }
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  // ----------------- TTS OpenAI (único) -----------------
  Future<void> _speakOpenAI(String text) async {
    if (!_voiceEnabled) return;
    final txt = text.trim();
    if (txt.isEmpty) return;

    try {
      if (kIsWeb) {
        // WEB: usa base64 + data URL (no BytesSource)
        final url = Uri.parse('$_apiBaseAi/tts_b64');
        final resp = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            "text": txt,
            "voice": _voice,
            "format": "webm"
          }), // 👈 webm en Web
        );
        if (resp.statusCode != 200) {
          throw Exception('TTS (web) HTTP ${resp.statusCode}: ${resp.body}');
        }
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final b64 = (data['audio_b64'] ?? '') as String;
        if (b64.isEmpty) return;

        await _player.stop();
        await _player.play(UrlSource('data:audio/webm;base64,$b64'));
      } else {
        // MOBILE/DESKTOP: bytes directos (mp3)
        final url = Uri.parse('$_apiBaseAi/tts_bytes');
        final resp = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            "text": txt,
            "voice": _voice,
            "format": "mp3"
          }), // 👈 mp3 fuera de Web
        );
        if (resp.statusCode != 200) {
          throw Exception('TTS (bytes) HTTP ${resp.statusCode}: ${resp.body}');
        }
        await _player.stop();
        await _player.play(BytesSource(resp.bodyBytes));
      }
    } catch (e) {
      debugPrint('⚠ TTS error: $e');
    }
  }

  // ----------------- Utilidades texto -----------------
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
    _speakOpenAI(text); // 👈 SIEMPRE OpenAI TTS
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
        'lang': _localeCode(),
      });
      final saludo = _sanitize(data['respuesta']?.toString() ?? '');
      if (saludo.isNotEmpty) _typeAndSpeak(saludo);
    } catch (e) {
      messages.add("${tr('saludo_error')}$e");
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
        'lang': _localeCode(),
      });
      final iaRaw = (data['respuesta'] ?? '').toString();
      final ia = _sanitize(iaRaw);

      if (data['crisis'] == true) _showSOSDialog();

      if (ia.isNotEmpty) {
        _typeAndSpeak(ia);
      } else {
        messages.add(tr('bot_empty'));
        setState(() {});
      }
    } catch (e) {
      messages.add("${tr('net_error')}$e");
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
        {"user_id": null, "channel": "web", "lang": _localeCode()},
      );
      _sessionId = data['session_id']?.toString();
      _dassIndex = (data['question_index'] ?? 0) as int;
      _dassQuestion = data['question_text']?.toString();
      _inDass = true;

      messages.add(tr('dass_intro'));
      setState(() {});
      _scrollToBottom();
    } catch (e) {
      messages.add("${tr('dass_start_error')}$e");
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
        "lang": _localeCode(),
      });

      if (data['done'] == true) {
        final scores = data['scores'];
        final resumen =
            "${tr('results_prefix')}${tr('depresion')}: ${scores['depresion']['severity']} (${scores['depresion']['score']}), "
            "${tr('ansiedad')}: ${scores['ansiedad']['severity']} (${scores['ansiedad']['score']}), "
            "${tr('estres')}: ${scores['estres']['severity']} (${scores['estres']['score']}).";
        messages.add("🤖 IA: $resumen");
        setState(() {});
        _speakOpenAI(resumen);

        _inDass = false;
        _inNegotiation = true;
        _negotiationIntro();
      } else {
        _dassIndex = data['next_index'] as int;
        _dassQuestion = data['next_text']?.toString();
        setState(() {});
        _scrollToBottom();
      }
    } catch (e) {
      messages.add("${tr('dass_save_error')}$e");
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
        "lang": _localeCode(),
      });

      final bot = (data['message'] ?? '').toString();
      final ask = data['ask_commitment'] == true;
      final q = data['commitment_question']?.toString();

      if (bot.isNotEmpty) {
        messages.add("🤖 IA: $bot");
        setState(() {});
        _speakOpenAI(bot);
      }

      if (!_commitAccepted && ask && q != null) {
        _negotiationCommitQ = q;
        messages.add("🤖 IA: $q");
        setState(() {});
      }
    } catch (e) {
      messages.add("${tr('nego_error')}$e");
      setState(() {});
    }
  }

  Future<void> _acceptCommitment() async {
    _commitAccepted = true;
    _negotiationCommitQ = null;
    setState(() {});
    messages.add("🧑: ${tr('commit_msg_user')}");
    setState(() {});
    _scrollToBottom();
    await _negotiationSend(tr('commit_msg_user'));
  }

  // ----------------- Mindfulness rápido -----------------
  Future<void> _quickMindfulness() async {
    setState(() => _isLoading = true);
    try {
      final data = await _get(_apiBaseAi, 'mindfullness', {
        'name': 'Zoe',
        'interaccion': 'Necesito relajarme',
        if (_sessionId != null) 'sid': _sessionId!,
        'lang': _localeCode(),
      });
      final txt = _sanitize(data['respuesta']?.toString() ?? '');
      if (txt.isNotEmpty) _typeAndSpeak(txt);
    } catch (e) {
      messages.add("${tr('mind_error')}$e");
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
        onError: (val) => debugPrint('⚠ onError: $val'),
      );
      if (available) {
        setState(() => _isListening = true);
        await _speech.listen(
          localeId: _sttLocaleId(),
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
        title: Center(
          child: Text(
            tr('calling_911'),
            textAlign: TextAlign.center,
            style: const TextStyle(
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
            },
            child:
                Text(tr('accept'), style: const TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.lightBlue),
            onPressed: () => Navigator.pop(context),
            child:
                Text(tr('cancel'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ----------------- Ciclo de vida -----------------
  @override
  void dispose() {
    _denyTimer?.cancel();
    _messageController.dispose();
    _eeaController.dispose();
    _scroll.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _changeLanguage(AppLanguage newLang) async {
    setState(() => _lang = newLang);
    if (_voiceEnabled) {
      await _speakOpenAI(tr('voice_on')); // misma voz en ambos idiomas
    }
  }

  // ===== Consentimiento como OVERLAY =====

  void _startDenyCountdown() {
    _denyTimer?.cancel();
    setState(() => _denyCountdown = 5);
    _denyTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _denyCountdown--);
      if (_denyCountdown <= 0) {
        t.cancel();
        if (kIsWeb) {
          html.window.location.href = '/';
        } else {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    });
  }

  Widget _buildConsentPanel() {
    bool _checked = false;
    return StatefulBuilder(
      builder: (context, setSB) {
        return SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Consentimiento Informado para el Uso de la Plataforma CoralIA',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const SizedBox(
                height: 360,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 8),
                      Text('1. Introducción',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text(
                          'Usted está por utilizar la plataforma CoralIA, un sistema de acompañamiento psicológico '
                          'diseñado para brindar apoyo emocional mediante herramientas digitales, incluyendo chatbots, '
                          'ejercicios de escritura emocional autorreflexiva y recursos de bienestar mental.\n\n'
                          'Este consentimiento busca informarle sobre el uso, los alcances y las limitaciones de la plataforma, '
                          'así como sobre el manejo de sus datos personales.'),
                      SizedBox(height: 12),
                      Text('2. Objetivo',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text(
                          'La plataforma tiene como finalidad ofrecer apoyo psicológico inicial y promover el autocuidado emocional. '
                          'No sustituye la atención profesional directa ni reemplaza la consulta con un psicólogo o psiquiatra certificado.'),
                      SizedBox(height: 12),
                      Text('3. Procedimiento',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text('Durante el uso de la plataforma, podrá:\n'
                          '• Interactuar con un asistente virtual diseñado para ofrecer respuestas empáticas y recursos de apoyo.\n'
                          '• Acceder a ejercicios de escritura emocional autoreflexiva y de mindfulness.\n'
                          '• Responder cuestionarios validados (DASS-21) para explorar su estado emocional.'),
                      SizedBox(height: 12),
                      Text('4. Beneficios',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text('El uso de la plataforma puede ayudarle a:\n'
                          '• Reflexionar sobre su estado emocional.\n'
                          '• Acceder a herramientas de autocuidado.\n'
                          '• Identificar patrones de estrés, ansiedad o depresión para buscar ayuda oportuna.'),
                      SizedBox(height: 12),
                      Text('5. Riesgos y limitaciones',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text(
                          '• En caso de emergencia, se recomienda acudir inmediatamente a un servicio de urgencias o llamar a '
                          'líneas de apoyo psicológico disponibles en su país.\n'
                          '• CoralIA puede cometer errores en sus textos generados.'),
                      SizedBox(height: 12),
                      Text('6. Manejo de datos personales',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text(
                          '• Sus datos personales serán encriptados y protegidos conforme a la normativa aplicable.\n'
                          '• Los datos recolectados se usarán para mejorar el servicio e investigación, de forma anonimizada.\n'
                          '• Usted podrá solicitar la eliminación de sus datos en cualquier momento.'),
                      SizedBox(height: 12),
                      Text('7. Voluntariedad',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text(
                          'El uso de la plataforma es completamente voluntario. Puede dejar de usarla en cualquier momento.'),
                      SizedBox(height: 12),
                      Text('8. Consentimiento',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text(
                          'Declaro haber leído y comprendido la información anterior. He tenido la oportunidad de hacer preguntas '
                          'y recibí respuestas satisfactorias. Acepto participar de manera libre y voluntaria en el uso de la plataforma CoralIA.'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _checked,
                onChanged: (v) => setSB(() => _checked = v ?? false),
                title: const Text(
                    'He leído y acepto el consentimiento informado.'),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _consentDenied = true;
                        _startDenyCountdown();
                      });
                    },
                    child: const Text('No acepto'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _checked
                        ? () {
                            setState(() => _consentAccepted = true);
                            if (kIsWeb) {
                              html.window.localStorage['coralia_consent'] = '1';
                            }
                          }
                        : null,
                    child: const Text('Aceptar y continuar'),
                  ),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildDeniedPanel() {
    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Disculpa, no te puedo ayudar',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
              'Necesitas aceptar el consentimiento informado para usar la plataforma.\n'
              'Saliendo en $_denyCountdown segundos…'),
        ],
      ),
    );
  }

  // ----------------- UI -----------------
  @override
  Widget build(BuildContext context) {
    final title = tr('app_title');

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
                PopupMenuButton<AppLanguage>(
                  tooltip: 'Idioma',
                  onSelected: _changeLanguage,
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: AppLanguage.esMX,
                      child: Row(
                        children: [
                          Icon(Icons.flag),
                          SizedBox(width: 8),
                          Text('Español (México)'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: AppLanguage.nah,
                      child: Row(
                        children: [
                          Icon(Icons.translate),
                          SizedBox(width: 8),
                          Text('Nāhuatl (experimental)'),
                        ],
                      ),
                    ),
                  ],
                  child: Row(
                    children: [
                      const Icon(Icons.language),
                      const SizedBox(width: 6),
                      Text(_lang == AppLanguage.esMX ? 'ES-MX' : 'NAH'),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // 🔊 Alternador de voz (OpenAI TTS)
                IconButton(
                  tooltip: _voiceEnabled ? tr('voice_on') : tr('voice_enable'),
                  onPressed: () async {
                    setState(() => _voiceEnabled = !_voiceEnabled);
                    if (!_voiceEnabled) {
                      await _player.stop();
                      if (mounted) setState(() => _isTalking = false);
                    } else {
                      await _speakOpenAI(tr('voice_on'));
                    }
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
        child: Stack(
          children: [
            // ===== CONTENIDO NORMAL =====
            Row(
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
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: _showSOSDialog,
                        child: const Text(
                          'SOS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Panel principal
                Expanded(
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 6),
                      AvatarAnimado(
                        talking: _isTalking,
                        size: 160,
                        speed: const Duration(milliseconds: 180),
                        idleFrameIndex: 1,
                      ),
                      const SizedBox(height: 6),

                      // ------ Chat + DASS inline ------
                      Expanded(
                        child: ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          itemCount: messages.length + (_inDass ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (_inDass && index == messages.length) {
                              return _buildDassInlineCard();
                            }

                            final isUser = messages[index].startsWith("🧑");
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 6.0),
                              child: Align(
                                alignment: isUser
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  constraints:
                                      const BoxConstraints(maxWidth: 720),
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

                      if (_negotiationCommitQ != null && !_commitAccepted)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Row(
                            children: [
                              Expanded(child: Text(_negotiationCommitQ!)),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _acceptCommitment,
                                child: Text(tr('commit_yes')),
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _messageController,
                                minLines: 1,
                                maxLines: 4,
                                decoration: InputDecoration(
                                  hintText: tr('type_hint'),
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
                              tooltip: tr('mindfulness'),
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

            // ===== OVERLAY CONSENTIMIENTO =====
            if (!_consentAccepted)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.45),
                  alignment: Alignment.center,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Material(
                      elevation: 8,
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: _consentDenied
                            ? _buildDeniedPanel()
                            : _buildConsentPanel(),
                      ),
                    ),
                  ),
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
              Text(
                '${tr('dass')} (${_dassIndex + 1}/21)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(_dassQuestion ?? '...'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  _dassBtn(0, tr('dass_opt0')),
                  _dassBtn(1, tr('dass_opt1')),
                  _dassBtn(2, tr('dass_opt2')),
                  _dassBtn(3, tr('dass_opt3')),
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
