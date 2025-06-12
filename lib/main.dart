import 'package:flutter/material.dart';
import 'screens/inicio_page.dart';

void main() {
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
