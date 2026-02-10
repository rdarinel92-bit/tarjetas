import 'package:flutter/material.dart';
import '../components/premium_scaffold.dart';
import '../components/premium_card.dart';
import '../components/premium_button.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: "Chat",
      body: Column(
        children: [
          PremiumButton(
            text: "Nueva Conversación",
            icon: Icons.chat,
            onPressed: () {},
          ),
          PremiumCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text("Conversaciones",
                    style: TextStyle(color: Colors.white, fontSize: 18)),
                SizedBox(height: 10),
                Text("Aquí aparecerán las conversaciones...",
                    style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
