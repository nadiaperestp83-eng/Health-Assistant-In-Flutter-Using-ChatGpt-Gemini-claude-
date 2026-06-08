import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../helper/my_dialog.dart';
import '../../controller/chat_controller.dart';
import '../../helper/global.dart';
import '../../widget/message_card.dart';
import '../../sounds_data.dart';
import '../../services/elevenlabs_service.dart';
import 'image_feature.dart';
import 'translator_feature.dart';

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

  int _selectedTab = 0;
  bool _isListening = false;
  bool _ttsEnabled = true;
  bool _isPlayingMusic = false;
  bool _isSpeaking = false; // indicador visual enquanto ElevenLabs fala

  final _tabs = [
    {'icon': Icons.chat_bubble_rounded, 'label': 'Chat'},
    {'icon': Icons.image_rounded,       'label': 'Imagem'},
    {'icon': Icons.translate_rounded,   'label': 'Tradutor'},
    {'icon': Icons.videocam_rounded,    'label': 'Vídeo'},
  ];

  // ─────────────────────────────────────────────
  // Init TTS nativo
  // ─────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _initTts();
  }

  void _initTts() async {
    await _tts.setLanguage('pt-BR');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  // ─────────────────────────────────────────────
  // PROTOCOLO DE PRESENÇA
  // Detecta [ALTA] ou [BAIXA] e direciona o áudio
  // ─────────────────────────────────────────────
  Future<void> _falarComPresenca(String textoRaw) async {
    if (!_ttsEnabled || textoRaw.isEmpty) return;

    // 1. Extrair tag
    final bool isAltaPresenca = textoRaw.trimLeft().startsWith('[ALTA]');

    // 2. Limpar tag + marcadores de botão
    final cleanText = textoRaw
        .replaceAll('[ALTA]', '')
        .replaceAll('[BAIXA]', '')
        .replaceAll('<SHOW_BUTTON>', '')
        .replaceAll('SHOW_BUTTON', '')
        .trim();

    if (cleanText.isEmpty) return;

    // 3. Parar qualquer voz em andamento
    await _tts.stop();
    await _player.stop();

    // 4. Direcionar
    if (isAltaPresenca) {
      await _falarElevenLabs(cleanText);
    } else {
      await _falarNativo(cleanText);
    }
  }

  // Voz ElevenLabs (alta presença)
  Future<void> _falarElevenLabs(String texto) async {
    final Uint8List? audioBytes = await ElevenLabsService.sintetizar(texto);

    if (audioBytes == null) {
      // Cota esgotada ou erro → fallback para TTS nativo
      await _falarNativo(texto);
      return;
    }

    try {
      setState(() => _isSpeaking = true);
      final source = MyCustomSource(audioBytes);
      await _player.setAudioSource(source);
      await _player.play();
      _player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          if (mounted) setState(() => _isSpeaking = false);
        }
      });
    } catch (_) {
      // Qualquer falha de reprodução → fallback
      await _falarNativo(texto);
    }
  }

  // TTS nativo Android (baixa presença ou fallback)
  Future<void> _falarNativo(String texto) async {
    setState(() => _isSpeaking = true);
    await _tts.speak(texto);
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
  }

  // ─────────────────────────────────────────────
  // Música ambiente (refúgio)
  // ─────────────────────────────────────────────
  void _ouvirSilencio() async {
    if (_isPlayingMusic) {
      await _player.stop();
      setState(() => _isPlayingMusic = false);
      return;
    }
    try {
      final random = Random();
      final url = trilhasRefugio[random.nextInt(trilhasRefugio.length)];
      await _player.setUrl(url);
      await _player.play();
      setState(() => _isPlayingMusic = true);
      _player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          if (mounted) setState(() => _isPlayingMusic = false);
        }
      });
    } catch (_) {
      MyDialog.error('Não foi possível tocar a música.');
    }
  }

  // ─────────────────────────────────────────────
  // STT (microfone)
  // ─────────────────────────────────────────────
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

  // ─────────────────────────────────────────────
  // Enviar pergunta via botão
  // ─────────────────────────────────────────────
  void _enviar() {
    _c.askQuestion().then((_) {
      final msgs = _c.list
          .where((m) => m.msgType.name == 'bot' && m.msg.isNotEmpty)
          .toList();
      if (msgs.isNotEmpty) {
        _falarComPresenca(msgs.last.msg);
      }
    });
  }

  @override
  void dispose() {
    _tts.stop();
    _stt.stop();
    _player.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────
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
        title: Text(
          _selectedTab == 0
              ? 'Assistente IA'
              : _selectedTab == 1
                  ? 'Criar Imagem'
                  : _selectedTab == 2
                      ? 'Tradutor'
                      : 'Criar Vídeo',
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          // Indicador visual de voz ElevenLabs ativa
          if (_isSpeaking)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(Icons.graphic_eq, color: Color(0xFF6B8EFF), size: 20),
            ),
          if (_isPlayingMusic)
            IconButton(
              icon: const Icon(Icons.stop_circle_outlined,
                  color: Color(0xFF6B8EFF)),
              onPressed: _ouvirSilencio,
            ),
          if (_selectedTab == 0)
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
          if (_selectedTab == 0)
            Obx(
              () => ListView(
                physics: const BouncingScrollPhysics(),
                controller: _c.scrollC,
                padding: EdgeInsets.only(
                  top: mq.height * .02,
                  bottom: mq.height * .22,
                  left: 16,
                  right: 16,
                ),
                // ✅ FIX: cast explícito para List<Widget>
                children: _c.list
                    .map<Widget>((e) => MessageCard(message: e))
                    .toList(),
              ),
            )
          else if (_selectedTab == 1)
            ImageFeature()
          else if (_selectedTab == 2)
            TranslatorFeature()
          else
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.videocam_rounded, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Em breve', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
        ],
      ),
      bottomSheet: _selectedTab == 0
          ? Container(
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _chip('🎨 Criar Imagem',
                                () => setState(() => _selectedTab = 1)),
                            const SizedBox(width: 8),
                            _chip('🌐 Traduzir',
                                () => setState(() => _selectedTab = 2)),
                            const SizedBox(width: 8),
                            _chip('🎬 Criar Vídeo',
                                () => setState(() => _selectedTab = 3)),
                            const SizedBox(width: 8),
                            _chip('🔍 Pesquisar', () {}),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
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
                                  contentPadding:
                                      const EdgeInsets.symmetric(
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
                                color: _isListening
                                    ? Colors.white
                                    : Colors.grey,
                                size: 22,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFF6B8EFF),
                                  Color(0xFFB06BFF)
                                ],
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
                  ],
                ),
              ),
            )
          : null,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedTab,
          onTap: (i) => setState(() => _selectedTab = i),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF6B8EFF),
          unselectedItemColor: Colors.grey,
          selectedLabelStyle:
              const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          elevation: 0,
          items: _tabs
              .map(
                (t) => BottomNavigationBarItem(
                  icon: Icon(t['icon'] as IconData),
                  label: t['label'] as String,
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _chip(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style:
                const TextStyle(fontSize: 13, color: Colors.black87)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AudioSource para bytes em memória (just_audio)
// Permite tocar o MP3 retornado pelo ElevenLabs sem salvar em disco
// ─────────────────────────────────────────────────────────────────────────────
class MyCustomSource extends StreamAudioSource {
  final Uint8List _buffer;
  MyCustomSource(this._buffer) : super(tag: 'ElevenLabsTTS');

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end   ??= _buffer.length;
    return StreamAudioResponse(
      sourceLength: _buffer.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(_buffer.sublist(start, end)),
      contentType: 'audio/mpeg',
    );
  }
}
