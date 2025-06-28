import 'package:fondosviajeros_web/model/usuario.dart';
import 'package:json_annotation/json_annotation.dart';
import 'base_model.dart';
import 'fondo.dart';

part 'movimiento.g.dart';

@JsonSerializable()
class Movimiento implements BaseModel {
  int id;
  String concepto;
  String tipo;
  double cantidad;
  DateTime fecha;
  Usuario usuario;
  Fondo fondo;

  Movimiento({
    required this.id,
    required this.concepto,
    required this.cantidad,
    required this.fecha,
    required this.usuario,
    required this.fondo,
    required this.tipo,
  });

  MovimientoEditable editableWith({
    int? id,
    String? concepto,
    double? cantidad,
    DateTime? fecha,
    Usuario? usuario,
    Fondo? fondo,
    String? tipo,
  }) =>
      MovimientoEditable(
        id: id ?? this.id,
        concepto: concepto ?? this.concepto,
        cantidad: cantidad ?? this.cantidad,
        fecha: fecha ?? this.fecha,
        usuario: usuario ?? this.usuario,
        fondo: fondo ?? this.fondo,
        tipo: tipo ?? this.tipo,
      );

  factory Movimiento.fromJson(Map<String, dynamic> json) =>
      _$MovimientoFromJson(json);
  Map<String, dynamic> toJson() => _$MovimientoToJson(this);

  @override
  bool operator ==(Object other) => other is Movimiento && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

@JsonSerializable()
class MovimientoEditable {
  int? id;
  String? concepto;
  double? cantidad;
  DateTime? fecha;
  Usuario? usuario;
  Fondo? fondo;
  String? tipo;

  MovimientoEditable({
    this.id,
    this.concepto,
    this.cantidad,
    this.fecha,
    this.usuario,
    this.fondo,
    this.tipo,
  });

  factory MovimientoEditable.fromJson(Map<String, dynamic> json) =>
      _$MovimientoEditableFromJson(json);
  Map<String, dynamic> toJson() => _$MovimientoEditableToJson(this);
}

@JsonSerializable()
class MovimientoPage {
  List<Movimiento> content;
  bool last;
  int totalElements;
  int totalPages;
  bool first;
  int size;
  int number;
  bool empty;

  MovimientoPage({
    required this.content,
    required this.last,
    required this.totalElements,
    required this.totalPages,
    required this.first,
    required this.size,
    required this.number,
    required this.empty,
  });

  factory MovimientoPage.fromJson(Map<String, dynamic> json) =>
      _$MovimientoPageFromJson(json);
  Map<String, dynamic> toJson() => _$MovimientoPageToJson(this);
}
