import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiVoiceService {
  final GenerativeModel model = GenerativeModel(
    model: 'gemini-pro',
    apiKey: 'AIzaSyDIUpEMTOMWI-x8Gz85DJstHrPULUEKK0A',
  );

  Future<String> obtenerRespuesta(String input) async {
    final prompt = [Content.text(input)];
    final response = await model.generateContent(prompt);
    return response.text ?? 'Sin respuesta';
  }
}
