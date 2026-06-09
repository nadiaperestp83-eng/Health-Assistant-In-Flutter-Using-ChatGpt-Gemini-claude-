import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

import 'helper/global.dart';

class ElevenLabsService {
  static const String _voiceId = 'YyqkX0AHv8W5D1vxG9lR';

  static Future<Uint8List?> sintetizar(String text) async {
    final String key = elevenlabsKey.trim();
    
    if (key.isEmpty) {
      log('ElevenLabs: chave vazia');
      return null;
    }

    try {
      final response = await http.post(
        Uri.parse('https://api.elevenlabs.io/v1/text-to-speech/$_voiceId'),
        headers: {
          'Content-Type': 'application/json',
          'xi-api-key': key,
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
        log('ElevenLabs: áudio recebido (${response.bodyBytes.length} bytes)');
        return response.bodyBytes;
      } else {
        log('ElevenLabs erro ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e) {
      log('ElevenLabs exceção: $e');
      return null;
    }
  }
}
