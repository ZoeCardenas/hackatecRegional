import 'package:flutter/material.dart';

class ChatTexto extends StatelessWidget {
  final String mensaje;

  const ChatTexto({super.key, required this.mensaje});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        mensaje,
        style: const TextStyle(fontSize: 16),
      ),
    );
  }
}
