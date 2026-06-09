import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'helper/global.dart';

class ElevenLabsService {
  static const String _voiceId = '4za2kOXGgUd57HRSQ1fn';

  static Future<String?> sintetizar(String text) async {
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
          'model_id': 'eleven_multilingual_v2', // ← corrigido
          'voice_settings': {
            'stability': 0.45,
            'similarity_boost': 0.80,
          }
        }),
      );

      if (response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/tts_output.mp3');
        await file.writeAsBytes(response.bodyBytes);
        return file.path;
      }

      // Log do erro para debug
      print('ElevenLabs erro ${response.statusCode}: ${response.body}');
      return null;
    } catch (e) {
      print('ElevenLabs exception: $e');
      return null;
    }
  }
}
