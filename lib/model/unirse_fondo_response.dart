// model/unirse_fondo_response.dart
import 'usuario.dart';
import 'fondo.dart';

class UnirseFondoResponse {
  final Usuario usuario;
  final Fondo fondo;
  final String mensaje;

  UnirseFondoResponse({
    required this.usuario,
    required this.fondo,
    this.mensaje = 'Usuario unido exitosamente al fondo',
  });

  factory UnirseFondoResponse.fromJson(Map<String, dynamic> json) {
    return UnirseFondoResponse(
      usuario: Usuario.fromJson(json['usuario']),
      fondo: Fondo.fromJson(json['fondo']),
      mensaje: json['mensaje'] ?? 'Usuario unido exitosamente al fondo',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'usuario': usuario.toJson(),
      'fondo': fondo.toJson(),
      'mensaje': mensaje,
    };
  }

  @override
  String toString() {
    return 'UnirseFondoResponse(usuario: $usuario, fondo: $fondo, mensaje: $mensaje)';
  }
}