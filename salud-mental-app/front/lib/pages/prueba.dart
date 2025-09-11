import 'package:flutter/material.dart';
import '/components/navbar.dart'; // Ajusta la ruta según tu proyecto

class Prueba extends StatelessWidget {
  const Prueba({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Integra la NavBar aquí
      drawer: const CustomNavBar(),
      appBar: AppBar(
        title: const Text('Página de Ejemplo'),
        backgroundColor: const Color(0xFF72C7D3), // Color de tu tema
      ),
      body: const Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Contenido de la página',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text(
              'Este es un ejemplo de página. Reemplaza este widget con el contenido real de tu app (tarjetas, listas, formularios, etc.).',
              style: TextStyle(fontSize: 16),
            ),
            // Puedes agregar más widgets aquí:
            SizedBox(height: 30),
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Ejemplo de tarjeta'),
              ),
            ),
          ],
        ),
      ),
      // Opcional: Botón flotante de ejemplo
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: const Color(0xFF72C7D3),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
