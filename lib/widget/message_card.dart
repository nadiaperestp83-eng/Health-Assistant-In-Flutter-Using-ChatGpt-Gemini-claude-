import 'dart:async';
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
              style: GoogleFonts.inter(
                  fontSize: 15, color: Colors.black87, height: 1.5),
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
  StreamSubscription? _completeSub;
  bool _isPlaying = false;

  // Sons de domínio público — CDN confiável, formato MP3
  static const _sons = [
    'https://cdn.freesound.org/previews/531/531947_3797507-lq.mp3', // chuva leve
    'https://cdn.freesound.org/previews/531/531948_3797507-lq.mp3', // floresta
    'https://cdn.freesound.org/previews/316/316847_2653013-lq.mp3', // ondas do mar
    'https://cdn.freesound.org/previews/200/200213_2394539-lq.mp3', // vento calmo
  ];

  @override
  void dispose() {
    _completeSub?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _ouvirSilencio() async {
    if (_isPlaying) {
      await _audioPlayer.stop();
      _completeSub?.cancel();
      if (mounted) setState(() => _isPlaying = false);
      return;
    }

    final url = _sons[DateTime.now().millisecond % _sons.length];

    try {
      // Cancela listener anterior antes de criar novo
      await _completeSub?.cancel();

      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(url));

      if (mounted) setState(() => _isPlaying = true);

      _completeSub = _audioPlayer.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _isPlaying = false);
      });
    } catch (e) {
      if (mounted) setState(() => _isPlaying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showButton = widget.message.msg.contains('<SHOW_BUTTON>') ||
        widget.message.msg.contains('SHOW_BUTTON');
    final cleanText = widget.message.msg
        .replaceAll('<SHOW_BUTTON>', '')
        .replaceAll('SHOW_BUTTON', '')
        .trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.message.aiProvider != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome, size: 13, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    widget.message.aiProvider!,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          widget.message.msg.isEmpty
              ? AnimatedTextKit(
                  animatedTexts: [
                    TypewriterAnimatedText(
                      'Ouvindo...',
                      textStyle: GoogleFonts.inter(
                        fontSize: 15,
                        color: Colors.grey,
                        height: 1.5,
                      ),
                      speed: const Duration(milliseconds: 80),
                    ),
                  ],
                  repeatForever: true,
                )
              : Text(
                  cleanText,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: Colors.black87,
                    height: 1.6,
                  ),
                ),
          if (showButton)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: InkWell(
                onTap: _ouvirSilencio,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isPlaying
                            ? Icons.pause_circle_filled
                            : Icons.music_note_rounded,
                        size: 14,
                        color: const Color(0xFF6B8EFF),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isPlaying ? 'Pausar...' : 'Ouvir o silêncio...',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
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
