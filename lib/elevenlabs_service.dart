import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'helper/global.dart';

class ElevenLabsService {
  // ID da voz definido conforme o seu requisito
  static const String _voiceId = 'YyqkX0AHv8W5D1vxG9lR';

  static Future<Uint8List?> sintetizar(String text) async {
    final url = Uri.parse('https://api.elevenlabs.io/v1/text-to-speech/$_voiceId');

    final response = await http.post(
      url,
      headers: {
        'accept': 'audio/mpeg',
        'xi-api-key': elevenlabsKey.trim(),
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'text': text,
        'model_id': 'eleven_multilingual_v2',
        'voice_settings': {
          'stability': 0.45,
          'similarity_boost': 0.80,
        }
      }),
    );

    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      // Retorna nulo para indicar falha na obtenção dos bytes
      return null;
    }
  }
}
