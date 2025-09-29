import 'package:flutter/material.dart';

class ChatScreen extends StatelessWidget {
  final String chatId;

  const ChatScreen({super.key, required this.chatId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: Center(child: Text('Chat Screen - ID: $chatId')),
    );
  }
}
