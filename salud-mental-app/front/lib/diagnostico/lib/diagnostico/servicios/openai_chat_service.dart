import 'dart:convert';
import 'package:http/http.dart' as http;

class OpenAIChatService {
  final String apiKey = 'TU_API_KEY_DE_OPENAI';

  Future<String> enviarMensaje(String mensaje) async {
    const url = 'https://api.openai.com/v1/chat/completions';

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'gpt-3.5-turbo',
        'messages': [
          {
            "role": "system",
            "content": "Eres un asistente médico que responde claro y empático."
          },
          {"role": "user", "content": mensaje},
        ],
        'max_tokens': 300,
        'temperature': 0.7,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'];
    } else {
      return 'Error al contactar OpenAI: ${response.body}';
    }
  }
}
