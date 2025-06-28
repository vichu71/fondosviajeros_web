// model/unirse_fondo_request.dart
class UnirseFondoRequest {
  final String nombreUsuario;
  final String codigoFondo;
  final String uuidDispositivo;

  UnirseFondoRequest({
    required this.nombreUsuario,
    required this.codigoFondo,
    required this.uuidDispositivo,
  });

  Map<String, dynamic> toJson() {
    return {
      'nombreUsuario': nombreUsuario,
      'codigoFondo': codigoFondo,
      'uuidDispositivo': uuidDispositivo,
    };
  }

  @override
  String toString() {
    return 'UnirseFondoRequest(nombreUsuario: $nombreUsuario, codigoFondo: $codigoFondo, uuidDispositivo: $uuidDispositivo)';
  }
}