import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'first.dart'; // 👈 está en el mismo paquete

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  late final AnimationController _floatCtrl =
      AnimationController(vsync: this, duration: const Duration(seconds: 4))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _floatCtrl.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _fakeLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 700)); // decorativo
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const First()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = const Color(0xFFFFFFFF); // como First
    final appbar = const Color.fromARGB(255, 187, 196, 189);
    final accent = Colors.lightBlue[100]!;
    final btn = const Color(0xFF72C7D3);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: appbar,
        elevation: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Logo (mismo asset que usas en First)
            Image.asset(
              'assets/imagenes/2.png',
              height: 120,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
            const Text(
              'CORALIA',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          // --- FONDO DECORATIVO suave, acorde al estilo ---
          Positioned.fill(
            child: CustomPaint(painter: _SoftBubbles(color: accent)),
          ),
          // --- CONTENIDO ---
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 780),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: Row(
                  children: [
                    // Columna izquierda con avatar animado (estética de First)
                    Expanded(
                      child: AnimatedBuilder(
                        animation: _floatCtrl,
                        builder: (context, _) {
                          final dy = math.sin(_floatCtrl.value * math.pi * 2) * 6;
                          return Transform.translate(
                            offset: Offset(0, dy),
                            child: _AvatarCard(),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Tarjeta de login
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              offset: Offset(0, 6),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Inicia sesión',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F0B18),
                                ),
                              ),
                              const SizedBox(height: 16),
                              _Input(
                                controller: _email,
                                hint: 'Email',
                                keyboardType: TextInputType.emailAddress,
                                validator: (v) => (v == null || v.isEmpty)
                                    ? 'Ingresa tu email'
                                    : null,
                              ),
                              const SizedBox(height: 12),
                              _Input(
                                controller: _pass,
                                hint: 'Password',
                                obscure: _obscure,
                                suffix: IconButton(
                                  tooltip: _obscure ? 'Mostrar' : 'Ocultar',
                                  onPressed: () => setState(() => _obscure = !_obscure),
                                  icon: Icon(
                                    _obscure ? Icons.visibility : Icons.visibility_off,
                                  ),
                                ),
                                validator: (v) => (v == null || v.isEmpty)
                                    ? 'Ingresa tu contraseña'
                                    : null,
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const Icon(Icons.info_outline, size: 16),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Este login es decorativo. Al continuar, se abre la ventana principal.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              SizedBox(
                                width: double.infinity,
                                height: 44,
                                child: ElevatedButton(
                                  onPressed: _loading ? null : _fakeLogin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: btn,
                                    foregroundColor: Colors.black87,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 6,
                                    shadowColor: const Color(0xFF0F0B18),
                                  ),
                                  child: _loading
                                      ? const SizedBox(
                                          height: 22, width: 22,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Text(
                                          'Iniciar sesión',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '¿No tienes cuenta?',
                                    style: TextStyle(color: Colors.grey[700]),
                                  ),
                                  TextButton(
                                    onPressed: () {}, // decorativo
                                    child: const Text('Crear una'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ====== Widgets y decoraciones ======

class _Input extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _Input({
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.suffix,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(boxShadow: [
        BoxShadow(color: Colors.black26, offset: Offset(0, 2), blurRadius: 6),
      ]),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          suffixIcon: suffix,
        ),
      ),
    );
  }
}

class _AvatarCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
      decoration: BoxDecoration(
        color: Colors.lightBlue[50],
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black26, offset: Offset(0, 6), blurRadius: 16),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Si tienes un avatar animado, podrías usarlo aquí.
          // Para mantenerlo autónomo, muestro un círculo con “🐢”.
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: Colors.lightBlue.shade100, width: 6),
            ),
            alignment: Alignment.center,
            child: const Text('🐢', style: TextStyle(fontSize: 64)),
          ),
          const SizedBox(height: 12),
          const Text(
            'Bienvenida a CoralIA',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Tu espacio seguro. Al iniciar sesión entrarás a la ventana principal.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[800]),
          ),
        ],
      ),
    );
  }
}

class _SoftBubbles extends CustomPainter {
  final Color color;
  _SoftBubbles({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..style = PaintingStyle.fill..color = color.withOpacity(.35);
    // Burbujas suaves
    canvas.drawCircle(Offset(size.width * .15, size.height * .25), 120, p);
    canvas.drawCircle(Offset(size.width * .92, size.height * .15), 90, p);
    canvas.drawCircle(Offset(size.width * .80, size.height * .85), 140, p);
    canvas.drawCircle(Offset(size.width * .20, size.height * .80), 70, p..color = color.withOpacity(.25));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
