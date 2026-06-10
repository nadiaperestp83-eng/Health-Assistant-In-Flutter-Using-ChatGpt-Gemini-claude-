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

      final config = OfflineTtsConfig(
        model: OfflineTtsModelConfig(
          vits: OfflineTtsVitsModelConfig(
            model: modelPath,
            lexicon: '',
            tokens: tokensPath,
            dataDir: '',
            noiseScale: 0.667,
            noiseScaleW: 0.8,
            lengthScale: 1.0,
          ),
          numThreads: 2,
          debug: false,
          provider: 'cpu',
        ),
        ruleFsts: '',
      );

      await SherpaOnnx.initOfflineTts(config);
      _tts = SherpaOnnx.offlineTts;
      _inicializado = true;
      print('✅ Piper Cadu inicializado');
    } catch (e) {
      _inicializado = false;
      print('❌ Piper erro: $e');
      rethrow;
    }
  }

  Future<void> _copiarModeloGrande(String destino) async {
    if (await File(destino).exists()) return;
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

    final audio = _tts!.generate(text: texto, sid: 0, speed: 1.0);
    if (audio.samples.isEmpty) throw Exception('Áudio vazio');

    final tmpDir = await getTemporaryDirectory();
    final arquivo = File(p.join(tmpDir.path, 'piper_${DateTime.now().millisecondsSinceEpoch}.wav'));
    await _salvarWav(arquivo, audio.samples, audio.sampleRate);
    return arquivo.path;
  }

  Future<void> _salvarWav(File arquivo, List<double> samples, int sampleRate) async {
    final pcm = _floatParaPcm16(samples);
    final wav = _montarWav(pcm, sampleRate);
    await arquivo.writeAsBytes(wav);
  }

  List<int> _floatParaPcm16(List<double> samples) {
    final out = <int>[];
    for (final s in samples) {
      int v = (s * 32767).round();
      v = v.clamp(-32768, 32767);
      out.add(v & 0xFF);
      out.add((v >> 8) & 0xFF);
    }
    return out;
  }

  List<int> _montarWav(List<int> pcm, int sampleRate) {
    final buf = <int>[];
    void w32(int v) => buf.addAll([v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF]);
    void w16(int v) => buf.addAll([v & 0xFF, (v >> 8) & 0xFF]);
    void str(String s) => buf.addAll(s.codeUnits);
    
    str('RIFF'); w32(36 + pcm.length);
    str('WAVE');
    str('fmt '); w32(16);
    w16(1); w16(1);
    w32(sampleRate); w32(sampleRate * 2);
    w16(2); w16(16);
    str('data'); w32(pcm.length);
    buf.addAll(pcm);
    return buf;
  }

  void dispose() {
    _tts = null;
    _inicializado = false;
    _player.dispose();
  }
}
