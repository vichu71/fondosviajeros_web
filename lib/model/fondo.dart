import 'package:json_annotation/json_annotation.dart';
import 'base_model.dart';

part 'fondo.g.dart';

@JsonSerializable()
class Fondo implements BaseModel {
  int? id;
  String nombre;
  String codigo;
  DateTime? fechaCreacion;
  String monto;

  Fondo({
    this.id,
    required this.nombre,
    required this.codigo,
    this.fechaCreacion,
    required this.monto,
  });

  FondoEditable editableWith({
    int? id,
    String? nombre,
    String? codigo,
    DateTime? fechaCreacion,
  }) =>
      FondoEditable(
        id: id ?? this.id,
        nombre: nombre ?? this.nombre,
        codigo: codigo ?? this.codigo,
        fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      );

  factory Fondo.fromJson(Map<String, dynamic> json) => _$FondoFromJson(json);
  Map<String, dynamic> toJson() => _$FondoToJson(this);

  @override
  bool operator ==(Object other) => other is Fondo && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

@JsonSerializable()
class FondoEditable {
  int? id;
  String? nombre;
  String? codigo;
  DateTime? fechaCreacion;
  String? monto;

  FondoEditable({
    this.id,
    this.nombre,
    this.codigo,
    this.fechaCreacion,
    this.monto,
  });

  factory FondoEditable.fromJson(Map<String, dynamic> json) =>
      _$FondoEditableFromJson(json);
  Map<String, dynamic> toJson() => _$FondoEditableToJson(this);
}

@JsonSerializable()
class FondoPage {
  List<Fondo> content;
  bool last;
  int totalElements;
  int totalPages;
  bool first;
  int size;
  int number;
  bool empty;

  FondoPage({
    required this.content,
    required this.last,
    required this.totalElements,
    required this.totalPages,
    required this.first,
    required this.size,
    required this.number,
    required this.empty,
  });

  factory FondoPage.fromJson(Map<String, dynamic> json) =>
      _$FondoPageFromJson(json);
  Map<String, dynamic> toJson() => _$FondoPageToJson(this);
}
