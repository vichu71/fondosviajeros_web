import 'package:json_annotation/json_annotation.dart';
import 'base_model.dart';
import 'fondo.dart';

part 'fondo_con_rol.g.dart';

@JsonSerializable()
class FondoConRol implements BaseModel {
  int? id;
  String nombre;
  String codigo;
  DateTime? fechaCreacion;
  String monto;
  String rolUsuario; // ← NUEVO: Rol del usuario en este fondo específico

  FondoConRol({
    this.id,
    required this.nombre,
    required this.codigo,
    this.fechaCreacion,
    required this.monto,
    required this.rolUsuario,
  });

  // Métodos de conveniencia para trabajar con roles
  bool get esAdmin => rolUsuario.toUpperCase() == 'ADMIN';
  bool get esUser => rolUsuario.toUpperCase() == 'USER';

  // Conversión a Fondo normal (para compatibilidad)
  Fondo toFondo() {
    return Fondo(
      id: id,
      nombre: nombre,
      codigo: codigo,
      fechaCreacion: fechaCreacion,
      monto: monto,
    );
  }

  factory FondoConRol.fromJson(Map<String, dynamic> json) => _$FondoConRolFromJson(json);
  Map<String, dynamic> toJson() => _$FondoConRolToJson(this);

  @override
  bool operator ==(Object other) => other is FondoConRol && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

@JsonSerializable()
class FondoConRolPage {
  List<FondoConRol> content;
  bool last;
  int totalElements;
  int totalPages;
  bool first;
  int size;
  int number;
  bool empty;

  FondoConRolPage({
    required this.content,
    required this.last,
    required this.totalElements,
    required this.totalPages,
    required this.first,
    required this.size,
    required this.number,
    required this.empty,
  });

  factory FondoConRolPage.fromJson(Map<String, dynamic> json) =>
      _$FondoConRolPageFromJson(json);
  Map<String, dynamic> toJson() => _$FondoConRolPageToJson(this);
}