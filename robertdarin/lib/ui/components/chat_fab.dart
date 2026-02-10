import 'package:flutter/material.dart';

class ChatFAB extends StatelessWidget {
  final VoidCallback onPressed;

  const ChatFAB({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      backgroundColor: Colors.blueAccent,
      elevation: 8,
      child: const Icon(Icons.chat_bubble, size: 28, color: Colors.white),
      onPressed: onPressed,
    );
  }
}
