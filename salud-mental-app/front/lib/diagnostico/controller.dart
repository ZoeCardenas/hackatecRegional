import 'dart:io';
import 'package:flutter/material.dart';
import 'api_service.dart';

class DiagnosticoController extends ChangeNotifier {
  File? imagenSeleccionada;
  String resultado = '';
  bool cargando = false;

  void setImagen(File imagen) {
    imagenSeleccionada = imagen;
    notifyListeners();
  }

  Future<void> diagnosticar() async {
    if (imagenSeleccionada == null) return;
    cargando = true;
    notifyListeners();

    try {
      final respuesta = await ApiService.enviarImagen(imagenSeleccionada!);
      final tiene = respuesta['prediccion'] ?? 'No detectado';
      final confianzaValor = respuesta['confianza'] ?? 0.0;

      resultado =
          "Resultado: $tiene\nConfianza: ${confianzaValor.toStringAsFixed(2)}%\nConsulta a un médico lo antes posible.";
    } catch (e) {
      resultado = "Error al diagnosticar: $e";
    }

    cargando = false;
    notifyListeners();
  }

  double get confianza {
    final regex = RegExp(r'Confianza: ([\d.]+)%');
    final match = regex.firstMatch(resultado);
    return match != null ? double.parse(match.group(1)!) : 0.0;
  }
}
