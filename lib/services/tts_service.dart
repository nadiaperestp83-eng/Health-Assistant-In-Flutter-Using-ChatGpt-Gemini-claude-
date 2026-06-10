// lib/services/tts_service.dart

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

  static const _modelAsset  = 'assets/voices/pt_BR-cadu-medium.onnx';
  static const _configAsset = 'assets/voices/pt_BR-cadu-medium.onnx.json';
  static const _tokensAsset = 'assets/voices/tokens.txt';

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

      // Copia assets → armazenamento interno na primeira execução
      await _copiarAsset(_modelAsset,  modelPath);
      await _copiarAsset(_configAsset, configPath);
      await _copiarAsset(_tokensAsset, tokensPath);

      final config = OfflineTtsConfig(
        model: OfflineTtsModelConfig(
          vits: OfflineTtsVitsModelConfig(
            model: modelPath,
            lexicon: '',
            tokens: tokensPath,
            dataDir: '',          // espeak não é necessário para pt_BR-cadu
            noiseScale: 0.667,
            noiseScaleW: 0.8,
            lengthScale: 1.0,
          ),
          numThreads: 2,
          debug: false,
          provider: 'cpu',
        ),
        ruleFsts: '',
        maxNumSentences: 1,
      );

      _tts = OfflineTts(config);
      _inicializado = true;
    } catch (e) {
      _inicializado = false;
      throw Exception('❌ TtsService.inicializar falhou: $e');
    }
  }

  Future<void> falar(String texto) async {
    if (!_inicializado) await inicializar();

    try {
      await _player.stop();

      final audio = _tts!.generate(
        text: texto,
        sid: 0,
        speed: 1.0,
      );

      if (audio.samples.isEmpty) {
        throw Exception('modelo retornou áudio vazio');
      }

      final tmpDir  = await getTemporaryDirectory();
      final arquivo = File(p.join(tmpDir.path, 'cadu_tts.wav'));
      await _salvarWav(arquivo, audio.samples, audio.sampleRate);

      await _player.setFilePath(arquivo.path);
      await _player.play();

      // Aguarda a reprodução terminar
      await _player.processingStateStream.firstWhere(
        (s) => s == ProcessingState.completed,
      );

      await arquivo.delete();
    } catch (e) {
      throw Exception('❌ TtsService.falar falhou: $e');
    }
  }

  Future<void> parar() async => _player.stop();

  void dispose() {
    _tts?.free();
    _player.dispose();
    _inicializado = false;
    _tts = null;
  }

  // ── helpers ────────────────────────────────────────────────

  Future<void> _copiarAsset(String assetPath, String destino) async {
    if (await File(destino).exists()) return;
    final data  = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    await File(destino).writeAsBytes(bytes, flush: true);
  }

  Future<void> _salvarWav(
    File arquivo,
    List<double> samples,
    int sampleRate,
  ) async {
    final pcm     = _floatParaPcm16(samples);
    final wavData = _montarCabecalhoWav(pcm, sampleRate);
    await arquivo.writeAsBytes(wavData, flush: true);
  }

  List<int> _floatParaPcm16(List<double> samples) {
    final out = <int>[];
    for (final s in samples) {
      final v = (s * 32767.0).round().clamp(-32768, 32767);
      out.add(v & 0xFF);
      out.add((v >> 8) & 0xFF);
    }
    return out;
  }

  List<int> _montarCabecalhoWav(List<int> pcm, int sampleRate) {
    final dataSize = pcm.length;
    final buf = <int>[];

    void w32(int v) => buf.addAll([
      v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF,
    ]);
    void w16(int v) => buf.addAll([v & 0xFF, (v >> 8) & 0xFF]);
    void str(String s) => buf.addAll(s.codeUnits);

    str('RIFF');  w32(36 + dataSize);
    str('WAVE');
    str('fmt ');  w32(16);
    w16(1);           // PCM
    w16(1);           // mono
    w32(sampleRate);
    w32(sampleRate * 2); // byteRate
    w16(2);           // blockAlign
    w16(16);          // bitsPerSample
    str('data');  w32(dataSize);
    buf.addAll(pcm);

    return buf;
  }
}
