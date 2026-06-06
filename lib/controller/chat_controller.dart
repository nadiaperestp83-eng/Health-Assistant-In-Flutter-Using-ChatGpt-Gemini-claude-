import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../apis/apis.dart';
import '../helper/my_dialog.dart';
import '../model/message.dart';

class ChatController extends GetxController {
  final textC = TextEditingController();
  final scrollC = ScrollController();

  final list = <Message>[
    Message(msg: 'Hello, How can I help you?', msgType: MessageType.bot)
  ].obs;

  Future<void> askQuestion() async {
    if (textC.text.trim().isNotEmpty) {
      list.add(Message(msg: textC.text, msgType: MessageType.user));
      list.add(Message(msg: '', msgType: MessageType.bot));
      _scrollDown();

      try {
        final res = await APIs.getAnswer(textC.text);
        list.removeLast();
        list.add(Message(
          msg: res.text.isEmpty ? 'Resposta vazia — provider: ${res.provider}' : res.text,
          msgType: MessageType.bot,
          aiProvider: res.provider,
        ));
      } catch (e) {
        list.removeLast();
        list.add(Message(
          msg: 'Exceção no controller: $e',
          msgType: MessageType.bot,
        ));
      }

      _scrollDown();
      textC.text = '';
    } else {
      MyDialog.info('Ask Something!');
    }
  }

  void _scrollDown() {
    scrollC.animateTo(scrollC.position.maxScrollExtent,
        duration: const Duration(milliseconds: 500), curve: Curves.ease);
  }
}
