import 'dart:convert';
import 'dart:typed_data';
import 'dart:io' as io show File;
import 'package:flutter/foundation.dart'; // kIsWeb
import 'package:http/http.dart' as http;

class ApiService {
  static Future<Map<String, dynamic>> enviarImagen(io.File imagen) async {
    try {
      var uri = Uri.parse('http://127.0.0.1:8000/predict');

      var request = http.MultipartRequest('POST', uri);

      if (kIsWeb) {
        final bytes = await imagen.readAsBytes();
        final multipartFile = http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: 'web_image.jpg',
        );
        request.files.add(multipartFile);
      } else {
        request.files.add(await http.MultipartFile.fromPath(
          'file',
          imagen.path,
        ));
      }

      final response = await request.send();

      if (response.statusCode == 200) {
        final res = await response.stream.bytesToString();
        final jsonResponse = json.decode(res);
        return {
          'prediccion': jsonResponse['resultado'],
          'confianza': jsonResponse['confianza']
        };
      } else {
        throw Exception("Error en el servidor: ${response.statusCode}");
      }
    } catch (e) {
      return {
        'prediccion': 'Error al diagnosticar',
        'confianza': 0.0,
        'error': e.toString(),
      };
    }
  }
}
