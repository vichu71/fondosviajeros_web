// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fondo_con_rol.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FondoConRol _$FondoConRolFromJson(Map<String, dynamic> json) => FondoConRol(
      id: (json['id'] as num?)?.toInt(),
      nombre: json['nombre'] as String,
      codigo: json['codigo'] as String,
      fechaCreacion: json['fechaCreacion'] == null
          ? null
          : DateTime.parse(json['fechaCreacion'] as String),
      monto: json['monto'] as String,
      rolUsuario: json['rolUsuario'] as String,
    );

Map<String, dynamic> _$FondoConRolToJson(FondoConRol instance) =>
    <String, dynamic>{
      'id': instance.id,
      'nombre': instance.nombre,
      'codigo': instance.codigo,
      'fechaCreacion': instance.fechaCreacion?.toIso8601String(),
      'monto': instance.monto,
      'rolUsuario': instance.rolUsuario,
    };

FondoConRolPage _$FondoConRolPageFromJson(Map<String, dynamic> json) =>
    FondoConRolPage(
      content: (json['content'] as List<dynamic>)
          .map((e) => FondoConRol.fromJson(e as Map<String, dynamic>))
          .toList(),
      last: json['last'] as bool,
      totalElements: (json['totalElements'] as num).toInt(),
      totalPages: (json['totalPages'] as num).toInt(),
      first: json['first'] as bool,
      size: (json['size'] as num).toInt(),
      number: (json['number'] as num).toInt(),
      empty: json['empty'] as bool,
    );

Map<String, dynamic> _$FondoConRolPageToJson(FondoConRolPage instance) =>
    <String, dynamic>{
      'content': instance.content,
      'last': instance.last,
      'totalElements': instance.totalElements,
      'totalPages': instance.totalPages,
      'first': instance.first,
      'size': instance.size,
      'number': instance.number,
      'empty': instance.empty,
    };
