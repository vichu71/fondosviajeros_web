import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import '../model/crear_fondo_request.dart';
import '../model/crear_fondo_response.dart';
import '../model/unirse_fondo_request.dart';
import '../model/unirse_fondo_response.dart';
import '../model/fondo.dart';
import '../model/movimiento.dart';
import '../model/usuario.dart';
import 'api_client.dart';
import '../utils/logger.dart';
import '../model/fondo_con_rol.dart';

class ApiService {
  final String baseUrl = '${const String.fromEnvironment('API_URL')}/fondos'; // Quitamos /fondos

  late Dio _dio;

  ApiService() {
    _dio = ApiClient.createDio();
    log('ApiService inicializado con baseUrl: $baseUrl', type: LogType.info);
  }

  // Método para obtener el token
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    log('Token obtenido: ${token != null ? "✅ Existe" : "❌ No existe"}', type: LogType.info);
    return token;
  }

  // Método para guardar el token
  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    log('Token guardado exitosamente', type: LogType.success);
  }

  // Método para guardar el usuario
  Future<void> saveUser(Usuario user) async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = jsonEncode(user.toJson());
    await prefs.setString('user', userJson);
    log('Usuario guardado: ${user.nombre} (ID: ${user.id})', type: LogType.success);
    log('JSON guardado: $userJson', type: LogType.info);
  }
