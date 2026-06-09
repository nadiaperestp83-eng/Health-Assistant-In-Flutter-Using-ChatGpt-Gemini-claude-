import 'dart:developer';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../controller/chat_controller.dart';
import '../../elevenlabs_service.dart';
import '../../helper/global.dart';
import '../../helper/my_dialog.dart';
import '../../widget/message_card.dart';

class ChatBotFeature extends StatefulWidget {
  const ChatBotFeature({super.key});

  @override
  State<ChatBotFeature> createState() => _ChatBotFeatureState();
}

class _ChatBotFeatureState extends State<ChatBotFeature> {
  final _c = ChatController();
  final _tts = FlutterTts();
  final _stt = SpeechToText();
  final _player = AudioPlayer();

  bool _isListening = false;
  bool _ttsEnabled = true;
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  void _initTts() async {
    await _tts.setLanguage('pt-BR');
    await _tts.setSpeechRate(0.55);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    // Busca a voz mais acolhedora/humana disponível no dispositivo
    try {
      final voices = await _tts.getVoices as List?;
      if (voices != null && voices.isNotEmpty) {
        // Prioridade: neural > high-quality > iub/iuc > pt-BR genérico
        final prioridade = ['neural', 'high-quality', 'iub', 'iuc', 'enhanced'];
        String? melhorVoz;

        for (final tag in prioridade) {
          final encontrada = voices.cast<Map>().firstWhere(
            (v) {
              final nome = (v['name'] ?? '').toString().toLowerCase();
              final locale = (v['locale'] ?? '').toString().toLowerCase();
              return nome.contains(tag) && locale.contains('pt');
            },
            orElse: () => {},
          );
          if (encontrada.isNotEmpty) {
            melhorVoz = encontrada['name']?.toString();
            break;
          }
        }

        // Fallback: qualquer voz pt-BR
        melhorVoz ??= voices.cast<Map>().firstWhere(
          (v) => (v['locale'] ?? '').toString().toLowerCase().contains('pt-br'),
          orElse: () => {},
        )['name']?.toString();

        if (melhorVoz != null) {
          await _tts.setVoice({'name': melhorVoz, 'locale': 'pt-BR'});
          log('TTS voz selecionada: $melhorVoz');
        }
      }
    } catch (e) {
      log('TTS voz fallback genérico: $e');
    }
  }

  Future<void> _falarComPresenca(String textoRaw) async {
    if (!_ttsEnabled || textoRaw.isEmpty) return;

    final cleanText = textoRaw
        .replaceAll('<SHOW_BUTTON>', '')
        .replaceAll('SHOW_BUTTON', '')
        .trim();

    if (cleanText.isEmpty) return;

    await _tts.stop();
    setState(() => _isSpeaking = true);

    final Uint8List? audioBytes = await ElevenLabsService.sintetizar(cleanText);

    if (audioBytes != null) {
      try {
        final source = MyBytesAudioSource(audioBytes);
        await _player.setAudioSource(source);
        await _player.play();
        _player.playerStateStream.listen((state) {
          if (state.processingState == ProcessingState.completed) {
            if (mounted) setState(() => _isSpeaking = false);
          }
        });
      } catch (_) {
        await _falarNativo(cleanText);
      }
    } else {
      // ElevenLabs falhou (429 ou erro) — fallback imediato para TTS nativo
      await _falarNativo(cleanText);
    }
  }

  Future<void> _falarNativo(String texto) async {
    await _tts.speak(texto);
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
  }

  void _startListening() async {
    final available = await _stt.initialize();
    if (available) {
      setState(() => _isListening = true);
      _stt.listen(
        onResult: (result) {
          _c.textC.text = result.recognizedWords;
          if (result.finalResult) {
            setState(() => _isListening = false);
            if (_c.textC.text.isNotEmpty) {
              _c.askQuestion().then((_) {
                final last = _c.list.lastWhere(
                  (m) => m.msgType.name == 'bot' && m.msg.isNotEmpty,
                  orElse: () => _c.list.last,
                );
                _falarComPresenca(last.msg);
              });
            }
          }
        },
        localeId: 'pt_BR',
      );
    } else {
      MyDialog.info('Microfone não disponível!');
    }
  }

  void _stopListening() {
    _stt.stop();
    setState(() => _isListening = false);
  }

  void _enviar() {
    _c.askQuestion().then((_) {
      final msgs = _c.list
          .where((m) => m.msgType.name == 'bot' && m.msg.isNotEmpty)
          .toList();
      if (msgs.isNotEmpty) _falarComPresenca(msgs.last.msg);
    });
  }

  @override
  void dispose() {
    _tts.stop();
    _stt.stop();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.black87),
          onPressed: () {},
        ),
        title: const Text(
          'Assistente IA',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_isSpeaking)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.graphic_eq,
                  color: Color(0xFF6B8EFF), size: 20),
            ),
          IconButton(
            icon: Icon(
              _ttsEnabled ? Icons.volume_up : Icons.volume_off,
              color: _ttsEnabled ? const Color(0xFF6B8EFF) : Colors.grey,
            ),
            onPressed: () {
              setState(() => _ttsEnabled = !_ttsEnabled);
              if (!_ttsEnabled) {
                _tts.stop();
                _player.stop();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.black87),
            onPressed: () {},
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF8F9FF), Color(0xFFFFFFFF)],
              ),
            ),
          ),
          Obx(() => ListView(
                physics: const BouncingScrollPhysics(),
                controller: _c.scrollC,
                padding: EdgeInsets.only(
                    top: mq.height * .02,
                    bottom: mq.height * .18,
                    left: 16,
                    right: 16),
                children: _c.list
                    .map<Widget>((e) => MessageCard(message: e))
                    .toList(),
              )),
        ],
      ),
      bottomSheet: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.camera_alt_outlined,
                      color: Colors.grey, size: 22),
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextFormField(
                      controller: _c.textC,
                      onTapOutside: (e) =>
                          FocusScope.of(context).unfocus(),
                      decoration: InputDecoration(
                        hintText: _isListening
                            ? 'Ouvindo...'
                            : 'Digite ou fale algo...',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: _isListening
                              ? const Color(0xFF6B8EFF)
                              : Colors.grey,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTapDown: (_) => _startListening(),
                  onTapUp: (_) => _stopListening(),
                  onTapCancel: () => _stopListening(),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isListening
                          ? const Color(0xFF6B8EFF)
                          : const Color(0xFFF5F5F5),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: _isListening ? Colors.white : Colors.grey,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF6B8EFF), Color(0xFFB06BFF)],
                    ),
                  ),
                  child: IconButton(
                    onPressed: _enviar,
                    icon: const Icon(Icons.arrow_upward_rounded,
                        color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Fonte de áudio em bytes para just_audio (ElevenLabs TTS)
class MyBytesAudioSource extends StreamAudioSource {
  final Uint8List _buffer;
  MyBytesAudioSource(this._buffer) : super(tag: 'MyBytesAudioSource');

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _buffer.length;
    return StreamAudioResponse(
      sourceLength: _buffer.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(_buffer.sublist(start, end)),
      contentType: 'audio/mpeg',
    );
  }
}
