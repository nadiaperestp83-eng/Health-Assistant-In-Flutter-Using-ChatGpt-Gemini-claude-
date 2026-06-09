import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ai_assistant/helper/global.dart';

class ElevenLabsService {
  static const String _voiceId = '4za2kOXGgUd57HRSQ1fn';

  static Future<List<int>?> sintetizar(String text) async {
    final String key = elevenlabsKey.trim();
    if (key.isEmpty) return null;

    try {
      final response = await http.post(
        Uri.parse('https://api.elevenlabs.io/v1/text-to-speech/$_voiceId'),
        headers: {
          'accept': 'audio/mpeg',
          'xi-api-key': key,
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

      if (response.statusCode == 200) return response.bodyBytes;
      return null;
    } catch (e) {
      return null;
    }
  }
}
