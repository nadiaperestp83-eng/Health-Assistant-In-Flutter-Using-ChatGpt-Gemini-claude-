import 'dart:typed_data';
import 'package:http/http.dart' as http;

class ElevenLabsService {
  // A chave é injetada via --dart-define no build ou via um provider de configuração
  static const String _apiKey = String.fromEnvironment('ELEVENLABS_API_KEY');
  static const String _voiceId = '6fZce9LFNG3iEITDfqZZ'; 

  static Future<Uint8List?> sintetizar(String texto) async {
    if (_apiKey.isEmpty) {
      print("Erro: Chave da API ElevenLabs não encontrada.");
      return null;
    }

    final url = Uri.parse('https://api.elevenlabs.io/v1/text-to-speech/$_voiceId');
    
    try {
      final response = await http.post(
        url,
        headers: {
          'xi-api-key': _apiKey,
          'Content-Type': 'application/json',
          'accept': 'audio/mpeg',
        },
        body: '''{
          "text": "$texto",
          "model_id": "eleven_multilingual_v2",
          "voice_settings": {
            "stability": 0.5,
            "similarity_boost": 0.75
          }
        }''',
      );

      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
