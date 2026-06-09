import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import 'helper/global.dart';

class ElevenLabsService {
  static const String _baseUrl = 'https://api.elevenlabs.io/v1/text-to-speech';
  static const String _voiceId = 'YyqkX0AHv8W5D1vxG9lR'; // sua voice ID

  static Future<Uint8List?> textToSpeech(String text) async {
    final String apiKey = elevenlabsKey.trim();
    
    if (apiKey.isEmpty) {
      debugPrint('❌ ElevenLabs: API Key vazia');
      return null;
    }

    final url = '$_baseUrl/$_voiceId';
    final headers = {
      'Content-Type': 'application/json',
      'xi-api-key': apiKey,
    };

    final body = jsonEncode({
      'text': text,
      'model_id': 'eleven_multilingual_v2',
      'voice_settings': {
        'stability': 0.5,
        'similarity_boost': 0.5,
      },
    });

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        debugPrint('✅ ElevenLabs: Audio gerado com sucesso');
        return response.bodyBytes;
      } else {
        debugPrint('❌ ElevenLabs Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ ElevenLabs Exception: $e');
      return null;
    }
  }
}
