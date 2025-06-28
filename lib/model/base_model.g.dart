// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'base_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MockModel _$MockModelFromJson(Map<String, dynamic> json) => MockModel();

Map<String, dynamic> _$MockModelToJson(MockModel instance) =>
    <String, dynamic>{};

Error _$ErrorFromJson(Map<String, dynamic> json) => Error(
      errorMessage: json['errorMessage'] as String? ?? '',
      apiError: json['apiError'] as bool? ?? false,
    );

Map<String, dynamic> _$ErrorToJson(Error instance) => <String, dynamic>{
      'apiError': instance.apiError,
      'errorMessage': instance.errorMessage,
    };

StringModel _$StringModelFromJson(Map<String, dynamic> json) => StringModel(
      data: json['data'] as String,
    );

Map<String, dynamic> _$StringModelToJson(StringModel instance) =>
    <String, dynamic>{
      'data': instance.data,
    };
