import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../helper/global.dart';
import '../model/message.dart';

class MessageCard extends StatelessWidget {
  final Message message;

  const MessageCard({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return message.msgType == MessageType.bot
        ? _BotMessage(message: message)
        : _UserMessage(message: message);
  }
}

class _UserMessage extends StatelessWidget {
  final Message message;
  const _UserMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: mq.width * .75),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFEEEEEE),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text(
              message.msg,
              style: GoogleFonts.inter(fontSize: 15, color: Colors.black87, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _BotMessage extends StatefulWidget {
  final Message message;
  const _BotMessage({required this.message});

  @override
  State<_BotMessage> createState() => _BotMessageState();
}

class _BotMessageState extends State<_BotMessage> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _abrirRefugio(BuildContext context) async {
    // 1. Inicia o áudio
    await _audioPlayer.play(UrlSource("https://actions.google.com/sounds/v1/nature/ocean_waves.ogg"));
    
    // 2. Atualiza estado para mostrar que está tocando
    setState(() => _isPlaying = true);

    // 3. Abre o painel modal
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Color(0xFF0F1219),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Text("Refuge Mode", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const Spacer(),
            // Aqui entraria sua Mandala com animação
            const Icon(Icons.hub, size: 200, color: Colors.tealAccent), 
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () {
                _audioPlayer.pause();
                setState(() => _isPlaying = false);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
    
    // Quando fechar o modal, pausa o áudio
    _audioPlayer.pause();
    setState(() => _isPlaying = false);
  }

  @override
  Widget build(BuildContext context) {
    final showButton = widget.message.msg.contains('<SHOW_BUTTON>') || widget.message.msg.contains('SHOW_BUTTON');
    final cleanText = widget.message.msg.replaceAll('<SHOW_BUTTON>', '').replaceAll('SHOW_BUTTON', '').trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(cleanText, style: GoogleFonts.inter(fontSize: 15, color: Colors.black87, height: 1.6)),
          if (showButton)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: InkWell(
                onTap: () => _abrirRefugio(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_isPlaying ? Icons.pause_circle_filled : Icons.music_note_rounded, size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text('Ouvir o silêncio...', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
