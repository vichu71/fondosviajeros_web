import 'package:json_annotation/json_annotation.dart';
import 'base_model.dart';

part 'usuario.g.dart';

@JsonSerializable()
class Usuario implements BaseModel {
  int id;
  String nombre;

  // ✅ ACTUALIZADO: Rol ahora es opcional porque depende del contexto del fondo
  String? rol;

  // ✅ ACTUALIZADO: Avatar sigue siendo opcional (base64 desde backend)
  String? avatar;

  // ✅ NUEVO: UUID del dispositivo (puede venir del backend)
  String? uuidDispositivo;

  Usuario({
    required this.id,
    required this.nombre,
    this.rol,  // ← Ahora opcional
    this.avatar,
    this.uuidDispositivo,
  });

  UsuarioEditable editableWith({
    int? id,
    String? nombre,
    String? rol,
    String? avatar,
    String? uuidDispositivo,
  }) =>
      UsuarioEditable(
        id: id ?? this.id,
        nombre: nombre ?? this.nombre,
        rol: rol ?? this.rol,
        avatar: avatar ?? this.avatar,
        uuidDispositivo: uuidDispositivo ?? this.uuidDispositivo,
      );

  factory Usuario.fromJson(Map<String, dynamic>? json) =>
      _$UsuarioFromJson(json!);
  Map<String, dynamic> toJson() => _$UsuarioToJson(this);

  @override
  bool operator ==(Object other) => other is Usuario && other.id == id;
  @override
  int get hashCode => id.hashCode;

  // ✅ NUEVO: Métodos de conveniencia para trabajar con roles
  bool get esAdmin => rol?.toUpperCase() == 'ADMIN';
  bool get esUser => rol?.toUpperCase() == 'USER';
  bool get tieneRol => rol != null && rol!.isNotEmpty;
}

@JsonSerializable()
class UsuarioEditable {
  int? id;
  String? nombre;
  String? rol;
  String? avatar;
  String? uuidDispositivo;

  UsuarioEditable({
    this.id,
    this.nombre,
    this.rol,
    this.avatar,
    this.uuidDispositivo,
  });

  factory UsuarioEditable.fromJson(Map<String, dynamic>? json) =>
      _$UsuarioEditableFromJson(json!);
  Map<String, dynamic> toJson() => _$UsuarioEditableToJson(this);
}

@JsonSerializable()
class UsuarioPage {
  List<Usuario> content;
  bool last;
  int totalElements;
  int totalPages;
  bool first;
  int size;
  int number;
  bool empty;

  UsuarioPage({
    required this.content,
    required this.last,
    required this.totalElements,
    required this.totalPages,
    required this.first,
    required this.size,
    required this.number,
    required this.empty,
  });

  factory UsuarioPage.fromJson(Map<String, dynamic>? json) =>
      _$UsuarioPageFromJson(json!);
  Map<String, dynamic> toJson() => _$UsuarioPageToJson(this);
}