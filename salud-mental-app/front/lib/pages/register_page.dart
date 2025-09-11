import 'package:flutter/material.dart';
import '../components/navbar.dart';
import '../components/custom_button.dart';
import '../components/input_field.dart';

class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD5CCC8), // Fondo suave como en login
      drawer: const CustomNavBar(), // NavBar lateral consistente
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 102, 146, 111),
        automaticallyImplyLeading:
            false, // Oculta el botón de retroceso (si no es necesario)
        title: Container(
          width: double.infinity, // Ocupa todo el ancho disponible
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end, // Alinea a la derecha
            crossAxisAlignment:
                CrossAxisAlignment.center, // Centra verticalmente
            children: [
              Image.asset(
                'assets/imagenes/wsswd.jpg',
                height:
                    50, // Reduje la altura para que quepa mejor en el AppBar
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 10),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Container(
            width: 380,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFF1E627C), // Fondo azul como en login
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black38,
                  offset: Offset(5, 5),
                  blurRadius: 15,
                ),
                BoxShadow(
                  color: Colors.white24,
                  offset: Offset(-3, -3),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Text(
                    'NUEVO USUARIO',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFBFE3D5), // Color texto claro
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                // Fecha de nacimiento
                const Text(
                  'Fecha de nacimiento (DD/MM/AAAA)',
                  style: TextStyle(
                    color: Color(0xFFBFE3D5),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 10),
                _buildDateField(),
                const SizedBox(height: 20),

                // Datos en tabla
                _buildInfoRow('Teléfono'),
                const SizedBox(height: 15),
                _buildInfoRow('Sexo'),
                const SizedBox(height: 15),
                _buildInfoRow('Estatura (cm)'),
                const SizedBox(height: 15),
                _buildInfoRow('Peso (kg)'),
                const SizedBox(height: 25),

                // Tipo de sangre
                const Text(
                  'Tipo de sangre',
                  style: TextStyle(
                    color: Color(0xFFBFE3D5),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 10),
                _buildBloodTypeDropdown(),
                const SizedBox(height: 25),

                // Checkboxes médicos
                _buildMedicalCheckbox('Cirugías previas'),
                _buildMedicalCheckbox('Alergias'),
                _buildMedicalCheckbox('Enfermedades crónicas'),
                const SizedBox(height: 30),

                // Botón GENERAR
                Center(
                  child: CustomButton(
                    text: 'GENERAR',
                    onPressed: () {
                      // Lógica de registro
                    },
                    width: 200,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateField() {
    return InputField(
      hintText: 'DD/MM/AAAA',
      icon: Icons.calendar_today,
      keyboardType: TextInputType.datetime,
    );
  }

  Widget _buildInfoRow(String label) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFFBFE3D5),
              fontSize: 16,
            ),
          ),
        ),
        const Text(':', style: TextStyle(color: Colors.white)),
        const Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: 10),
            child: InputField(hintText: '', showIcon: false),
          ),
        ),
      ],
    );
  }

  Widget _buildBloodTypeDropdown() {
    const bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      ),
      items: bloodTypes.map((type) {
        return DropdownMenuItem(
          value: type,
          child: Text(type),
        );
      }).toList(),
      onChanged: (value) {},
      hint: const Text('Selecciona tu tipo'),
    );
  }

  Widget _buildMedicalCheckbox(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Checkbox(
            value: false,
            onChanged: (value) {},
            fillColor: MaterialStateProperty.all(const Color(0xFF72C7D3)),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFBFE3D5),
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
