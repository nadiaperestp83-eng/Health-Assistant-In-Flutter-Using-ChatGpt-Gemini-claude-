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
  TtsService._internal();

  sherpa_onnx.OfflineTts? _piperTts;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _flutterTts = FlutterTts();
  bool _piperDisponivel = false;

  Future<void> inicializar() async {
    try {
      // ✅ FIX: inicializar bindings ANTES de qualquer uso do sherpa_onnx
      sherpa_onnx.initBindings();

      final dir = await getApplicationSupportDirectory();
      final modelPath = '${dir.path}/pt_BR-cadu-medium.onnx';

      if (!File(modelPath).existsSync()) {
        await _copiarModeloDoAsset(modelPath);
      }

      final config = sherpa_onnx.OfflineTtsConfig(
        model: sherpa_onnx.OfflineTtsModelConfig(
          vits: sherpa_onnx.OfflineTtsVitsModelConfig(
            model: modelPath,
            lexicon: '',
            tokens: '',
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
        maxNumSentences: 1,
      );

      _piperTts = sherpa_onnx.OfflineTts(config);
      _piperDisponivel = true;
      print('✅ Piper Cadu inicializado com sucesso');
    } catch (e) {
      print('⚠️ Piper indisponível, usando fallback: $e');
      _piperDisponivel = false;
    }

    // Configurar fallback Flutter TTS
    await _flutterTts.setLanguage('pt-BR');
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  Future<void> _copiarModeloDoAsset(String destino) async {
    final byteData = await rootBundle.load('assets/voices/pt_BR-cadu-medium.onnx');
    final buffer = byteData.buffer;
    final file = File(destino);
    await file.parent.create(recursive: true);

    // Copiar em chunks de 4MB
    const chunkSize = 4 * 1024 * 1024;
    int offset = 0;
    final sink = file.openWrite();
    while (offset < buffer.lengthInBytes) {
      final end = (offset + chunkSize).clamp(0, buffer.lengthInBytes);
      sink.add(Uint8List.view(buffer, offset, end - offset));
      offset = end;
    }
    await sink.close();
    print('✅ Modelo Piper copiado para: $destino');
  }

  Future<void> falar(String texto) async {
    if (_piperDisponivel && _piperTts != null) {
      try {
        final result = _piperTts!.generate(
          text: texto,
          sid: 0,
          speed: 1.0,
        );
        if (result.samples.isNotEmpty) {
          await _reproduzirPcm(result.samples, result.sampleRate);
          return;
        }
      } catch (e) {
        print('❌ Piper erro: $e');
      }
    }

    // Fallback ElevenLabs ou Flutter TTS (já existente no seu app)
    await _flutterTts.speak(texto);
  }

  Future<void> _reproduzirPcm(
      List<double> samples, int sampleRate) async {
    // Converter float32 para PCM16
    final pcm = Int16List(samples.length);
    for (int i = 0; i < samples.length; i++) {
      pcm[i] = (samples[i] * 32767).round().clamp(-32768, 32767);
    }

    final dir = await getApplicationSupportDirectory();
    final wavFile = File('${dir.path}/tts_output.wav');
    await _escreverWav(wavFile, pcm, sampleRate);

    await _audioPlayer.setFilePath(wavFile.path);
    await _audioPlayer.play();
  }

  Future<void> _escreverWav(
      File file, Int16List pcm, int sampleRate) async {
    final numSamples = pcm.length;
    final byteRate = sampleRate * 2;
    final dataSize = numSamples * 2;

    final header = ByteData(44);
    // RIFF header
    header.setUint8(0, 0x52); header.setUint8(1, 0x49);
    header.setUint8(2, 0x46); header.setUint8(3, 0x46);
    header.setUint32(4, 36 + dataSize, Endian.little);
    header.setUint8(8, 0x57); header.setUint8(9, 0x41);
    header.setUint8(10, 0x56); header.setUint8(11, 0x45);
    // fmt chunk
    header.setUint8(12, 0x66); header.setUint8(13, 0x6D);
    header.setUint8(14, 0x74); header.setUint8(15, 0x20);
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);  // PCM
    header.setUint16(22, 1, Endian.little);  // mono
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, 2, Endian.little);
    header.setUint16(34, 16, Endian.little);
    // data chunk
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