// Método unificado para obtener el usuario actual de cualquier fuente
  Future<Usuario?> getCurrentUser() async {
    try {
      // 1. Intentar obtener de la caché (método getUser existente)
      Usuario? usuario = await getUser();

      if (usuario != null) {
        log('👤 Usuario obtenido de caché: ${usuario.nombre}', type: LogType.info);
        return usuario;
      }

      // 2. Si no está en caché, buscar en userData (como en inicio_page)
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('userData');

      if (userDataString != null) {
        log('👤 Usuario encontrado en userData, obteniendo detalles...', type: LogType.info);

        final userData = jsonDecode(userDataString);
        final userId = int.parse(userData['userId']);

        // 3. Obtener usuario completo del API
        usuario = await getUsuarioById(userId);

        // 4. Guardar en caché para próximas veces
        await saveUser(usuario);

        log('✅ Usuario cargado y guardado en caché: ${usuario.nombre}', type: LogType.success);
        return usuario;
      }

      log('⚠️ No se encontró usuario en ninguna fuente', type: LogType.warning);
      return null;

    } catch (e) {
      log('💥 Error en getCurrentUser: $e', type: LogType.error);
      return null;
    }
  }
  // Método para obtener el usuario
  Future<Usuario?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final String? userJson = prefs.getString('user');

    if (userJson != null) {
      try {
        final usuario = Usuario.fromJson(jsonDecode(userJson));
        log('Usuario recuperado: ${usuario.nombre} (ID: ${usuario.id})', type: LogType.success);
        return usuario;
      } catch (e) {
        log('Error al decodificar usuario: $e', type: LogType.error);
        return null;
      }
    } else {
      log('No hay usuario guardado', type: LogType.warning);
      return null;
    }
  }

  Future<List<Usuario>> getUsuarios() async {
    final url = Uri.parse('$baseUrl/api/usuarios');
    log('🚀 [GET] Solicitando usuarios desde: $url', type: LogType.api);

    try {
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
      });

      log('📥 [RESPONSE] Status: ${response.statusCode}', type: LogType.api);
      log('📥 [RESPONSE] Headers: ${response.headers}', type: LogType.info);
      log('📥 [RESPONSE] Body: ${response.body}', type: LogType.api);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final usuarios = data.map((json) => Usuario.fromJson(json)).toList();

        log('✅ Usuarios decodificados exitosamente: ${usuarios.length} usuarios', type: LogType.success);
        for (final u in usuarios) {
          log('👤 Usuario: ID=${u.id}, Nombre=${u.nombre}, Rol=${u.rol}', type: LogType.info);
        }

        return usuarios;
      } else {
        log('❌ Error en respuesta: ${response.statusCode} - ${response.body}', type: LogType.error);
        throw Exception('Error al obtener usuarios: ${response.statusCode}');
      }
    } catch (e) {
      log('💥 Excepción en getUsuarios: $e', type: LogType.error);
      throw Exception('Error de red al obtener usuarios: $e');
    }
  }

  Future<Usuario> getUsuarioById(int id) async {
    final url = Uri.parse('$baseUrl/api/usuarios/$id');
    log('🚀 [GET] Solicitando usuario por ID: $url', type: LogType.api);

    try {
      final response = await http.get(url);

      log('📥 [RESPONSE] Status: ${response.statusCode}', type: LogType.api);
      log('📥 [RESPONSE] Body: ${response.body}', type: LogType.api);

      if (response.statusCode == 200) {
        final usuario = Usuario.fromJson(jsonDecode(response.body));
        log('✅ Usuario obtenido: ${usuario.nombre} (ID: ${usuario.id})', type: LogType.success);
        return usuario;
      } else {
        log('❌ Error al obtener usuario: ${response.statusCode} - ${response.body}', type: LogType.error);
        throw Exception('Error al obtener usuario con ID $id');
      }
    } catch (e) {
      log('💥 Excepción en getUsuarioById: $e', type: LogType.error);
      throw Exception('Error de red al obtener usuario: $e');
    }
  }

  Future<Usuario> crearUsuario(UsuarioEditable usuario) async {
    final url = Uri.parse('$baseUrl/api/usuarios');
    final body = jsonEncode(usuario.toJson());

    log('🚀 [POST] Creando usuario: $url', type: LogType.api);
    log('📤 [REQUEST] Body: $body', type: LogType.api);

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      log('📥 [RESPONSE] Status: ${response.statusCode}', type: LogType.api);
      log('📥 [RESPONSE] Body: ${response.body}', type: LogType.api);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final usuarioCreado = Usuario.fromJson(jsonDecode(response.body));
        log('✅ Usuario creado exitosamente: ${usuarioCreado.nombre} (ID: ${usuarioCreado.id})', type: LogType.success);
        return usuarioCreado;
      } else {
        log('❌ Error al crear usuario: ${response.statusCode} - ${response.body}', type: LogType.error);
        throw Exception('Error al crear usuario: ${response.statusCode}');
      }
    } catch (e) {
      log('💥 Excepción en crearUsuario: $e', type: LogType.error);
      throw Exception('Error de red al crear usuario: $e');
    }
  }

  Future<Usuario> actualizarUsuario(int id, UsuarioEditable usuario) async {
    final url = Uri.parse('$baseUrl/api/usuarios/$id');
    final body = jsonEncode(usuario.toJson());

    log('🚀 [PUT] Actualizando usuario: $url', type: LogType.api);
    log('📤 [REQUEST] Body: $body', type: LogType.api);

    try {
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      log('📥 [RESPONSE] Status: ${response.statusCode}', type: LogType.api);
      log('📥 [RESPONSE] Body: ${response.body}', type: LogType.api);

      if (response.statusCode == 200) {
        final usuarioActualizado = Usuario.fromJson(jsonDecode(response.body));
        log('✅ Usuario actualizado: ${usuarioActualizado.nombre} (ID: ${usuarioActualizado.id})', type: LogType.success);
        return usuarioActualizado;
      } else {
        log('❌ Error al actualizar usuario: ${response.statusCode} - ${response.body}', type: LogType.error);
        throw Exception('Error al actualizar usuario: ${response.statusCode}');
      }
    } catch (e) {
      log('💥 Excepción en actualizarUsuario: $e', type: LogType.error);
      throw Exception('Error de red al actualizar usuario: $e');
    }
  }

  Future<void> eliminarUsuario(int id) async {
    final url = Uri.parse('$baseUrl/api/usuarios/$id');
    log('🚀 [DELETE] Eliminando usuario: $url', type: LogType.api);

    try {
      final response = await http.delete(url);

      log('📥 [RESPONSE] Status: ${response.statusCode}', type: LogType.api);
      log('📥 [RESPONSE] Body: ${response.body}', type: LogType.api);

      if (response.statusCode == 200) {
        log('✅ Usuario eliminado exitosamente (ID: $id)', type: LogType.success);
      } else {
        log('❌ Error al eliminar usuario: ${response.statusCode} - ${response.body}', type: LogType.error);
        throw Exception('Error al eliminar usuario con ID $id');
      }
    } catch (e) {
      log('💥 Excepción en eliminarUsuario: $e', type: LogType.error);
      throw Exception('Error de red al eliminar usuario: $e');
    }
  }



  // =========================
  // FONDOS - CRUD
  // =========================

  Future<List<Fondo>> getFondos() async {
    final url = Uri.parse('$baseUrl/api/fondos');
    log('🚀 [GET] Solicitando fondos: $url', type: LogType.api);

    try {
      final response = await http.get(url);

      log('📥 [RESPONSE] Status: ${response.statusCode}', type: LogType.api);
      log('📥 [RESPONSE] Body: ${response.body}', type: LogType.api);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final fondos = data.map((json) => Fondo.fromJson(json)).toList();

        log('✅ Fondos obtenidos exitosamente: ${fondos.length} fondos', type: LogType.success);
        for (final f in fondos) {
          log('💰 Fondo: ID=${f.id}, Nombre=${f.nombre}, Código=${f.codigo}, Monto=${f.monto}', type: LogType.info);
        }

        return fondos;
      } else {
        log('❌ Error al obtener fondos: ${response.statusCode} - ${response.body}', type: LogType.error);
        throw Exception('Error al obtener fondos');
      }
    } catch (e) {
      log('💥 Excepción en getFondos: $e', type: LogType.error);
      throw Exception('Error de red al obtener fondos: $e');
    }
  }

  Future<Fondo> getFondoById(int id) async {
    final url = Uri.parse('$baseUrl/api/fondos/$id');
    log('🚀 [GET] Solicitando fondo por ID: $url', type: LogType.api);

    try {
      final response = await http.get(url);

      log('📥 [RESPONSE] Status: ${response.statusCode}', type: LogType.api);
      log('📥 [RESPONSE] Body: ${response.body}', type: LogType.api);

      if (response.statusCode == 200) {
        final fondo = Fondo.fromJson(jsonDecode(response.body));
        log('✅ Fondo obtenido: ${fondo.nombre} (ID: ${fondo.id})', type: LogType.success);
        return fondo;
      } else {
        log('❌ Error al obtener fondo: ${response.statusCode} - ${response.body}', type: LogType.error);
        throw Exception('Error al obtener fondo con ID $id');
      }
    } catch (e) {
      log('💥 Excepción en getFondoById: $e', type: LogType.error);
      throw Exception('Error de red al obtener fondo: $e');
    }
  }

  Future<CrearFondoResponse> crearFondo(CrearFondoRequest request) async {
    final url = Uri.parse('$baseUrl/api/fondos/crear');
    final body = jsonEncode(request.toJson());

    log('🚀 [POST] Creando fondo: $url', type: LogType.api);
    log('📤 [REQUEST] Body: $body', type: LogType.api);
    log('📤 [REQUEST] Nombre Usuario: ${request.nombreUsuario}', type: LogType.info);
    log('📤 [REQUEST] Nombre Fondo: ${request.nombreFondo}', type: LogType.info);

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      log('📥 [RESPONSE] Status: ${response.statusCode}', type: LogType.api);
      log('📥 [RESPONSE] Headers: ${response.headers}', type: LogType.info);
      log('📥 [RESPONSE] Body: ${response.body}', type: LogType.api);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        final crearFondoResponse = CrearFondoResponse.fromJson(responseData);

        log('✅ Fondo creado exitosamente!', type: LogType.success);
        log('👤 Usuario creado: ${crearFondoResponse.usuario.nombre} (ID: ${crearFondoResponse.usuario.id})', type: LogType.info);
        log('💰 Fondo creado: ${crearFondoResponse.fondo.nombre} (Código: ${crearFondoResponse.fondo.codigo})', type: LogType.info);

        return crearFondoResponse;
      } else {
        log('❌ Error al crear fondo: ${response.statusCode}', type: LogType.error);
        log('❌ Cuerpo del error: ${response.body}', type: LogType.error);
        throw Exception('Error al crear fondo: ${response.statusCode}');
      }
    } catch (e) {
      log('💥 Excepción en crearFondo: $e', type: LogType.error);
      throw Exception('Error de red al crear fondo: $e');
    }
  }

  Future<Fondo> actualizarFondo(int id, FondoEditable fondo) async {
    final url = Uri.parse('$baseUrl/api/fondos/$id');
    final body = jsonEncode(fondo.toJson());

    log('🚀 [PUT] Actualizando fondo: $url', type: LogType.api);
    log('📤 [REQUEST] Body: $body', type: LogType.api);

    try {
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      log('📥 [RESPONSE] Status: ${response.statusCode}', type: LogType.api);
      log('📥 [RESPONSE] Body: ${response.body}', type: LogType.api);

      if (response.statusCode == 200) {
        final fondoActualizado = Fondo.fromJson(jsonDecode(response.body));
        log('✅ Fondo actualizado: ${fondoActualizado.nombre} (ID: ${fondoActualizado.id})', type: LogType.success);
        return fondoActualizado;
      } else {
        log('❌ Error al actualizar fondo: ${response.statusCode} - ${response.body}', type: LogType.error);
        throw Exception('Error al actualizar fondo');
      }
    } catch (e) {
      log('💥 Excepción en actualizarFondo: $e', type: LogType.error);
      throw Exception('Error de red al actualizar fondo: $e');
    }
  }

  Future<void> eliminarFondo(int id) async {
    final url = Uri.parse('$baseUrl/api/fondos/$id');
    log('🚀 [DELETE] Eliminando fondo: $url', type: LogType.api);

    try {
      final response = await http.delete(url);

      log('📥 [RESPONSE] Status: ${response.statusCode}', type: LogType.api);
      log('📥 [RESPONSE] Body: ${response.body}', type: LogType.api);

      if (response.statusCode == 200) {
        log('✅ Fondo eliminado exitosamente (ID: $id)', type: LogType.success);
      } else {
        log('❌ Error al eliminar fondo: ${response.statusCode} - ${response.body}', type: LogType.error);
        throw Exception('Error al eliminar fondo con ID $id');
      }
    } catch (e) {
      log('💥 Excepción en eliminarFondo: $e', type: LogType.error);
      throw Exception('Error de red al eliminar fondo: $e');
    }
  }

  // =========================
  // MOVIMIENTOS - CRUD
  // =========================

  Future<List<Movimiento>> getMovimientos() async {
    final url = Uri.parse('$baseUrl/api/movimientos');
    log('🚀 [GET] Solicitando movimientos: $url', type: LogType.api);

    try {
      final response = await http.get(url);

      log('📥 [RESPONSE] Status: ${response.statusCode}', type: LogType.api);
      log('📥 [RESPONSE] Body: ${response.body}', type: LogType.api);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final movimientos = data.map((json) => Movimiento.fromJson(json)).toList();

        log('✅ Movimientos obtenidos: ${movimientos.length} movimientos', type: LogType.success);
        for (final m in movimientos) {
          log('📋 Movimiento: ID=${m.id}, Tipo=${m.tipo}', type: LogType.info);
        }

        return movimientos;
      } else {
        log('❌ Error al obtener movimientos: ${response.statusCode} - ${response.body}', type: LogType.error);
        throw Exception('Error al obtener movimientos');
      }
    } catch (e) {
      log('💥 Excepción en getMovimientos: $e', type: LogType.error);
      throw Exception('Error de red al obtener movimientos: $e');
    }
  }

  Future<Movimiento> getMovimientoById(int id) async {
    final url = Uri.parse('$baseUrl/api/movimientos/$id');
    log('🚀 [GET] Solicitando movimiento por ID: $url', type: LogType.api);

    try {
      final response = await http.get(url);

      log('📥 [RESPONSE] Status: ${response.statusCode}', type: LogType.api);
      log('📥 [RESPONSE] Body: ${response.body}', type: LogType.api);

      if (response.statusCode == 200) {
        final movimiento = Movimiento.fromJson(jsonDecode(response.body));
        log('✅ Movimiento obtenido:  (ID: ${movimiento.id})', type: LogType.success);
        return movimiento;
      } else {
        log('❌ Error al obtener movimiento: ${response.statusCode} - ${response.body}', type: LogType.error);
        throw Exception('Error al obtener movimiento con ID $id');
      }
    } catch (e) {
      log('💥 Excepción en getMovimientoById: $e', type: LogType.error);
      throw Exception('Error de red al obtener movimiento: $e');
    }
  }

  Future<Movimiento> crearMovimiento(MovimientoEditable movimiento) async {
    final url = Uri.parse('$baseUrl/api/movimientos');

    // Convertir a JSON y limpiar campos problemáticos
    final movimientoJson = movimiento.toJson();

    // Limpiar campos que pueden causar problemas en el backend
    movimientoJson.remove('id'); // No enviar ID para creación

    // Si usuario y fondo son objetos, extraer solo los IDs
    if (movimiento.usuario != null) {
      movimientoJson['usuarioId'] = movimiento.usuario!.id;
      movimientoJson.remove('usuario');
    }

    if (movimiento.fondo != null) {
      movimientoJson['fondoId'] = movimiento.fondo!.id;
      movimientoJson.remove('fondo');
    }

    final body = jsonEncode(movimientoJson);

    log('🚀 [POST] Creando movimiento: $url', type: LogType.api);
    log('📤 [REQUEST] Body: $body', type: LogType.api);

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      log('📥 [RESPONSE] Status: ${response.statusCode}', type: LogType.api);
      log('📥 [RESPONSE] Body: ${response.body}', type: LogType.api);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final movimientoCreado = Movimiento.fromJson(jsonDecode(response.body));
        log('✅ Movimiento creado:  (ID: ${movimientoCreado.id})', type: LogType.success);
        return movimientoCreado;
      } else {
        log('❌ Error al crear movimiento: ${response.statusCode} - ${response.body}', type: LogType.error);
        throw Exception('Error al crear movimiento: ${response.statusCode}');
      }
    } catch (e) {
      log('💥 Excepción en crearMovimiento: $e', type: LogType.error);
      throw Exception('Error de red al crear movimiento: $e');
    }
  }

  Future<Movimiento> actualizarMovimiento(int id, MovimientoEditable movimiento) async {
    final url = Uri.parse('$baseUrl/api/movimientos/$id');
    final body = jsonEncode(movimiento.toJson());

    log('🚀 [PUT] Actualizando movimiento: $url', type: LogType.api);
    log('📤 [REQUEST] Body: $body', type: LogType.api);

    try {
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      log('📥 [RESPONSE] Status: ${response.statusCode}', type: LogType.api);
      log('📥 [RESPONSE] Body: ${response.body}', type: LogType.api);

      if (response.statusCode == 200) {
        final movimientoActualizado = Movimiento.fromJson(jsonDecode(response.body));
        log('✅ Movimiento actualizado: (ID: ${movimientoActualizado.id})', type: LogType.success);
        return movimientoActualizado;
      } else {
        log('❌ Error al actualizar movimiento: ${response.statusCode} - ${response.body}', type: LogType.error);
        throw Exception('Error al actualizar movimiento');
      }
    } catch (e) {
      log('💥 Excepción en actualizarMovimiento: $e', type: LogType.error);
      throw Exception('Error de red al actualizar movimiento: $e');
    }
  }

  Future<void> eliminarMovimiento(int id) async {
    final url = Uri.parse('$baseUrl/api/fondos/movimientos/$id');
    log('🚀 [DELETE] Eliminando movimiento: $url', type: LogType.api);

    try {
      final response = await http.delete(url);

      log('📥 [RESPONSE] Status: ${response.statusCode}', type: LogType.api);
      log('📥 [RESPONSE] Body: ${response.body}', type: LogType.api);

      if (response.statusCode == 200) {
        log('✅ Movimiento eliminado exitosamente (ID: $id)', type: LogType.success);
      } else {
        log('❌ Error al eliminar movimiento: ${response.statusCode} - ${response.body}', type: LogType.error);
        throw Exception('Error al eliminar movimiento con ID $id');
      }
    } catch (e) {
      log('💥 Excepción en eliminarMovimiento: $e', type: LogType.error);
      throw Exception('Error de red al eliminar movimiento: $e');
    }
  }
