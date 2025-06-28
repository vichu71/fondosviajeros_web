// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'movimiento.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Movimiento _$MovimientoFromJson(Map<String, dynamic> json) => Movimiento(
      id: (json['id'] as num).toInt(),
      concepto: json['concepto'] as String,
      cantidad: (json['cantidad'] as num).toDouble(),
      fecha: DateTime.parse(json['fecha'] as String),
      usuario: Usuario.fromJson(json['usuario'] as Map<String, dynamic>?),
      fondo: Fondo.fromJson(json['fondo'] as Map<String, dynamic>),
      tipo: json['tipo'] as String,
    );

Map<String, dynamic> _$MovimientoToJson(Movimiento instance) =>
    <String, dynamic>{
      'id': instance.id,
      'concepto': instance.concepto,
      'tipo': instance.tipo,
      'cantidad': instance.cantidad,
      'fecha': instance.fecha.toIso8601String(),
      'usuario': instance.usuario,
      'fondo': instance.fondo,
    };

MovimientoEditable _$MovimientoEditableFromJson(Map<String, dynamic> json) =>
    MovimientoEditable(
      id: (json['id'] as num?)?.toInt(),
      concepto: json['concepto'] as String?,
      cantidad: (json['cantidad'] as num?)?.toDouble(),
      fecha: json['fecha'] == null
          ? null
          : DateTime.parse(json['fecha'] as String),
      usuario: json['usuario'] == null
          ? null
          : Usuario.fromJson(json['usuario'] as Map<String, dynamic>?),
      fondo: json['fondo'] == null
          ? null
          : Fondo.fromJson(json['fondo'] as Map<String, dynamic>),
      tipo: json['tipo'] as String?,
    );

Map<String, dynamic> _$MovimientoEditableToJson(MovimientoEditable instance) =>
    <String, dynamic>{
      'id': instance.id,
      'concepto': instance.concepto,
      'cantidad': instance.cantidad,
      'fecha': instance.fecha?.toIso8601String(),
      'usuario': instance.usuario,
      'fondo': instance.fondo,
      'tipo': instance.tipo,
    };

MovimientoPage _$MovimientoPageFromJson(Map<String, dynamic> json) =>
    MovimientoPage(
      content: (json['content'] as List<dynamic>)
          .map((e) => Movimiento.fromJson(e as Map<String, dynamic>))
          .toList(),
      last: json['last'] as bool,
      totalElements: (json['totalElements'] as num).toInt(),
      totalPages: (json['totalPages'] as num).toInt(),
      first: json['first'] as bool,
      size: (json['size'] as num).toInt(),
      number: (json['number'] as num).toInt(),
      empty: json['empty'] as bool,
    );

Map<String, dynamic> _$MovimientoPageToJson(MovimientoPage instance) =>
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
