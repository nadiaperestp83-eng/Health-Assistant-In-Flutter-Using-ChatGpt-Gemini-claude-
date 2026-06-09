import 'dart:developer';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

import 'helper/global.dart';

class ElevenLabsService {
  static const _voiceId = '6fZce9LFNG3iEITDfqZZ';

  static Future<Uint8List?> sintetizar(String texto) async {
    try {
      final res = await http.post(
        Uri.parse('https://api.elevenlabs.io/v1/text-to-speech/$_voiceId'),
        headers: {
          'xi-api-key': elevenlabsKey,
          'Content-Type': 'application/json',
        },
        body: '{'
            '"text":"${texto.replaceAll('"', '\\"')}",'
            '"model_id":"eleven_multilingual_v2",'
            '"voice_settings":{'
            '"stability":0.45,'
            '"similarity_boost":0.80,'
            '"style":0.0,'
            '"use_speaker_boost":true'
            '}'
            '}',
      );
      if (res.statusCode == 200) return res.bodyBytes;
      if (res.statusCode == 429) {
        log('ElevenLabs: cota atingida (429) — usando fallback nativo');
        return null;
      }
      log('ElevenLabs erro: ${res.statusCode} ${res.body}');
      return null;
    } catch (e) {
      log('ElevenLabsE: $e');
      return null;
    }
  }
}
