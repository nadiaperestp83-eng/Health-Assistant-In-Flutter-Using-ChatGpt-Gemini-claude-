import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;
import 'package:just_audio/just_audio.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  static TtsService get instance => _instance;
  TtsService._internal();

  sherpa_onnx.OfflineTts? _piperTts;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _flutterTts = FlutterTts();
  bool _piperDisponivel = false;

  Future<void> inicializar() async {
    try {
      sherpa_onnx.initBindings();

      final dir = await getApplicationSupportDirectory();
      final voicesDir = '${dir.path}/voices';
      await Directory(voicesDir).create(recursive: true);

      final modelPath = '$voicesDir/pt_BR-cadu-medium.onnx';
      final dataDirPath = '$voicesDir/espeak-ng-data';

      if (!File(modelPath).existsSync()) {
        await _copiarAsset(
            'assets/voices/pt_BR-cadu-medium.onnx', modelPath);
      }
      if (!File('$voicesDir/pt_BR-cadu-medium.onnx.json').existsSync()) {
        await _copiarAsset(
            'assets/voices/pt_BR-cadu-medium.onnx.json',
            '$voicesDir/pt_BR-cadu-medium.onnx.json');
      }
      if (!File('$voicesDir/tokens.txt').existsSync()) {
        await _copiarAsset(
            'assets/voices/tokens.txt', '$voicesDir/tokens.txt');
      }
      if (!Directory(dataDirPath).existsSync()) {
        await _copiarEspeakData(dataDirPath);
      }

      final config = sherpa_onnx.OfflineTtsConfig(
        model: sherpa_onnx.OfflineTtsModelConfig(
          vits: sherpa_onnx.OfflineTtsVitsModelConfig(
            model: modelPath,
            lexicon: '',
            tokens: '$voicesDir/tokens.txt',
            dataDir: dataDirPath,
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

      _piperTts = sherpa_onnx.OfflineTts(config);
      _piperDisponivel = true;
      print('✅ Piper Cadu inicializado com sucesso');
    } catch (e) {
      print('⚠️ Piper indisponível: $e');
      _piperDisponivel = false;
    }

    await _flutterTts.setLanguage('pt-BR');
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  Future<void> _copiarAsset(String assetPath, String destino) async {
    final byteData = await rootBundle.load(assetPath);
    final buffer = byteData.buffer;
    final file = File(destino);
    await file.parent.create(recursive: true);
    const chunkSize = 4 * 1024 * 1024;
    int offset = 0;
    final sink = file.openWrite();
    while (offset < buffer.lengthInBytes) {
      final end = (offset + chunkSize).clamp(0, buffer.lengthInBytes);
      sink.add(Uint8List.view(buffer, offset, end - offset));
      offset = end;
    }
    await sink.close();
  }

  Future<void> _copiarEspeakData(String destDirPath) async {
    // Listar e copiar todos os arquivos do espeak-ng-data via AssetManifest
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final keys = manifest.listAssets().where(
        (k) => k.startsWith('assets/voices/espeak-ng-data/'));
    for (final key in keys) {
      final relative = key.replaceFirst('assets/voices/espeak-ng-data/', '');
      final destFile = '$destDirPath/$relative';
      await _copiarAsset(key, destFile);
    }
    print('✅ espeak-ng-data copiado: ${keys.length} arquivos');
  }

  Future<String> gerarAudio(String texto) async {
    if (!_piperDisponivel || _piperTts == null) {
      throw Exception('Piper não inicializado');
    }
    final result = _piperTts!.generate(
      text: texto,
      sid: 0,
      speed: 1.0,
    );
    if (result.samples.isEmpty) {
      throw Exception('Piper retornou áudio vazio');
    }
    final pcm = Int16List(result.samples.length);
    for (int i = 0; i < result.samples.length; i++) {
      pcm[i] = (result.samples[i] * 32767).round().clamp(-32768, 32767);
    }
    final dir = await getApplicationSupportDirectory();
    final wavFile = File(
        '${dir.path}/tts_${DateTime.now().millisecondsSinceEpoch}.wav');
    await _escreverWav(wavFile, pcm, result.sampleRate);
    return wavFile.path;
  }

  Future<void> falar(String texto) async {
    if (_piperDisponivel && _piperTts != null) {
      try {
        final path = await gerarAudio(texto);
        await _audioPlayer.setFilePath(path);
        await _audioPlayer.play();
        return;
      } catch (e) {
        print('❌ Piper erro: $e');
      }
    }
    await _flutterTts.speak(texto);
  }

  Future<void> _escreverWav(File file, Int16List pcm, int sampleRate) async {
    final dataSize = pcm.length * 2;
    final header = ByteData(44);
    header.setUint8(0, 0x52); header.setUint8(1, 0x49);
    header.setUint8(2, 0x46); header.setUint8(3, 0x46);
    header.setUint32(4, 36 + dataSize, Endian.little);
    header.setUint8(8, 0x57); header.setUint8(9, 0x41);
    header.setUint8(10, 0x56); header.setUint8(11, 0x45);
    header.setUint8(12, 0x66); header.setUint8(13, 0x6D);
    header.setUint8(14, 0x74); header.setUint8(15, 0x20);
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, 1, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, sampleRate * 2, Endian.little);
    header.setUint16(32, 2, Endian.little);
    header.setUint16(34, 16, Endian.little);
    header.setUint8(36, 0x64); header.setUint8(37, 0x61);
    header.setUint8(38, 0x74); header.setUint8(39, 0x61);
    header.setUint32(40, dataSize, Endian.little);
    final sink = file.openWrite();
    sink.add(header.buffer.asUint8List());
    sink.add(pcm.buffer.asUint8List());
    await sink.close();
  }

  Future<void> parar() async {
    await _audioPlayer.stop();
    await _flutterTts.stop();
  }

  void dispose() {
    _piperTts?.free();
    _audioPlayer.dispose();
  }
}
