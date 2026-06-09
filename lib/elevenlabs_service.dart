import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import 'helper/global.dart';

class ElevenLabsService {
  static Future<Uint8List?> textToSpeech(String text) async {
    final String apiKey = elevenlabsKey.trim();
    
    if (apiKey.isEmpty) {
      debugPrint('❌ ElevenLabs: API Key não configurada');
      return null;
    }

    const String voiceId = 'YyqkX0AHv8W5D1vxG9lR';
    final String url = 'https://api.elevenlabs.io/v1/text-to-speech/$voiceId';

    final headers = {
      'Content-Type': 'application/json',
      'xi-api-key': apiKey,
    };

    final body = jsonEncode({
      'text': text,
      'model_id': 'eleven_monolingual_v1',
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
        debugPrint('✅ ElevenLabs: Áudio gerado com sucesso');
        return response.bodyBytes;
      } else {
        debugPrint('❌ ElevenLabs Erro ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ ElevenLabs Exceção: $e');
      return null;
    }
  }
}
