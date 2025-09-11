import 'package:flutter/material.dart';
import '/components/navbar.dart'; // Ajusta la ruta según tu proyecto
import 'dart:html' as html; // Solo funciona en Flutter Web

class Prueba extends StatelessWidget {
  const Prueba({super.key});

  void _confirmarBorrado(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text("Confirmar borrado"),
          content: const Text("¿Estás seguro de que deseas borrar tu cuenta?"),
          actions: [
            TextButton(
              child: const Text("Cancelar"),
              onPressed: () {
                Navigator.of(ctx).pop();
              },
            ),
            ElevatedButton(
              child: const Text("Confirmar"),
              onPressed: () {
                Navigator.of(ctx).pop(); // Cierra el diálogo
                // Redirigir a google.com (Flutter Web)
                html.window.location.href = "/";
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const CustomNavBar(),
      appBar: AppBar(
        title: const Text('Borrar Cuenta'),
        backgroundColor: const Color(0xFF72C7D3),
      ),
      body: Center(
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
          ),
          onPressed: () => _confirmarBorrado(context),
          child: const Text(
            "Borrar cuenta",
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
      ),
    );
  }
}
