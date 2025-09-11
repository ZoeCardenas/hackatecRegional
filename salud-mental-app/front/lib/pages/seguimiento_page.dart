import 'dart:convert';
import 'dart:typed_data';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../components/navbar.dart';

class SeguimientoPage extends StatefulWidget {
  const SeguimientoPage({super.key});

  @override
  _SeguimientoPageState createState() => _SeguimientoPageState();
}

class _SeguimientoPageState extends State<SeguimientoPage> {
  bool _listening = false;
  final TextEditingController _messageController = TextEditingController();

  void _toggleListening() {
    setState(() {
      _listening = !_listening;
    });
  }

  void _sendSOS() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alerta de emergencia'),
        content: const Text(
            'Se ha enviado tu ubicación a los contactos de emergencia'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> enviarMensajeAlChat(String mensaje) async {
    final url = Uri.parse('http://127.0.0.1:8000/chat/chat');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'message': mensaje}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final pasos = data['first_aid_steps'].join('\n• ');
        final ia = data['assist_response'];

        _mostrarDialogoResultado(
            '🩺 Primeros Auxilios', '• $pasos\n\n🤖 IA: $ia');
      } else {
        _mostrarDialogoResultado(
            'Error', 'El servidor respondió con: ${response.statusCode}');
      }
    } catch (e) {
      _mostrarDialogoResultado('Error', 'Fallo la conexión: $e');
    }
  }

  Future<void> subirImagenParaPrediccion(Uint8List imagenBytes) async {
    final url = Uri.parse('http://127.0.0.1:8000/predict');

    try {
      final request = http.MultipartRequest('POST', url);
      request.files.add(http.MultipartFile.fromBytes(
        'image',
        imagenBytes,
        filename: 'foto.png',
      ));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        final clase = decoded['mejor_prediccion']['clase'];
        final confianza = decoded['mejor_prediccion']['confianza'];
        final nota = decoded['nota'];

        _mostrarDialogoResultado(
          'Resultado del análisis',
          '🧠 Clase: $clase\n📊 Confianza: $confianza%\n\n🔔 Nota:\n$nota',
        );
      } else {
        _mostrarDialogoResultado(
            'Error', 'El servidor respondió con: ${response.statusCode}');
      }
    } catch (e) {
      _mostrarDialogoResultado('Error', 'No se pudo procesar la imagen: $e');
    }
  }

  void _subirFotoDesdeSistema() {
    final uploadInput = html.FileUploadInputElement()
      ..accept = 'image/*'
      ..click();

    uploadInput.onChange.listen((event) {
      final file = uploadInput.files?.first;
      if (file == null) return;

      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      reader.onLoadEnd.listen((_) {
        final bytes = reader.result as Uint8List;
        subirImagenParaPrediccion(bytes);
      });
    });
  }

  void _mostrarDialogoResultado(String titulo, String mensaje) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titulo),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
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
        backgroundColor: const Color.fromARGB(255, 102, 146, 111),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Image.asset(
              'assets/imagenes/logohorizontal.png',
              height: 50,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 10),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Text(
              '¿En qué puedo ayudarte?',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Color(0xFF3C6043),
              ),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Describe tu situación...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(16),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send, color: Color(0xFF72C7D3)),
                  onPressed: () {
                    final msg = _messageController.text.trim();
                    if (msg.isNotEmpty) {
                      enviarMensajeAlChat(msg);
                      _messageController.clear();
                    }
                  },
                ),
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 30),
            GestureDetector(
              onTap: _subirFotoDesdeSistema,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF72C7D3), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_upload,
                        size: 50, color: Color(0xFF72C7D3)),
                    const SizedBox(height: 10),
                    Text(
                      'SUBE TU FOTO\nA ANALIZAR',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 2,
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(
                    icon: _listening ? Icons.mic_off : Icons.mic,
                    color: _listening ? Colors.red : const Color(0xFF3C6043),
                    onPressed: _toggleListening,
                    label: _listening ? 'Detener' : 'Grabar',
                  ),
                  _buildActionButton(
                    icon: Icons.camera_alt,
                    color: const Color(0xFF3C6043),
                    onPressed: _subirFotoDesdeSistema,
                    label: 'Cargar',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(icon, size: 28),
          color: color,
          onPressed: onPressed,
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
