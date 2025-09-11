import 'package:flutter/material.dart';
import 'chat_texto.dart';
import 'chat_voz.dart';
import 'resultado_widget.dart';

class WidgetSelector extends StatelessWidget {
  final String resultado;
  final double confianza;
  final String modo;

  const WidgetSelector({
    super.key,
    required this.resultado,
    required this.confianza,
    required this.modo,
  });

  @override
  Widget build(BuildContext context) {
    switch (modo) {
      case 'voz':
        return ChatVoz(
          mensaje: resultado, // Solo este parámetro se requiere ahora
        );
      case 'texto':
        return ChatTexto(mensaje: resultado);
      default:
        return ResultadoWidget(
          resultado: resultado,
          confianza: confianza,
        );
    }
  }
}
