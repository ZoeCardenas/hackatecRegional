// front/lib/widgets/avatar_popup.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../services/tts_service.dart'; // ajusta ruta si tu TtsService está en otra carpeta

/// AvatarPopup
/// - Usa 4 assets en assets/imagenes/:
///   avatar_bc_1.png  (boca cerrada, ojos abiertos)
///   avatar_bc_2.png  (boca cerrada, ojos cerrados)
///   avatar_ba_1.png  (boca abierta, ojos abiertos)
///   avatar_ba_2.png  (boca abierta, ojos cerrados)
///
/// Uso:
/// 1) Coloca el widget dentro de la jerarquía de tu página (por ejemplo, en un Stack).
/// 2) Dale una key global si quieres controlarlo externamente:
///    final GlobalKey<AvatarPopupState> avatarKey = GlobalKey();
///    AvatarPopup(key: avatarKey)
/// 3) Para hablar + animar desde tu lógica:
///    await avatarKey.currentState?.speakAndAnimate("Texto a leer");
///
/// Nota: el widget internamente llama a TtsService().speak(text) si existe.
/// Si no quieres que llame TtsService, usa startSpeaking()/stopSpeaking() y reproduce TTS por tu cuenta.
class AvatarPopup extends StatefulWidget {
  const AvatarPopup({
    Key? key,
    this.marginFromEdge = const EdgeInsets.only(left: 16, top: 16),
    this.minSize = 76,
    this.maxSize = 260,
    this.avatarPrefix =
        'avatar', // si usas otro prefijo en nombres, por ejemplo 'miavatar'
    this.animateOnSpeak = true,
    this.enableTapToExpand = true,
  }) : super(key: key);

  final EdgeInsets marginFromEdge;
  final double minSize;
  final double maxSize;
  final String avatarPrefix;
  final bool animateOnSpeak;
  final bool enableTapToExpand;

  @override
  AvatarPopupState createState() => AvatarPopupState();
}

