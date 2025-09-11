import 'dart:convert';
import 'dart:typed_data';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import '../components/navbar.dart';

class SeguimientoPage extends StatefulWidget {
  const SeguimientoPage({Key? key}) : super(key: key);

  @override
  _SeguimientoPageState createState() => _SeguimientoPageState();
}

class _SeguimientoPageState extends State<SeguimientoPage> {
  bool _listening = false;
  final TextEditingController _messageController = TextEditingController();
  final FlutterTts flutterTts = FlutterTts();

  void _toggleListening() {
    setState(() => _listening = !_listening);
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
              onPressed: () => Navigator.pop(context), child: const Text('OK')),
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
        final completo = 'Pasos:\n• $pasos\n\nIA: $ia';
        _mostrarDialogoResultado('🩺 Primeros Auxilios', completo);
      } else {
        _mostrarDialogoResultado(
            'Error', 'El servidor respondió con: ${response.statusCode}');
      }
    } catch (e) {
      _mostrarDialogoResultado('Error', 'Fallo la conexión: $e');
    }
  }

  Future<void> subirImagenParaPrediccion(
      Uint8List bytes, String fileName) async {
    final url = Uri.parse('http://127.0.0.1:8000/predict');

    final request = http.MultipartRequest('POST', url);
    request.files
        .add(http.MultipartFile.fromBytes('image', bytes, filename: fileName));

    try {
      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final decoded = jsonDecode(responseData);

      final clase = decoded['mejor_prediccion']['clase'];
      final confianza = decoded['mejor_prediccion']['confianza'];
      final texto =
          '🧠 Diagnóstico: $clase\n📊 Confianza: ${(confianza * 100).toStringAsFixed(2)}%\nConsulta a un médico.';

      _mostrarDialogoResultado('Resultado del análisis', texto);
    } catch (e) {
      _mostrarDialogoResultado('Error', 'No se pudo procesar la imagen: $e');
    }
  }

  void _subirArchivo() {
    final uploadInput = html.FileUploadInputElement()
      ..accept = '.pdf,image/*'
      ..click();

    uploadInput.onChange.listen((event) {
      final file = uploadInput.files?.first;
      if (file == null) return;

      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);

      reader.onLoadEnd.listen((event) {
        final bytes = reader.result as Uint8List;
        final extension = file.name.split('.').last.toLowerCase();

        if (['png', 'jpg', 'jpeg'].contains(extension)) {
          subirImagenParaPrediccion(bytes, file.name);
        } else if (extension == 'pdf') {
          _mostrarDialogoResultado('Archivo PDF recibido',
              'Se ha subido el archivo "${file.name}" correctamente.');
          // Puedes agregar lógica para subir PDFs aquí
        } else {
          _mostrarDialogoResultado(
              'Error', 'Formato no permitido: .$extension');
        }
      });
    });
  }

  Future<void> _hablar(String texto) async {
    await flutterTts.setLanguage("es-MX");
    await flutterTts.setPitch(1.0);
    await flutterTts.setSpeechRate(0.4);
    await flutterTts.speak(texto);
  }

  void _mostrarDialogoResultado(String titulo, String mensaje) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titulo),
        content: SingleChildScrollView(child: Text(mensaje)),
        actions: [
          ElevatedButton.icon(
            onPressed: () => _hablar(mensaje),
            icon: const Icon(Icons.volume_up),
            label: const Text("Escuchar"),
          ),
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
            Image.asset('assets/imagenes/logohorizontal.png',
                height: 50, fit: BoxFit.contain),
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
                  color: Color(0xFF3C6043)),
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
                    borderSide: BorderSide.none),
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
              onTap: _subirArchivo,
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
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.upload_file, size: 50, color: Color(0xFF72C7D3)),
                    SizedBox(height: 10),
                    Text(
                      'SUBE PDF O IMAGEN',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey),
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
                    icon: Icons.upload_file,
                    color: const Color(0xFF3C6043),
                    onPressed: _subirArchivo,
                    label: 'Archivo',
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
            icon: Icon(icon, size: 28), color: color, onPressed: onPressed),
        Text(label,
            style: TextStyle(
                fontSize: 12, color: color, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
