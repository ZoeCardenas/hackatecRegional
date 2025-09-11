// lib/components/AvatarAnimado.dart
import 'dart:async';
import 'package:flutter/material.dart';

/// Avatar de tortuga que “mueve la boca” mientras [talking] sea true.
/// Cambia de frame con un Timer.periodic y vuelve al frame de reposo cuando
/// talking es false.
///
/// Frames esperados (en este orden):
/// 0) assets/imagenes/Auxilia.png        // boca abierta
/// 1) assets/imagenes/avatar_bc_1.png    // boca cerrada (idle)
/// 2) assets/imagenes/avatar_bc_2.png    // variación/sonrisa
class AvatarAnimado extends StatefulWidget {
  /// Si true, se anima (va rotando frames). Si false, se queda en idle.
  final bool talking;

  /// Tamaño cuadrado del avatar.
  final double size;

  /// Velocidad de cambio de frame durante la animación.
  final Duration speed;

  /// Índice de frame para reposo (boca cerrada).
  final int idleFrameIndex;

  const AvatarAnimado({
    super.key,
    required this.talking,
    this.size = 120.0,
    this.speed = const Duration(milliseconds: 180),
    this.idleFrameIndex = 1,
  });

  @override
  State<AvatarAnimado> createState() => _AvatarAnimadoState();
}

class _AvatarAnimadoState extends State<AvatarAnimado> {
  Timer? _timer;
  int _index = 0;

  /// Asegúrate de tener estos assets en pubspec.yaml -> flutter -> assets:
  /// - assets/imagenes/Auxilia.png
  /// - assets/imagenes/avatar_bc_1.png
  /// - assets/imagenes/avatar_bc_2.png
  final List<String> _frames = const <String>[
    'assets/imagenes/avatar_ba_1.png', // 0: boca abierta
    'assets/imagenes/avatar_bc_1.png', // 1: boca cerrada (idle)
    'assets/imagenes/avatar_bc_2.png', // 2: variación/sonrisa
    'assets/imagenes/avatar_ba_2.png',
  ];

  @override
  void initState() {
    super.initState();
    _index = widget.idleFrameIndex.clamp(0, _frames.length - 1);
    _ensureTimer();
  }

  @override
  void didUpdateWidget(covariant AvatarAnimado oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reinicia el timer si cambian: talking, speed o idleFrameIndex.
    if (oldWidget.talking != widget.talking ||
        oldWidget.speed != widget.speed ||
        oldWidget.idleFrameIndex != widget.idleFrameIndex) {
      _ensureTimer();
    }
  }

  void _ensureTimer() {
    _timer?.cancel();

    if (widget.talking) {
      // Mientras “hable”, rotamos frames 0->1->2->0...
      _timer = Timer.periodic(widget.speed, (_) {
        if (!mounted) return;
        setState(() {
          _index = (_index + 1) % _frames.length;
        });
      });
    } else {
      // Reposo: boca cerrada (idle)
      setState(() {
        _index = widget.idleFrameIndex.clamp(0, _frames.length - 1);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safeIndex = _index.clamp(0, _frames.length - 1);
    return Center(
      child: Image.asset(
        _frames[safeIndex],
        width: widget.size,
        height: widget.size,
        fit: BoxFit.contain,
        // Si algún asset faltara, no rompas la app:
        errorBuilder: (_, __, ___) => const SizedBox(
          width: 1,
          height: 1,
        ),
      ),
    );
  }
}
