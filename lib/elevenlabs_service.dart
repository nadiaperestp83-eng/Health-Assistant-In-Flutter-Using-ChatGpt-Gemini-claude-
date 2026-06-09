import 'package:elevenlabs_flutter/elevenlabs_flutter.dart';
import 'package:ai_assistant/helper/global.dart';

class ElevenLabsService {
  static const String _voiceId = '4za2kOXGgUd57HRSQ1fn';

  static final _api = ElevenLabsAPI();
  static bool _initialized = false;

  static Future<void> _init() async {
    if (_initialized) return;
    await _api.init(
      baseUrl: 'https://api.elevenlabs.io',
      apiKey: elevenlabsKey.trim(),
    );
    _initialized = true;
  }

  static Future<List<int>?> sintetizar(String text) async {
    try {
      await _init();
      final result = await _api.synthesize(
        TextToSpeechRequest(
          text: text,
          voiceId: _voiceId,
          modelId: 'eleven_multilingual_v2',
          voiceSettings: VoiceSettings(
            stability: 0.45,
            similarityBoost: 0.80,
          ),
        ),
      );
      return result;
    } catch (e) {
      print('ElevenLabs erro: $e');
      return null;
    }
  }
}
