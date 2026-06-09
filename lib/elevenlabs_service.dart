import 'dart:developer';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'helper/global.dart';

class ElevenLabsService {
  static const _voiceId = 'YyqkX0AHv8W5D1vxG9lR';

  static Future<String?> sintetizar(String texto) async {
    final key = elevenlabsKey.trim();
    if (key.isEmpty) return null;

    try {
      final res = await http.post(
        Uri.parse('https://api.elevenlabs.io/v1/text-to-speech/$_voiceId'),
        headers: {
          'xi-api-key': key,
          'Content-Type': 'application/json',
          'Accept': 'audio/mpeg',
        },
        body: jsonEncode({
          'text': texto,
          'model_id': 'eleven_multilingual_v2',
          'voice_settings': {
            'stability': 0.45,
            'similarity_boost': 0.80,
            'style': 0.0,
            'use_speaker_boost': true,
          }
        }),
      );

      log('[EL] status: ${res.statusCode}');

      if (res.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/el_tts.mp3');
        await file.writeAsBytes(res.bodyBytes);
        log('[EL] arquivo salvo: ${file.path}');
        return file.path;
      }

      log('[EL] erro: ${res.statusCode} ${res.body}');
      return null;
    } catch (e) {
      log('[EL] exception: $e');
      return null;
    }
  }
}
