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

      // CORREÇÃO: Usando os parâmetros esperados pela versão 1.13.2
      final config = OfflineTtsConfig(
        model: OfflineModelConfig(model: modelPath), // Ajustado de modelPath para model
        tokens: tokensPath,
      );
      
      _tts = OfflineTts(config);
      
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

    // Em muitas versões, o generate retorna a lista de samples diretamente ou um objeto.
    // Se ainda der erro aqui, tente: _tts!.generate(text: texto).samples
    final samples = _tts!.generate(text: texto);
    
    if (samples.isEmpty) throw Exception('Áudio vazio');

    final tmpDir = await getTemporaryDirectory();
    final arquivo = File(p.join(tmpDir.path, 'piper_${DateTime.now().millisecondsSinceEpoch}.wav'));
    
    await _salvarWav(arquivo, samples);
    return arquivo.path;
  }

  Future<void> _salvarWav(File arquivo, List<double> samples) async {
    final buffer = ByteData(samples.length * 2);
    for (int i = 0; i < samples.length; i++) {
      final intVal = (samples[i] * 32767).round().clamp(-32768, 32767);
      buffer.setInt16(i * 2, intVal, Endian.little);
    }
    await arquivo.writeAsBytes(buffer.buffer.asUint8List());
  }

  void dispose() {
    // CORREÇÃO: A classe OfflineTts na sua versão não possui dispose() público.
    // Basta apenas anular a referência.
    _tts = null; 
    _inicializado = false;
    _player.dispose();
  }
}
