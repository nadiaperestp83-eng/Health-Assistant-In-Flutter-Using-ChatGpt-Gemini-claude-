import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';
import 'package:just_audio/just_audio.dart';

class TtsService {
  static TtsService? _instance;
  static TtsService get instance => _instance ??= TtsService._();
  TtsService._();

  OfflineTts? _tts;
  final AudioPlayer _player = AudioPlayer();
  bool _inicializado = false;

  static const _configAsset = 'assets/voices/pt_BR-cadu-medium.onnx.json';
  static const _tokensAsset = 'assets/voices/tokens.txt';
  static const _modelAsset = 'assets/voices/pt_BR-cadu-medium.onnx';

  static const _modelFile   = 'pt_BR-cadu-medium.onnx';
  static const _configFile  = 'pt_BR-cadu-medium.onnx.json';
  static const _tokensFile  = 'tokens.txt';

  Future<void> inicializar() async {
    if (_inicializado) return;

    try {
      final dir = await getApplicationSupportDirectory();
      final modelPath  = p.join(dir.path, _modelFile);
      final configPath = p.join(dir.path, _configFile);
      final tokensPath = p.join(dir.path, _tokensFile);

      await _copiarAsset(_configAsset, configPath);
      await _copiarAsset(_tokensAsset, tokensPath);
      await _copiarModeloGrande(modelPath);

      // Leitura do arquivo de configuração
      final configJson = await File(configPath).readAsString();
      
      final config = OfflineTtsConfig.fromJson(configJson);
      
      _tts = await OfflineTts.create(config);
      _inicializado = true;
      print('✅ Piper Cadu inicializado');
    } catch (e) {
      _inicializado = false;
      print('❌ Piper erro: $e');
      rethrow;
    }
  }

  Future<void> _copiarModeloGrande(String destino) async {
    if (await File(destino).exists()) {
      final size = await File(destino).length();
      if (size > 1000000) return;
    }
    final ByteData data = await rootBundle.load(_modelAsset);
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    await File(destino).writeAsBytes(bytes);
  }

  Future<void> _copiarAsset(String assetPath, String destino) async {
    if (await File(destino).exists()) return;
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    await File(destino).writeAsBytes(bytes);
  }

  Future<String> gerarAudio(String texto) async {
    if (!_inicializado) await inicializar();
    if (_tts == null) throw Exception('TTS não inicializado');

    final audio = await _tts!.generate(texto);
    if (audio == null || audio.isEmpty) throw Exception('Áudio vazio');

    final tmpDir = await getTemporaryDirectory();
    final arquivo = File(p.join(tmpDir.path, 'piper_${DateTime.now().millisecondsSinceEpoch}.wav'));
    await arquivo.writeAsBytes(audio);
    return arquivo.path;
  }

  void dispose() {
    _tts?.close();
    _tts = null;
    _inicializado = false;
    _player.dispose();
  }
}
