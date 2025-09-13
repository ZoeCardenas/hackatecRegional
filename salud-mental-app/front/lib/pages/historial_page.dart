import 'package:flutter/material.dart';
import '../components/navbar.dart';

class HistorialClinicoPage extends StatelessWidget {
  const HistorialClinicoPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Map<String, String> datosClinicos = {
      'Paciente': 'Zoe Cardenas',
      'Edad': '19 años',
      'Enfermedades cronicas': 'Hipertensión',
      'Tipo de sangre': 'O+',
      'Alergias': 'Penicilina',
      'Estatura': '1.75 m',
      'IMC': '24.5',
      'Cirugias': 'Apendicitis',
    };

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      drawer: const CustomNavBar(),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 187, 196, 189),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Image.asset(
              'assets/imagenes/2.png',
              height: 150,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 10),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: ListView(
          children: [
            const Text(
              'HISTORIAL CLÍNICO',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            _buildDataRow('Paciente:', datosClinicos['Paciente']!),
            _buildDataRow('Edad:', datosClinicos['Edad']!),
            _buildDataRow('Enfermedades crónicas:',
                datosClinicos['Enfermedades cronicas']!),
            _buildDataRow('Tipo de sangre:', datosClinicos['Tipo de sangre']!),
            _buildDataRow('Alergias:', datosClinicos['Alergias']!),
            _buildDataRow('Estatura:', datosClinicos['Estatura']!),
            _buildDataRow('IMC:', datosClinicos['IMC']!),
            _buildDataRow('Cirugías:', datosClinicos['Cirugias']!),
          ],
        ),
      ),
    );
  }

  Widget _buildDataRow(String label, String data) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Color(0xFF3C6043),
            ),
          ),
          Flexible(
            child: Text(
              data,
              style: const TextStyle(fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
