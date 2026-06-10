import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'helper/global.dart';

class ElevenLabsService {
  static const String _voiceId = '4za2kOXGgUd57HRSQ1fn';

  static Future<Uint8List?> textToSpeech(String text) async {
    final String key = elevenlabsKey.trim();
    if (key.isEmpty) return null;

    try {
      final response = await http.post(
        Uri.parse('https://api.elevenlabs.io/v1/text-to-speech/$_voiceId'),
        headers: {
          'Content-Type': 'application/json',
          'xi-api-key': key,
        },
        body: jsonEncode({
          'text': text,
          'model_id': 'eleven_monolingual_v1',
          'voice_settings': {
            'stability': 0.6,
            'similarity_boost': 0.75,
          }
        }),
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
