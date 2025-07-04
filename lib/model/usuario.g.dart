// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'usuario.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Usuario _$UsuarioFromJson(Map<String, dynamic> json) => Usuario(
      id: (json['id'] as num).toInt(),
      nombre: json['nombre'] as String,
      rol: json['rol'] as String?,
      avatar: json['avatar'] as String?,
      uuidDispositivo: json['uuidDispositivo'] as String?,
    );

Map<String, dynamic> _$UsuarioToJson(Usuario instance) => <String, dynamic>{
      'id': instance.id,
      'nombre': instance.nombre,
      'rol': instance.rol,
      'avatar': instance.avatar,
      'uuidDispositivo': instance.uuidDispositivo,
    };

UsuarioEditable _$UsuarioEditableFromJson(Map<String, dynamic> json) =>
    UsuarioEditable(
      id: (json['id'] as num?)?.toInt(),
      nombre: json['nombre'] as String?,
      rol: json['rol'] as String?,
      avatar: json['avatar'] as String?,
      uuidDispositivo: json['uuidDispositivo'] as String?,
    );

Map<String, dynamic> _$UsuarioEditableToJson(UsuarioEditable instance) =>
    <String, dynamic>{
      'id': instance.id,
      'nombre': instance.nombre,
      'rol': instance.rol,
      'avatar': instance.avatar,
      'uuidDispositivo': instance.uuidDispositivo,
    };

UsuarioPage _$UsuarioPageFromJson(Map<String, dynamic> json) => UsuarioPage(
      content: (json['content'] as List<dynamic>)
          .map((e) => Usuario.fromJson(e as Map<String, dynamic>?))
          .toList(),
      last: json['last'] as bool,
      totalElements: (json['totalElements'] as num).toInt(),
      totalPages: (json['totalPages'] as num).toInt(),
      first: json['first'] as bool,
      size: (json['size'] as num).toInt(),
      number: (json['number'] as num).toInt(),
      empty: json['empty'] as bool,
    );

Map<String, dynamic> _$UsuarioPageToJson(UsuarioPage instance) =>
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
