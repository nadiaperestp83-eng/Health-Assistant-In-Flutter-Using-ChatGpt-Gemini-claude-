import 'dart:developer';
import 'dart:typed_data';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'helper/global.dart';

class ElevenLabsService {
  static const _voiceId = 'YyqkX0AHv8W5D1vxG9lR';

  static Future<Uint8List?> sintetizar(String texto) async {
    final key = elevenlabsKey.trim();

    print('=== DIAGNÓSTICO ELEVENLABS ===');
    print('Chave vazia? ${key.isEmpty}');
    print('Tamanho: ${key.length}');
    if (key.length >= 4) {
      print('Prefixo: ${key.substring(0, 4)}');
      print('Sufixo: ${key.substring(key.length - 4)}');
    }
    print('Texto a sintetizar: "$texto"');
    print('==============================');

    if (key.isEmpty) {
      log('❌ Chave ElevenLabs vazia — fallback nativo');
      return null;
    }

    try {
      final body = jsonEncode({
        'text': texto,
        'model_id': 'eleven_multilingual_v2',
        'output_format': 'mp3_44100_128',
        'voice_settings': {
          'stability': 0.45,
          'similarity_boost': 0.80,
          'style': 0.0,
          'use_speaker_boost': true,
        }
      });

      final res = await http.post(
        Uri.parse(
            'https://api.elevenlabs.io/v1/text-to-speech/$_voiceId'),
        headers: {
          'xi-api-key': key,
          'Content-Type': 'application/json',
          'Accept': 'audio/mpeg',
        },
        body: body,
      );

      print('[EL] Status: ${res.statusCode}');

      if (res.statusCode == 200) {
        print('[EL] ✅ Áudio recebido — ${res.bodyBytes.length} bytes');
        return res.bodyBytes;
      }
      if (res.statusCode == 401) {
        log('ElevenLabs: ❌ Chave inválida (401) — ${res.body}');
        return null;
      }
      if (res.statusCode == 429) {
        log('ElevenLabs: cota atingida (429) — fallback nativo');
        return null;
      }

      log('ElevenLabs erro: ${res.statusCode} — ${res.body}');
      return null;
    } catch (e) {
      log('ElevenLabsE: $e');
      return null;
    }
  }
}
