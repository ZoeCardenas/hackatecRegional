import 'package:flutter/material.dart';

// Importa tus páginas
import '../pages/login_page.dart';
import '../pages/first.dart';
import '../pages/prueba.dart';
import '../pages/register_page.dart';
import '../pages/seguimiento_page.dart';
import '../pages/historial_page.dart';
import '../pages/cercademi.dart';
import '../pages/rescupera_pass.dart';

class AppRoutes {
  static const String login = '/login';
  static const String first = '/first';
  static const String prueba = '/prueba';
  static const String register = '/register';
  static const String seguimiento = '/seguimiento';
  static const String historial = '/historial';
  static const String cercademi = '/cercademi';
  static const String recuperaPass = '/recuperaPass';

  static Map<String, WidgetBuilder> routes = {
    login: (context) => const LoginPage(),
    first: (context) => const First(),
    prueba: (context) => const Prueba(),
    register: (context) => const RegisterPage(),
    seguimiento: (context) => const SeguimientoPage(),
    historial: (context) => const HistorialClinicoPage(),
    cercademi: (context) => const CercaDeMiPage(),
    recuperaPass: (context) => const RescuperaPass(),
  };
}
