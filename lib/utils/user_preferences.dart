
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class UserPreferences {

  // Guardar datos del usuario cuando crea o se une a un fondo
  static Future<void> saveUserFondo({
    required String userId,
    required String userName,
    required String fondoId,
    required String fondoNombre,
    required String fondoMonto,
    required bool esCreador,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    Map<String, dynamic> userData = {
      'userId': userId,
      'userName': userName,
      'fondoId': fondoId,
      'fondoNombre': fondoNombre,
      'fondoMonto': fondoMonto,
      'esCreador': esCreador,
      'fechaUltimoAcceso': DateTime.now().toIso8601String(),
    };

    await prefs.setString('userData', jsonEncode(userData));
  }

  // Obtener datos del usuario
  static Future<Map<String, dynamic>?> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('userData');

    if (userDataString != null) {
      return jsonDecode(userDataString);
    }
    return null;
  }

  // Verificar si el usuario tiene un fondo activo
  static Future<bool> hasActiveFondo() async {
    final userData = await getUserData();
    return userData != null && userData['fondoId'] != null;
  }

  // Limpiar datos del usuario (logout o salir del fondo)
  static Future<void> clearUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userData');
  }

  // Actualizar solo el monto del fondo
  static Future<void> updateFondoMonto(String nuevoMonto) async {
    final userData = await getUserData();
    if (userData != null) {
      userData['fondoMonto'] = nuevoMonto;
      userData['fechaUltimoAcceso'] = DateTime.now().toIso8601String();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userData', jsonEncode(userData));
    }
  }
}