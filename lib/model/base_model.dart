import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';

part 'base_model.g.dart';

abstract class BaseModel {
  dynamic toJson();
}

abstract class BaseFilter implements BaseModel {}

abstract class Page<T> implements BaseModel{
  bool last;
  int totalElements;
  int totalPages;
  bool first;
  int size;
  int number;
  bool empty;
  List<T> get content;
  Page({
    required this.last,
    required this.totalElements,
    required this.totalPages,
    required this.first,
    required this.size,
    required this.number,
    required this.empty
  });
}

@JsonSerializable()
class MockModel implements BaseModel {
  static const instance = MockModel();
  const MockModel();
  factory MockModel.fromJson(Map<String, dynamic>? json) => _$MockModelFromJson(json!);
  @override
  Map<String, dynamic> toJson() => _$MockModelToJson(this);
}

@JsonSerializable()
class Error implements BaseModel {
  final bool? apiError;
  @JsonKey(defaultValue: '')
  final String errorMessage;
  @JsonKey(ignore: true)
  late int statusCode;

  Error({ required this.errorMessage, this.apiError = false, this.statusCode = 0 }) ;

  factory Error.fromJson(Map<String, dynamic>? json, int statusCode) => _$ErrorFromJson(json!)..statusCode = statusCode;
  @override Map<String, dynamic> toJson() => _$ErrorToJson(this);

  @override
  String toString() => '$statusCode - $errorMessage [api: ${apiError ?? 'null'}]';

}

@JsonSerializable()
class StringModel implements BaseModel {

  final String data;

  StringModel({ required this.data });

  @override dynamic toJson() => jsonDecode(data);
  factory StringModel.fromJson(Map<String, dynamic>? json) => _$StringModelFromJson(json!);

}