class AvatarPopupState extends State<AvatarPopup>
    with TickerProviderStateMixin {
  // estado expandido
  bool _expanded = false;

  // anim controllers
  late final AnimationController _sizeController;
  late final Animation<double> _sizeAnim;

  // blinking
  Timer? _blinkTimer;
  bool _eyesClosed = false;

  // mouth animation while speaking
  Timer? _mouthTimer;
  bool _mouthOpen = false;

  // small bobbing / translate while speaking
  late final AnimationController _bobController;
  late final Animation<double> _bobAnim;

  // control de speaking (interno)
  bool _isSpeaking = false;

  // random para jitter en la animación de boca
  final Random _rng = Random();

  // TtsService fallback: si quieres que el widget haga el speak
  final TtsService _tts = TtsService();

  @override
  void initState() {
    super.initState();

    _sizeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _sizeAnim = CurvedAnimation(parent: _sizeController, curve: Curves.easeOut);

    _bobController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _bobAnim = Tween<double>(begin: 0, end: 6).animate(
        CurvedAnimation(parent: _bobController, curve: Curves.easeInOut));

    _startBlinkCycle();
  }

  @override
  void dispose() {
    _sizeController.dispose();
    _bobController.dispose();
    _stopBlinkCycle();
    _stopMouthAnimation();
    super.dispose();
  }

  // ---------------- Public API ----------------

  /// Llama a TtsService().speak(text) y anima automáticamente
  Future<void> speakAndAnimate(String text) async {
    if (text.trim().isEmpty) return;
    // arrancamos animaciones
    startSpeaking();
    try {
      // usa la instancia TtsService (asegúrate de que la ruta importada sea correcta)
      await _tts.speak(text);
      // wait: según configuración de TtsService puede esperar a completion
    } catch (e) {
      // ignore errors (pero paramos animación)
    } finally {
      stopSpeaking();
    }
  }

  /// Iniciar animación de speaking (útil si manejas TTS fuera del widget)
  void startSpeaking() {
    if (_isSpeaking) return;
    _isSpeaking = true;
    _startMouthAnimation();
    _bobController.repeat(reverse: true);
  }

  /// Parar animación de speaking
  void stopSpeaking() {
    if (!_isSpeaking) return;
    _isSpeaking = false;
    _stopMouthAnimation();
    _bobController.stop();
    _setMouthClosed();
  }

  /// Alterna expandido/contraído (tap handler interno)
  void toggleExpanded() {
    _expanded = !_expanded;
    if (_expanded) {
      _sizeController.forward();
    } else {
      _sizeController.reverse();
    }
    setState(() {});
  }

  // ---------------- Internal helpers ----------------

  void _startBlinkCycle() {
    _blinkTimer?.cancel();
    // schedule first blink a 1-3s para que no parpadee justo al inicio siempre
    final first = 800 + _rng.nextInt(2200);
    _blinkTimer = Timer(Duration(milliseconds: first), _blinkOnce);
  }

  void _blinkOnce() {
    if (!mounted) return;
    setState(() => _eyesClosed = true);
    // ojos cerrados solo 180-320ms
    final closeFor = 160 + _rng.nextInt(180);
    Timer(Duration(milliseconds: closeFor), () {
      if (!mounted) return;
      setState(() => _eyesClosed = false);
      // program next blink random 2-6s
      final next = 1200 + _rng.nextInt(5000);
      _blinkTimer = Timer(Duration(milliseconds: next), _blinkOnce);
    });
  }

  void _stopBlinkCycle() {
    _blinkTimer?.cancel();
    _blinkTimer = null;
  }

  void _startMouthAnimation() {
    _mouthTimer?.cancel();
    int baseMs = 140;
    _mouthOpen = true;
    _mouthTimer = Timer.periodic(Duration(milliseconds: baseMs), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _mouthOpen = !_mouthOpen;
      });
      // jitter re-seed
      if (_rng.nextDouble() < 0.12) {
        t.cancel();
        final jitter = baseMs + (_rng.nextInt(120) - 60);
        _mouthTimer = Timer.periodic(Duration(milliseconds: jitter), (t2) {
          if (!mounted) return t2.cancel();
          setState(() => _mouthOpen = !_mouthOpen);
        });
      }
    });
  }

  void _stopMouthAnimation() {
    _mouthTimer?.cancel();
    _mouthTimer = null;
  }

  void _setMouthClosed() {
    if (!mounted) return;
    setState(() => _mouthOpen = false);
  }

  // ---------------- Image selection ----------------
  // mapear nombres de asset a estados
  String _currentAssetPath() {
    // nombres que me indicaste: avatar_bc_1, avatar_bc_2, avatar_ba_1, avatar_ba_2
    // ba = boca abierta, bc = boca cerrada, _1 = ojos abiertos, _2 = ojos cerrados
    final eyesSuffix = _eyesClosed ? '_2' : '_1';
    final mouthPrefix = _mouthOpen ? 'avatar_ba' : 'avatar_bc';
    final fileName = '${mouthPrefix}${eyesSuffix}.png';
    // assets/imagenes/<fileName>
    return 'assets/imagenes/$fileName';
  }

  // ---------------- Build ----------------

  @override
  Widget build(BuildContext context) {
    // tamaño interpolado
    final min = widget.minSize;
    final max = widget.maxSize;
    final size = min + (max - min) * _sizeAnim.value;

    // posición: top-left offset según margin
    final top = widget.marginFromEdge.top;
    final left = widget.marginFromEdge.left;

    // bobbing offset while speaking
    final bob = (_isSpeaking && widget.animateOnSpeak) ? _bobAnim.value : 0.0;

    return Positioned(
      top: top + bob,
      left: left + bob / 2,
      child: GestureDetector(
        onTap: widget.enableTapToExpand ? toggleExpanded : null,
        behavior: HitTestBehavior.translucent,
        child: AnimatedBuilder(
          animation: Listenable.merge([_sizeController, _bobController]),
          builder: (context, _) {
            return Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12 + (20 * _sizeAnim.value)),
              color: Colors.white.withOpacity(0.9),
              child: Container(
                width: size,
                height: size,
                padding: EdgeInsets.all(6 + (10 * _sizeAnim.value)), // interior
                child: Stack(
                  children: [
                    // avatar image (center)
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: Image.asset(
                          _currentAssetPath(),
                          key: ValueKey(_currentAssetPath()),
                          width: size * 0.92,
                          height: size * 0.92,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) {
                            // fallback simple si no encuentra asset
                            return Container(
                              width: size * 0.9,
                              height: size * 0.9,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.person,
                                  size: size * 0.5, color: Colors.grey[600]),
                            );
                          },
                        ),
                      ),
                    ),

                    // small badge / expanded content example
                    if (_expanded)
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('Coralia',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                      ),
                    // optional speaking indicator (dot)
                    if (_isSpeaking)
                      Positioned(
                        left: 6,
                        top: 6,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.greenAccent[400],
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.greenAccent.withOpacity(0.6),
                                  blurRadius: 6,
                                  spreadRadius: 1)
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
