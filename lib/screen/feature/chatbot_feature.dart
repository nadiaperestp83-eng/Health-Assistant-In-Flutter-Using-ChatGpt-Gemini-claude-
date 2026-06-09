import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:path_provider/path_provider.dart';

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
  final _player = AudioPlayer(); // músicas ambiente
  final _ttsPlayer = AudioPlayer(); // ElevenLabs TTS

  StreamSubscription? _playerSub;

  bool _isListening = false;
  bool _ttsEnabled = true;
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    _initTts();
  }
// ... [TODO O SEU CÓDIGO DA TELA] ...
} // <--- AQUI TERMINA SUA CLASSE CHATBOT_FEATURE

// A CLASSE DO TUTORIAL VAI AQUI, NO FINAL DO ARQUIVO:

class MyCustomSource extends StreamAudioSource {
  final List<int> bytes;
  MyCustomSource(this.bytes);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= bytes.length;
    return StreamAudioResponse(
      sourceLength: bytes.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(bytes.sublist(start, end)),
      contentType: 'audio/mpeg',
    );
  }
}

  void _initTts() async {
    // FORÇA TTS NEURAL HUMANO (WaveNet / Belle / Google Neural)
    await _tts.setLanguage('pt-BR');
    await _tts.setSpeechRate(0.55);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    
    // Tenta forçar o motor neural do Google
    try {
      await _tts.setEngine("com.google.android.tts");
      log('✅ Motor TTS: Google TTS configurado');
    } catch (e) {
      log('⚠️ Não foi possível setar engine Google: $e');
    }
    
    // Força voz neural disponível no dispositivo
    try {
      final voices = await _tts.getVoices as List?;
      if (voices != null && voices.isNotEmpty) {
        // Lista de vozes neurais humanas em português
        final vozesNeurais = [
          'pt-BR-neural',
          'pt-BR-wavenet',
          'pt-BR-std',
          'pt-br-x-iub-network',  // Belle (Google Neural)
          'pt-br-x-iua-network',  // Google Neural Feminina
          'com.google.android.tts:pt-br-x-iub-network',
          'com.google.android.tts:pt-br-x-iua-network',
        ];
        
        String? vozEscolhida;
        
        // Procura por voz neural
        for (final voz in vozesNeurais) {
          final encontrada = voices.cast<Map>().firstWhere(
            (v) {
              final nome = (v['name'] ?? '').toString().toLowerCase();
              final id = (v['id'] ?? '').toString().toLowerCase();
              return nome.contains(voz.toLowerCase()) || id.contains(voz.toLowerCase());
            },
            orElse: () => {},
          );
          if (encontrada.isNotEmpty) {
            vozEscolhida = encontrada['name']?.toString();
            log('✅ Voz neural encontrada: $vozEscolhida');
            break;
          }
        }
        
        // Se não achou, tenta qualquer voz que contenha 'neural' ou 'wavenet'
        if (vozEscolhida == null) {
          for (final v in voices.cast<Map>()) {
            final nome = (v['name'] ?? '').toString().toLowerCase();
            final id = (v['id'] ?? '').toString().toLowerCase();
            if (nome.contains('neural') || 
                id.contains('neural') ||
                nome.contains('wavenet') || 
                id.contains('wavenet')) {
              vozEscolhida = v['name']?.toString();
              log('✅ Voz alternativa neural: $vozEscolhida');
              break;
            }
          }
        }
        
        if (vozEscolhida != null) {
          await _tts.setVoice({'name': vozEscolhida, 'locale': 'pt-BR'});
          log('🎤 Voz neural configurada: $vozEscolhida');
        } else {
          log('⚠️ Nenhuma voz neural encontrada, usando padrão do sistema');
        }
      }
    } catch (e) {
      log('❌ Erro ao configurar voz neural: $e');
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

    // ===== PRIORIDADE 1: ElevenLabs =====
    log('🎯 Tentando ElevenLabs primeiro...');
    log('🔑 Chave tem ${elevenlabsKey.length} caracteres');
    
    if (elevenlabsKey.isNotEmpty && elevenlabsKey != '') {
      try {
        final Uint8List? audioBytes = await ElevenLabsService.sintetizar(cleanText);
        
        if (audioBytes != null) {
          log('✅ ElevenLabs: áudio recebido (${audioBytes.length} bytes)');
          
          // Salva temporariamente e toca
          final tempDir = await getTemporaryDirectory();
          final tempFile = File('${tempDir.path}/elevenlabs_${DateTime.now().millisecondsSinceEpoch}.mp3');
          await tempFile.writeAsBytes(audioBytes);
          
          await _ttsPlayer.setFilePath(tempFile.path);
          await _ttsPlayer.play();
          
          _playerSub = _ttsPlayer.playerStateStream.listen((state) {
            if (state.processingState == ProcessingState.completed) {
              if (mounted) setState(() => _isSpeaking = false);
              // Limpa arquivo temporário
              tempFile.delete();
            }
          });
          return; // Sai da função - ElevenLabs funcionou!
        } else {
          log('⚠️ ElevenLabs: retornou null, usando fallback neural');
        }
      } catch (e) {
        log('❌ ElevenLabs exceção: $e');
      }
    } else {
      log('⚠️ ElevenLabs: chave vazia, usando fallback neural');
    }

    // ===== PRIORIDADE 2: Fallback TTS Neural Humano =====
    log('🎧 Usando fallback TTS neural humano (WaveNet/Belle)');
    await _falarNeural(cleanText);
  }

  Future<void> _falarNeural(String texto) async {
    try {
      // Recria a configuração neural antes de falar
      await _tts.setLanguage('pt-BR');
      await _tts.setSpeechRate(0.55);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      
      // Força motor Google novamente
      try {
        await _tts.setEngine("com.google.android.tts");
      } catch (e) {
        // Ignora se não conseguir
      }
      
      // Força voz neural novamente
      try {
        final voices = await _tts.getVoices as List?;
        if (voices != null && voices.isNotEmpty) {
          // Prioridade: Belle (x-iub), depois WaveNet, depois qualquer neural
          final prioridades = [
            'x-iub',      // Belle (voz feminina neural)
            'x-iua',      // Google Neural feminina
            'wavenet',
            'neural',
          ];
          
          String? melhorVoz;
          for (final prioridade in prioridades) {
            final encontrada = voices.cast<Map>().firstWhere(
              (v) {
                final nome = (v['name'] ?? '').toString().toLowerCase();
                final id = (v['id'] ?? '').toString().toLowerCase();
                return (nome.contains(prioridade) || id.contains(prioridade)) && 
                       (nome.contains('pt') || id.contains('pt'));
              },
              orElse: () => {},
            );
            if (encontrada.isNotEmpty) {
              melhorVoz = encontrada['name']?.toString();
              log('✅ Fallback usando voz: $melhorVoz');
              break;
            }
          }
          
          if (melhorVoz != null) {
            await _tts.setVoice({'name': melhorVoz, 'locale': 'pt-BR'});
          }
        }
      } catch (e) {
        log('Erro ao forçar voz neural no fallback: $e');
      }
      
      await _tts.speak(texto);
      _tts.setCompletionHandler(() {
        if (mounted) setState(() => _isSpeaking = false);
      });
    } catch (e) {
      log('❌ Erro TTS neural: $e');
      // Último fallback: TTS padrão do sistema
      try {
        await _tts.speak(texto);
      } catch (_) {}
      if (mounted) setState(() => _isSpeaking = false);
    }
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
    _playerSub?.cancel();
    _tts.stop();
    _stt.stop();
    _player.dispose();
    _ttsPlayer.dispose();
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
              child: Icon(Icons.graphic_eq, color: Color(0xFF6B8EFF), size: 20),
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
                children:
                    _c.list.map<Widget>((e) => MessageCard(message: e)).toList(),
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
