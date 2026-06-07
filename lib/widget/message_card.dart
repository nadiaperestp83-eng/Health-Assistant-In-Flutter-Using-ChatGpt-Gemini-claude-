import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../helper/global.dart';
import '../model/message.dart';

class MessageCard extends StatelessWidget {
  final Message message;
  final VoidCallback? onOuvir;

  const MessageCard({super.key, required this.message, this.onOuvir});

  @override
  Widget build(BuildContext context) {
    return message.msgType == MessageType.bot
        ? _BotMessage(message: message, onOuvir: onOuvir)
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
                fontSize: 15,
                color: Colors.black87,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BotMessage extends StatelessWidget {
  final Message message;
  final VoidCallback? onOuvir;
  const _BotMessage({required this.message, this.onOuvir});

  @override
  Widget build(BuildContext context) {
    final showButton = message.msg.contains('<SHOW_BUTTON>');
    final cleanText = message.msg.replaceAll('<SHOW_BUTTON>', '').trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.aiProvider != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ProviderChip(provider: message.aiProvider!),
            ),
          message.msg.isEmpty
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
          if (showButton && onOuvir != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: GestureDetector(
                onTap: onOuvir,
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
                      const Icon(Icons.music_note_rounded,
                          size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        'Ouvir o silêncio...',
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

class _ProviderChip extends StatelessWidget {
  final String provider;
  const _ProviderChip({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.auto_awesome, size: 13, color: Colors.grey),
        const SizedBox(width: 4),
        Text(
          provider,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
