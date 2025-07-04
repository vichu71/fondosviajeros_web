import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../apirest/api_service.dart';
import '../model/crear_fondo_request.dart';
import '../model/crear_fondo_response.dart';
import '../model/fondo.dart';
import '../model/usuario.dart';
import '../utils/logger.dart';
import 'home_fondo_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:share_plus/share_plus.dart';



class CrearFondoPage extends StatefulWidget {
  const CrearFondoPage({super.key});

  @override
  State<CrearFondoPage> createState() => _CrearFondoPageState();
}

class _CrearFondoPageState extends State<CrearFondoPage>
    with TickerProviderStateMixin {

  String? _nombreUsuario;
  bool _loading = true;
  TextEditingController _nombreFondoController = TextEditingController();
  TextEditingController _nombreUsuarioController = TextEditingController();
  final ApiService _apiService = ApiService();

  String? _error;
  bool _cargando = false;

  late AnimationController _sparkleController;
  late AnimationController _shakeController;
  late AnimationController _floatController;
  late Animation<double> _sparkleAnimation;
  late Animation<double> _shakeAnimation;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _cargarUsuario();
  }

  void _initAnimations() {
    _sparkleController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _floatController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );

    _sparkleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_sparkleController);

    _shakeAnimation = Tween<double>(
      begin: -8.0,
      end: 8.0,
    ).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.elasticIn,
    ));

    _floatAnimation = Tween<double>(
      begin: -15.0,
      end: 15.0,
    ).animate(CurvedAnimation(
      parent: _floatController,
      curve: Curves.easeInOut,
    ));

    _sparkleController.repeat();
    _floatController.repeat(reverse: true);
  }
  Future<void> _cargarUsuario() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('userData');

    String? nombre;
    if (jsonString != null) {
      try {
        final Map<String, dynamic> userMap = jsonDecode(jsonString);
        nombre = userMap['userName'];
      } catch (e) {
        print('❌ Error al parsear userData: $e');
      }
    }

    setState(() {
      _nombreUsuario = nombre;
      _loading = false;
    });

    print('🧠 Usuario cargado: $_nombreUsuario');
  }

  Future<String> _getOrCreateUuidDispositivo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? uuid = prefs.getString('uuid_dispositivo');

      if (uuid == null || uuid.isEmpty) {
        uuid = const Uuid().v4();
        final success = await prefs.setString('uuid_dispositivo', uuid);

        if (!success) {
          throw Exception('Error al guardar UUID del dispositivo');
        }

        log('🆔 UUID del dispositivo creado: $uuid', type: LogType.info);
      } else {
        log('🆔 UUID del dispositivo existente: $uuid', type: LogType.info);
      }

      return uuid;
    } catch (e) {
      log('❌ Error al manejar UUID del dispositivo: $e', type: LogType.error);
      // Fallback: generar UUID temporal (no persistente)
      return const Uuid().v4();
    }
  }
  Future<void> _guardarDatosUsuario(CrearFondoResponse response) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // ✅ VERIFICAR que los datos existen antes de guardar
      if (response.usuario == null || response.usuario.id == null || response.usuario.nombre.isEmpty) {
        throw Exception('Datos de usuario inválidos en la respuesta del servidor');
      }

      // Solo guardamos datos esenciales del usuario
      Map<String, dynamic> userData = {
        'userId': response.usuario.id.toString(),
        'userName': response.usuario.nombre,
        'fechaUltimoAcceso': DateTime.now().toIso8601String(),
      };

      log('💾 Guardando datos del usuario:', type: LogType.info);
      log('   - User ID: ${userData['userId']}', type: LogType.info);
      log('   - User Name: ${userData['userName']}', type: LogType.info);
      log('   - Fecha: ${userData['fechaUltimoAcceso']}', type: LogType.info);

      final success = await prefs.setString('userData', jsonEncode(userData));

      if (!success) {
        throw Exception('Error al escribir en SharedPreferences');
      }

      // ✅ VERIFICAR que se guardó correctamente
      final verificacion = prefs.getString('userData');
      if (verificacion == null) {
        throw Exception('Verificación falló: datos no encontrados después de guardar');
      }

      log('✅ Datos de usuario guardados exitosamente', type: LogType.success);
      log('   - Verificación: ${verificacion.substring(0, 50)}...', type: LogType.info);

    } catch (e) {
      log('❌ ERROR CRÍTICO al guardar datos del usuario: $e', type: LogType.error);

      // Mostrar error al usuario
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Text("⚠️", style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Error al guardar datos: $e",
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }

      // Re-lanzar la excepción para que el caller lo sepa
      rethrow;
    }
  }
  Future<void> _crearFondo() async {
    final nombreUsuario = _nombreUsuario ?? _nombreUsuarioController.text.trim();
    final nombreFondo = _nombreFondoController.text.trim();

    if (nombreUsuario.isEmpty || nombreFondo.isEmpty) {
      _mostrarError("¡Hey! Rellena todo para ser el líder 👑");
      return;
    }

    setState(() {
      _error = null;
      _cargando = true;
    });

    try {
      final uuid = await _getOrCreateUuidDispositivo();

      CrearFondoRequest request = CrearFondoRequest(
        nombreUsuario: nombreUsuario,
        nombreFondo: nombreFondo,
        uuidDispositivo: uuid,
      );

      log('🚀 Enviando request para crear fondo: $request', type: LogType.api);

      CrearFondoResponse response = await _apiService.crearFondo(request);

      log('✅ Respuesta recibida del servidor:', type: LogType.success);
      log('   - Fondo ID: ${response.fondo.id}', type: LogType.info);
      log('   - Fondo nombre: ${response.fondo.nombre}', type: LogType.info);
      log('   - Usuario ID: ${response.usuario.id}', type: LogType.info);
      log('   - Usuario nombre: ${response.usuario.nombre}', type: LogType.info);

      // ✅ IMPORTANTE: Guardar datos del usuario ANTES de mostrar el diálogo
      await _guardarDatosUsuario(response);

      setState(() => _cargando = false);

      _mostrarDialogExito(response.fondo, nombreFondo);

    } catch (e) {
      setState(() => _cargando = false);
      final mensaje = e.toString().contains('409') || e.toString().contains('400')
          ? "Ese nombre ya está pillado! 😅 Prueba otro"
          : "Algo ha petado 💥 ¡Inténtalo otra vez!";
      _mostrarError(mensaje);
      log('💥 Error al crear fondo: $e', type: LogType.error);
    }
  }



  void _mostrarError(String mensaje) {
    setState(() => _error = mensaje);
    _shakeController.forward().then((_) => _shakeController.reverse());
  }


  // ✅ MÉTODO ACTUALIZADO: _mostrarDialogExito con botón de compartir

  void _mostrarDialogExito(Fondo fondo, String nombreFondo) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.purple.shade400,
                Colors.pink.shade400,
                Colors.orange.shade300,
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      spreadRadius: 5,
                      blurRadius: 15,
                    ),
                  ],
                ),
                child: const Text(
                  "👑",
                  style: TextStyle(fontSize: 60),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "¡ERES EL BOSS! 🔥",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Squad '$nombreFondo' creado con éxito! 🎊",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    const Text(
                      "Código del fondo:",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            spreadRadius: 2,
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            fondo.codigo.toString(),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Colors.purple.shade700,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: fondo.codigo.toString()));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text("¡ID copiado! 📋✨"),
                                  backgroundColor: Colors.green.shade600,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.purple.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.copy,
                                color: Colors.purple.shade700,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ✅ NUEVO: Botones de acción (Compartir + Vamos allá)
              Column(
                children: [
                  // Botón Compartir
                  Container(
                    width: double.infinity,
                    height: 50,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ElevatedButton(
                      onPressed: () => _compartirCodigo(fondo, nombreFondo),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.2),
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withOpacity(0.4), width: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text("📤", style: TextStyle(fontSize: 16)),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            "Compartir código",
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text("📱", style: TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                  ),

                  // Botón Vamos allá (principal)
                  Container(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context); // Cerrar dialog

                        // Navegación para crear fondo: Preservar solo InicioPage en el stack
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => HomeFondoPage(
                              fondo: fondo, // Pasamos el objeto fondo completo
                            ),
                          ),
                          // Preservar solo InicioPage en el stack
                              (route) => route.settings.name == '/' || route.toString().contains('InicioPage'),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.purple.shade700,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        elevation: 8,
                      ),
                      child: const Text(
                        "¡Vamos allá! 🚀",
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

// ✅ NUEVO: Método para compartir el código del fondo
  void _compartirCodigo(Fondo fondo, String nombreFondo) async {
    try {
      final mensaje = '''🎒✈️ ¡Únete a mi squad de viaje!

🎯 Fondo: $nombreFondo
🔑 Código: ${fondo.codigo}

¡Descárgate FondosViajeros y únete usando este código! Vamos a hacer realidad esta aventura juntos 🌟

#SquadGoals #ViajeEnGrupo #FondosViajeros''';

      // Usar el paquete share_plus para compartir
      await Share.share(
        mensaje,
        subject: '¡Únete a mi fondo de viaje: $nombreFondo!',
      );

      // Log para debugging
      log('📤 Código compartido: ${fondo.codigo}', type: LogType.info);

    } catch (e) {
      log('❌ Error al compartir: $e', type: LogType.error);

      // Fallback: copiar al portapapeles
      Clipboard.setData(ClipboardData(text: fondo.codigo.toString()));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Text("📋", style: TextStyle(fontSize: 16)),
                SizedBox(width: 8),
                Text(
                  "Código copiado al portapapeles",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            backgroundColor: Colors.blue.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.indigo.shade500,
              Colors.purple.shade400,
              Colors.pink.shade400,
              Colors.orange.shade300,
            ],
            stops: const [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header personalizado
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        "¡Crea tu squad! 👑",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      // Icono principal animado
                      AnimatedBuilder(
                        animation: _floatAnimation,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(0, _floatAnimation.value),
                            child: Container(
                              padding: const EdgeInsets.all(25),
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  colors: [
                                    Colors.white,
                                    Colors.yellow.shade100,
                                  ],
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.orange.withOpacity(0.4),
                                    spreadRadius: 6,
                                    blurRadius: 20,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: AnimatedBuilder(
                                animation: _sparkleAnimation,
                                builder: (context, child) {
                                  return Transform.rotate(
                                    angle: _sparkleAnimation.value * 2 * 3.14159,
                                    child: const Text(
                                      "⭐",
                                      style: TextStyle(fontSize: 50),
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 30),

                      // Formulario principal
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              spreadRadius: 2,
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: AnimatedBuilder(
                          animation: _shakeAnimation,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: _error != null ? Offset(_shakeAnimation.value, 0) : Offset.zero,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 👋 Saludo si ya existe usuario
                                  if (_nombreUsuario != null)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 20.0),
                                      child: Text(
                                        'Hey $_nombreUsuario 👋',
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),

                                  // Título del formulario
                                  Center(
                                    child: Column(
                                      children: [
                                        const Text(
                                          "¡Time to lead! 🔥",
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          "Crea tu grupo y sé el captain ⚡",
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade600,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  // 👤 Campo nombre de usuario solo si no está cargado
                                  if (_nombreUsuario == null) ...[
                                    const Text(
                                      "¿Cómo te llamas, líder? 😎",
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(18),
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.indigo.shade50,
                                            Colors.purple.shade50,
                                          ],
                                        ),
                                        border: Border.all(
                                          color: Colors.indigo.shade200,
                                          width: 2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.indigo.withOpacity(0.1),
                                            spreadRadius: 1,
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: TextField(
                                        controller: _nombreUsuarioController,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: "Tu nombre de boss 👑",
                                          hintStyle: TextStyle(
                                            color: Colors.grey.shade500,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          border: InputBorder.none,
                                          contentPadding: const EdgeInsets.all(16),
                                          prefixIcon: Container(
                                            margin: const EdgeInsets.all(12),
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  Colors.indigo.shade400,
                                                  Colors.purple.shade400,
                                                ],
                                              ),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: const Text(
                                              "🎯",
                                              style: TextStyle(fontSize: 18),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                  ],



                                  // Campo nombre del fondo
                                  const Text(
                                    "Nombre épico para tu squad 🚀",
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(18),
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.pink.shade50,
                                          Colors.orange.shade50,
                                        ],
                                      ),
                                      border: Border.all(
                                        color: Colors.pink.shade200,
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.pink.withOpacity(0.1),
                                          spreadRadius: 1,
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: TextField(
                                      controller: _nombreFondoController,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: "Ej: Viaje a Bali 2025 🏝️",
                                        hintStyle: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: const EdgeInsets.all(16),
                                        prefixIcon: Container(
                                          margin: const EdgeInsets.all(12),
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.pink.shade400,
                                                Colors.orange.shade400,
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Text(
                                            "✨",
                                            style: TextStyle(fontSize: 18),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  // Mensaje de error
                                  if (_error != null)
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(18),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: Colors.red.shade200,
                                          width: 2,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Text(
                                            "😵",
                                            style: TextStyle(fontSize: 24),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Text(
                                              _error!,
                                              style: TextStyle(
                                                color: Colors.red.shade700,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  const SizedBox(height: 24),

                                  // Botón crear fondo
                                  Container(
                                    width: double.infinity,
                                    height: 55,
                                    child: ElevatedButton(
                                      onPressed: _cargando ? null : _crearFondo,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        padding: EdgeInsets.zero,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(22),
                                        ),
                                      ),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: _cargando
                                                ? [
                                              Colors.grey.shade400,
                                              Colors.grey.shade500,
                                            ]
                                                : [
                                              Colors.indigo.shade500,
                                              Colors.purple.shade500,
                                              Colors.pink.shade400,
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(22),
                                          boxShadow: [
                                            BoxShadow(
                                              color: _cargando
                                                  ? Colors.grey.withOpacity(0.3)
                                                  : Colors.purple.withOpacity(0.5),
                                              spreadRadius: 3,
                                              blurRadius: 15,
                                              offset: const Offset(0, 8),
                                            ),
                                          ],
                                        ),
                                        child: Center(
                                          child: _cargando
                                              ? Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              const SizedBox(
                                                height: 24,
                                                width: 24,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 3,
                                                  valueColor: AlwaysStoppedAnimation<Color>(
                                                    Colors.white,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              const Text(
                                                "Creando magia... ✨",
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          )
                                              : const Text(
                                            "¡Crear mi squad! 👑",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 20,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Footer inspiracional
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.15),
                              Colors.white.withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        child: const Column(
                          children: [
                            Text(
                              "🌟 ¡Conviértete en el líder que tu crew necesita! 🌟",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              "Crea, lidera y haz realidad esa aventura épica ✈️",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}