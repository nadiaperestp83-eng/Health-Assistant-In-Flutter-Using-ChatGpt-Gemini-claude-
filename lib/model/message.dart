class Message {
  String msg;
  final MessageType msgType;
  final String? aiProvider;

  Message({
    required this.msg,
    required this.msgType,
    this.aiProvider,
  });
}

enum MessageType { user, bot }
