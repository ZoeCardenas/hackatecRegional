import 'package:flutter/material.dart';

class ResultadoWidget extends StatelessWidget {
  final String resultado;
  final double confianza;

  const ResultadoWidget({
    super.key,
    required this.resultado,
    required this.confianza,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            resultado,
            style: const TextStyle(fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'Confianza: ${(confianza * 100).toStringAsFixed(2)}%',
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
