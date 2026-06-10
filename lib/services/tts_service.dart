import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:typed_data';


class TtsService {
  static TtsService? _instance;
  static TtsService get instance => _instance ??= TtsService._();
  TtsService._();

  OfflineTts? _tts;
  final AudioPlayer _player = AudioPlayer();
  bool _inicializado = false;

  static const _modelAsset = 'assets/voices/pt_BR-cadu-medium.onnx';
  static const _tokensAsset = 'assets/voices/tokens.txt';

  Future<void> inicializar() async {
    if (_inicializado) return;

    try {
      final dir = await getApplicationSupportDirectory();
      final modelPath = p.join(dir.path, 'pt_BR-cadu-medium.onnx');
      final tokensPath = p.join(dir.path, 'tokens.txt');

      await _copiarArquivo(_modelAsset, modelPath);
      await _copiarArquivo(_tokensAsset, tokensPath);

      // API CORRETA do sherpa_onnx
      _tts = OfflineTts(
        modelPath: modelPath,
        tokensPath: tokensPath,
        numThreads: 2,
      );
      
      _inicializado = true;
      print('✅ Piper Cadu inicializado');
    } catch (e) {
      _inicializado = false;
      print('❌ Piper erro: $e');
      rethrow;
    }
  }

  Future<void> _copiarArquivo(String assetPath, String destino) async {
    if (await File(destino).exists()) return;
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    await File(destino).writeAsBytes(bytes);
  }

  Future<String> gerarAudio(String texto) async {
    if (!_inicializado) await inicializar();
    if (_tts == null) throw Exception('TTS não inicializado');

    // API CORRETA para gerar áudio
    final samples = _tts!.generate(texto);
    
    if (samples.isEmpty) throw Exception('Áudio vazio');

    final tmpDir = await getTemporaryDirectory();
    final arquivo = File(p.join(tmpDir.path, 'piper_${DateTime.now().millisecondsSinceEpoch}.wav'));
    
    // Converte samples para WAV
    await _salvarWav(arquivo, samples, 16000);
    return arquivo.path;
  }

  Future<void> _salvarWav(File arquivo, List<double> samples, int sampleRate) async {
    final buffer = ByteData();
    // Converte float para PCM16
    for (final s in samples) {
      final intVal = (s * 32767).round().clamp(-32768, 32767);
      buffer.putInt16(intVal, Endian.little);
    }
    await arquivo.writeAsBytes(buffer.buffer.asUint8List());
  }

  void dispose() {
    _tts = null;
    _inicializado = false;
    _player.dispose();
  }
}
