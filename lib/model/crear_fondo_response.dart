import 'package:fondosviajeros_web/model/usuario.dart';

import 'fondo.dart';

class CrearFondoResponse {
  final Fondo fondo;
  final Usuario usuario;
  final String mensaje;

  CrearFondoResponse({
    required this.fondo,
    required this.usuario,
    this.mensaje = 'Fondo creado exitosamente',
  });

  factory CrearFondoResponse.fromJson(Map<String, dynamic> json) {
    return CrearFondoResponse(
      fondo: Fondo.fromJson(json['fondo']),
      usuario: Usuario.fromJson(json['usuario']),
      mensaje: json['mensaje'] ?? 'Fondo creado exitosamente',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fondo': fondo.toJson(),
      'usuario': usuario.toJson(),
      'mensaje': mensaje,
    };
  }

  @override
  String toString() {
    return 'CrearFondoResponse(fondo: $fondo, usuario: $usuario, mensaje: $mensaje)';
  }
}