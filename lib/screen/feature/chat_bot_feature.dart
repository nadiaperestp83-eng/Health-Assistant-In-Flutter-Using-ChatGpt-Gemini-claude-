// lib/screen/feature/chat_bot_feature.dart

import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../controller/chat_controller.dart';
import '../../elevenlabs_service.dart';
import '../../helper/global.dart';
import '../../helper/my_dialog.dart';
import '../../services/tts_service.dart';
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
  final _ttsPlayer = AudioPlayer();

  StreamSubscription? _playerSub;

  bool _isListening = false;
  bool _ttsEnabled = true;
  bool _isSpeaking = false;

  // 1 = Piper Cadu (offline), 2 = ElevenLabs, 3 = Flutter TTS neural
  int _voiceMode = 1;

  @override
  void initState() {
    super.initState();
    _initTts();
    // Pré-inicializa o Piper em background para primeira fala ser rápida
    TtsService.instance.inicializar().catchError((e) {
      log('⚠️ Piper pré-init: $e');
    });
  }

  void _initTts() async {
    try {
      await _tts.setEngine("com.google.android.tts");
    } catch (e) {
      log('⚠️ Engine Google TTS: $e');
    }
    await _tts.setLanguage('pt-BR');
    await _tts.setSpeechRate(0.48);
    await _tts.setVolume(1.0);
    await _tts.setPitch(0.88);

    try {
      final voices = await _tts.getVoices;
      if (voices != null) {
        final voiceList = List<Map>.from(voices);
        final neural = voiceList.where((v) {
          final name = (v['name'] ?? '').toString().toLowerCase();
          final locale = (v['locale'] ?? '').toString().toLowerCase();
          return (locale.contains('pt-br') || locale.contains('pt_br')) &&
              (name.contains('neural') ||
                  name.contains('wavenet') ||
                  name.contains('enhanced') ||
                  name.contains('premium'));
        }).toList();

        if (neural.isNotEmpty) {
          await _tts.setVoice({
            'name': neural.first['name'],
            'locale': neural.first['locale'],
          });
          log('✅ Voz neural selecionada: ${neural.first['name']}');
        } else {
          final ptbr = voiceList.where((v) {
            final locale = (v['locale'] ?? '').toString().toLowerCase();
            return locale.contains('pt-br') || locale.contains('pt_br');
          }).toList();
          if (ptbr.isNotEmpty) {
            await _tts.setVoice({
              'name': ptbr.first['name'],
              'locale': ptbr.first['locale'],
            });
            log('ℹ️ Voz pt-BR selecionada: ${ptbr.first['name']}');
          }
        }
      }
    } catch (e) {
      log('⚠️ Seleção de voz: $e');
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
    await _ttsPlayer.stop();
    await _playerSub?.cancel();
    _playerSub = null;

    setState(() => _isSpeaking = true);

    // ===== VOZ 1: Piper Cadu (offline) =====
    if (_voiceMode == 1) {
      try {
        log('🎙️ Piper Cadu...');
        final path = await TtsService.instance.gerarAudio(cleanText);
        await _tocarArquivo(path);
        return;
      } catch (e) {
        log('❌ Piper erro: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('❌ Piper: $e',
                style: const TextStyle(fontSize: 12)),
            backgroundColor: Colors.red[900],
            duration: const Duration(seconds: 10),
          ));
          setState(() => _isSpeaking = false);
        }
        return;
      }
    }

    // ===== VOZ 2: ElevenLabs =====
    if (_voiceMode == 2) {
      try {
        log('🎙️ Tentando ElevenLabs...');
        final path = await ElevenLabsService.sintetizar(cleanText);
        await _tocarArquivo(path!);
        return;
      } catch (e) {
        log('❌ ElevenLabs erro: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('❌ ElevenLabs: $e',
                style: const TextStyle(fontSize: 12)),
            backgroundColor: Colors.red[900],
            duration: const Duration(seconds: 10),
          ));
          setState(() => _isSpeaking = false);
        }
        return;
      }
    }

    // ===== VOZ 3: Flutter TTS Neural =====
    log('🎤 TTS nativo neural (modo 3)');
    await _tts.speak(cleanText);
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
  }

  Future<void> _tocarArquivo(String filePath) async {
    await _ttsPlayer.setFilePath(filePath);
    await _ttsPlayer.play();
    _playerSub = _ttsPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        File(filePath).delete().catchError((_) {});
        if (mounted) setState(() => _isSpeaking = false);
      }
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

  void _mostrarSeletorVoz() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Escolher voz',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              _voiceTile(
                icon: Icons.spatial_audio_rounded,
                title: 'Voz 1 — Piper Cadu (offline)',
                subtitle: 'Masculina pt-BR, neural offline',
                mode: 1,
                setModalState: setModalState,
              ),
              _voiceTile(
                icon: Icons.spatial_audio_off_rounded,
                title: 'Voz 2 — ElevenLabs',
                subtitle: 'Neural premium multilíngue',
                mode: 2,
                setModalState: setModalState,
              ),
              _voiceTile(
                icon: Icons.record_voice_over_rounded,
                title: 'Voz 3 — TTS Neural',
                subtitle: 'Voz neural do dispositivo (offline)',
                mode: 3,
                setModalState: setModalState,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _voiceTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required int mode,
    required StateSetter setModalState,
  }) {
    final selected = _voiceMode == mode;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF6B8EFF).withOpacity(0.15)
              : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon,
            color: selected ? const Color(0xFF6B8EFF) : Colors.grey),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle),
      trailing: selected
          ? const Icon(Icons.check_circle, color: Color(0xFF6B8EFF))
          : null,
      onTap: () {
        setModalState(() {});
        setState(() => _voiceMode = mode);
        Navigator.pop(context);
      },
    );
  }

  @override
  void dispose() {
    _playerSub?.cancel();
    _tts.stop();
    _stt.stop();
    _player.dispose();
    _ttsPlayer.dispose();
    TtsService.instance.dispose();
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
          GestureDetector(
            onTap: _mostrarSeletorVoz,
            child: Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF6B8EFF).withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _voiceMode == 1
                        ? Icons.spatial_audio_rounded
                        : _voiceMode == 2
                            ? Icons.spatial_audio_off_rounded
                            : Icons.record_voice_over_rounded,
                    color: const Color(0xFF6B8EFF),
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Voz $_voiceMode',
                    style: const TextStyle(
                      color: Color(0xFF6B8EFF),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
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
                _ttsPlayer.stop();
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
                      onTapOutside: (e) => FocusScope.of(context).unfocus(),
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