// =========================
// MOVIMIENTOS POR FONDO - PAGINADOS
// =========================

  Future<MovimientoPage> getMovimientosByFondo(int fondoId, int page, int size) async {
    final url = Uri.parse('$baseUrl/api/movimientos/fondo/$fondoId?page=$page&size=$size');
    log('🚀 [GET] Solicitando movimientos del fondo: $url', type: LogType.api);
    log('💰 Fondo ID: $fondoId | Página: $page | Tamaño: $size', type: LogType.info);

    try {
      final response = await http.get(url);

      log('📥 [RESPONSE] Status: ${response.statusCode}', type: LogType.api);
      log('📥 [RESPONSE] Body: ${response.body}', type: LogType.api);

      if (response.statusCode == 200) {
        final MovimientoPage movimientoPage = MovimientoPage.fromJson(jsonDecode(response.body));

        log('✅ Movimientos obtenidos: ${movimientoPage.content.length}', type: LogType.success);
        for (final m in movimientoPage.content) {
          log('📋 Movimiento: ${m.concepto} | Tipo: ${m.tipo} | Cantidad: ${m.cantidad}', type: LogType.info);
        }

        return movimientoPage;
      } else {
        log('❌ Error al obtener movimientos paginados: ${response.statusCode} - ${response.body}', type: LogType.error);
        throw Exception('Error al obtener movimientos paginados del fondo');
      }
    } catch (e) {
      log('💥 Excepción en getMovimientosByFondo (paginado): $e', type: LogType.error);
      throw Exception('Error de red al obtener movimientos paginados del fondo: $e');
    }
  }
  //unirse al fondo
  Future<UnirseFondoResponse> unirseAFondo(UnirseFondoRequest request) async {
    log('🚀 Iniciando petición para unirse a fondo: ${request.toString()}', type: LogType.api);

    try {
      final url = Uri.parse('$baseUrl/api/fondos/unirse');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(request.toJson()),
      );

      log('📨 Respuesta recibida - Status: ${response.statusCode}', type: LogType.api);
      log('📨 Body: ${response.body}', type: LogType.api);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        final unirseFondoResponse = UnirseFondoResponse.fromJson(responseData);

        log('✅ Usuario unido exitosamente: ${unirseFondoResponse.usuario.nombre} al fondo ${unirseFondoResponse.fondo.nombre}', type: LogType.success);
        log('👤 Rol asignado: ${unirseFondoResponse.usuario.rol}', type: LogType.info);

        return unirseFondoResponse;
      } else if (response.statusCode == 409) {
        // Conflicto - usuario ya existe en el fondo o código inválido
        final errorData = jsonDecode(response.body);
        throw Exception('Conflicto: ${errorData['mensaje'] ?? 'Usuario ya existe o código inválido'}');
      } else if (response.statusCode == 400) {
        // Bad request - datos inválidos
        final errorData = jsonDecode(response.body);
        throw Exception('Datos inválidos: ${errorData['mensaje'] ?? 'Revisa los datos enviados'}');
      } else if (response.statusCode == 404) {
        // Not found - fondo no existe
        final errorData = jsonDecode(response.body);
        throw Exception('Fondo no encontrado: ${errorData['mensaje'] ?? 'Código de fondo inválido'}');
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      log('💥 Error en unirseAFondo: $e', type: LogType.error);
      if (e is Exception) {
        rethrow;
      } else {
        throw Exception('Error de conexión: No se pudo conectar con el servidor');
      }
    }
  }
  // =========================
  // FONDOS POR USUARIO
  // =========================

  Future<FondoConRolPage> getFondosByUsuario(int userId, int page, int size) async {
    log('🚀 Obteniendo fondos con roles para usuario ID: $userId (página: $page)', type: LogType.api);

    try {
      final url = Uri.parse('$baseUrl/api/fondos/usuarios/$userId?page=$page&size=$size');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
      );

      log('📨 Respuesta recibida - Status: ${response.statusCode}', type: LogType.api);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final fondoConRolPage = FondoConRolPage.fromJson(responseData);

        log('✅ Fondos con roles cargados: ${fondoConRolPage.content.length} elementos', type: LogType.success);

        // Log detallado de roles
        for (var fondo in fondoConRolPage.content) {
          log('📋 Fondo: ${fondo.nombre} → Rol: ${fondo.rolUsuario} (${fondo.esAdmin ? "ADMIN 👑" : "USER 👤"})',
              type: LogType.info);
        }

        return fondoConRolPage;
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      log('💥 Error al obtener fondos con roles: $e', type: LogType.error);
      if (e is Exception) {
        rethrow;
      } else {
        throw Exception('Error de conexión: No se pudo conectar con el servidor');
      }
    }
  }

}
