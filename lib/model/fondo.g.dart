// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fondo.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Fondo _$FondoFromJson(Map<String, dynamic> json) => Fondo(
      id: (json['id'] as num?)?.toInt(),
      nombre: json['nombre'] as String,
      codigo: json['codigo'] as String,
      fechaCreacion: json['fechaCreacion'] == null
          ? null
          : DateTime.parse(json['fechaCreacion'] as String),
      monto: json['monto'] as String,
    );

Map<String, dynamic> _$FondoToJson(Fondo instance) => <String, dynamic>{
      'id': instance.id,
      'nombre': instance.nombre,
      'codigo': instance.codigo,
      'fechaCreacion': instance.fechaCreacion?.toIso8601String(),
      'monto': instance.monto,
    };

FondoEditable _$FondoEditableFromJson(Map<String, dynamic> json) =>
    FondoEditable(
      id: (json['id'] as num?)?.toInt(),
      nombre: json['nombre'] as String?,
      codigo: json['codigo'] as String?,
      fechaCreacion: json['fechaCreacion'] == null
          ? null
          : DateTime.parse(json['fechaCreacion'] as String),
      monto: json['monto'] as String?,
    );

Map<String, dynamic> _$FondoEditableToJson(FondoEditable instance) =>
    <String, dynamic>{
      'id': instance.id,
      'nombre': instance.nombre,
      'codigo': instance.codigo,
      'fechaCreacion': instance.fechaCreacion?.toIso8601String(),
      'monto': instance.monto,
    };

FondoPage _$FondoPageFromJson(Map<String, dynamic> json) => FondoPage(
      content: (json['content'] as List<dynamic>)
          .map((e) => Fondo.fromJson(e as Map<String, dynamic>))
          .toList(),
      last: json['last'] as bool,
      totalElements: (json['totalElements'] as num).toInt(),
      totalPages: (json['totalPages'] as num).toInt(),
      first: json['first'] as bool,
      size: (json['size'] as num).toInt(),
      number: (json['number'] as num).toInt(),
      empty: json['empty'] as bool,
    );

Map<String, dynamic> _$FondoPageToJson(FondoPage instance) => <String, dynamic>{
      'content': instance.content,
      'last': instance.last,
      'totalElements': instance.totalElements,
      'totalPages': instance.totalPages,
      'first': instance.first,
      'size': instance.size,
      'number': instance.number,
      'empty': instance.empty,
    };
