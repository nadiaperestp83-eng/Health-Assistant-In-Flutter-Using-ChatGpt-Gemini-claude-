import 'dart:developer';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

import 'helper/global.dart';

class ElevenLabsService {
  static const _voiceId = 'YyqkX0AHv8W5D1vxG9lR'; // ← voz atualizada

  static Future<Uint8List?> sintetizar(String texto) async {
    // ===== LOGS DE DIAGNÓSTICO =====
    final key = elevenlabsKey.trim(); // Remove espaços/linhas extras
    print('=== DIAGNÓSTICO ELEVENLABS ===');
    print('Chave está vazia? ${key.isEmpty}');
    print('Tamanho da chave: ${key.length}');
    if (key.length >= 4) {
      print('Primeiros 4 caracteres: ${key.substring(0, 4)}');
      print('Últimos 4 caracteres: ${key.substring(key.length - 4)}');
    } else if (key.isNotEmpty) {
      print('Chave muito curta: "$key"');
    }
    print('Primeiro caractere (ASCII): ${key.isNotEmpty ? key.codeUnitAt(0) : "N/A"}');
    print('===============================');
    
    if (key.isEmpty) {
      print('❌ Chave ElevenLabs vazia - usando fallback nativo');
      return null;
    }
    // ===== FIM DOS LOGS =====
    
    try {
      final res = await http.post(
        Uri.parse('https://api.elevenlabs.io/v1/text-to-speech/$_voiceId'),
        headers: {
          'xi-api-key': key, // Usar a chave com trim
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
