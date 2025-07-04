import 'package:flutter/material.dart';
import 'screens/inicio_page.dart';

void main() {
const apiUrl1 = String.fromEnvironment('DART_DEFINE_API_URL', defaultValue: 'NO DEFINIDO');
  const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'NO DEFINIDO');
  print('🌐 API_URL activo: $apiUrl');
    print('🌐 API_URL1 activo: $apiUrl1');
  runApp(const FondosViajerosApp());
}


class FondosViajerosApp extends StatelessWidget {
  const FondosViajerosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fondos Viajeros',
      theme: ThemeData.dark(),
      home: const InicioPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
