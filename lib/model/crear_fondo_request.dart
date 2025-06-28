class CrearFondoRequest {
  final String nombreUsuario;
  final String nombreFondo;
  final String uuidDispositivo;

  CrearFondoRequest({
    required this.nombreUsuario,
    required this.nombreFondo,
    required this.uuidDispositivo,
  });

  Map<String, dynamic> toJson() {
    return {
      'nombreUsuario': nombreUsuario,
      'nombreFondo': nombreFondo,
      'uuidDispositivo': uuidDispositivo,
    };
  }
}
