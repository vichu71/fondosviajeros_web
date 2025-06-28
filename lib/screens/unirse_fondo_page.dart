import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';

import '../model/unirse_fondo_request.dart';
import '../model/unirse_fondo_response.dart';
import '../model/fondo.dart';
import '../apirest/api_service.dart';
import '../utils/logger.dart';
import 'inicio_page.dart';
import 'home_fondo_page.dart';

class UnirseFondoPage extends StatefulWidget {
  const UnirseFondoPage({super.key});

  @override
  State<UnirseFondoPage> createState() => _UnirseFondoPageState();
}

class _UnirseFondoPageState extends State<UnirseFondoPage>
    with TickerProviderStateMixin {

  final ApiService _apiService = ApiService();
  final _nombreUsuarioController = TextEditingController();
  final _codigoFondoController = TextEditingController();
  String? _error;
  bool _cargando = false;

  late AnimationController _shakeController;
  late AnimationController _pulseController;
  late Animation<double> _shakeAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _shakeAnimation = Tween<double>(
      begin: -5.0,
      end: 5.0,
    ).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.elasticIn,
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _pulseController.dispose();
    _nombreUsuarioController.dispose();
    _codigoFondoController.dispose();
    super.dispose();
  }

  // Método para obtener o crear UUID del dispositivo
  Future<String> _getOrCreateUuidDispositivo() async {
    final prefs = await SharedPreferences.getInstance();
    String? uuid = prefs.getString('uuid_dispositivo');
    if (uuid == null) {
      uuid = const Uuid().v4();
      await prefs.setString('uuid_dispositivo', uuid);
      log('🆔 UUID del dispositivo creado: $uuid', type: LogType.info);
    } else {
      log('🆔 UUID del dispositivo existente: $uuid', type: LogType.info);
    }
    return uuid;
  }

  // Método actualizado para guardar datos del usuario
  Future<void> _guardarDatosUsuario(UnirseFondoResponse response) async {
    final prefs = await SharedPreferences.getInstance();

    Map<String, dynamic> userData = {
      'userId': response.usuario.id.toString(),
      'userName': response.usuario.nombre,
      'fechaUltimoAcceso': DateTime.now().toIso8601String(),
    };

    await prefs.setString('userData', jsonEncode(userData));

    log('✅ Datos de usuario guardados: ID=${response.usuario.id}, Nombre=${response.usuario.nombre}', type: LogType.success);
  }

  // Método principal actualizado
  Future<void> _unirseAFondo() async {
    final nombreUsuario = _nombreUsuarioController.text.trim();
    final codigoFondo = _codigoFondoController.text.trim();

    if (nombreUsuario.isEmpty || codigoFondo.isEmpty) {
      setState(() => _error = "¡Oye! Necesito que rellenes todo 📝");
      _shakeController.forward().then((_) => _shakeController.reverse());
      return;
    }

    setState(() {
      _error = null;
      _cargando = true;
    });

    try {
      // Obtener UUID del dispositivo
      final uuid = await _getOrCreateUuidDispositivo();

      // Crear request
      final request = UnirseFondoRequest(
        nombreUsuario: nombreUsuario,
        codigoFondo: codigoFondo,
        uuidDispositivo: uuid,
      );

      log('🚀 Intentando unirse al fondo: ${request.toString()}', type: LogType.info);

      // Llamar al API
      final response = await _apiService.unirseAFondo(request);

      // Guardar datos del usuario
      await _guardarDatosUsuario(response);

      setState(() => _cargando = false);

      // Mostrar dialog de éxito
      _mostrarDialogExito(response.fondo, response.usuario.nombre);

    } catch (e) {
      setState(() => _cargando = false);

      String mensajeError;
      if (e.toString().contains('Conflicto')) {
        mensajeError = "Oops! 😅 Ese nombre ya está pillado o el código no mola";
      } else if (e.toString().contains('Fondo no encontrado')) {
        mensajeError = "🤔 Ese código no existe, ¿seguro que está bien?";
      } else if (e.toString().contains('Datos inválidos')) {
        mensajeError = "📝 Revisa los datos que has puesto";
      } else if (e.toString().contains('conexión')) {
        mensajeError = "📡 No hay conexión, ¡revisa tu internet!";
      } else {
        mensajeError = "Algo ha petado 💥 ¡Inténtalo de nuevo!";
      }

      setState(() => _error = mensajeError);
      _shakeController.forward().then((_) => _shakeController.reverse());

      log('💥 Error al unirse al fondo: $e', type: LogType.error);
    }
  }

  // Método para mostrar dialog de éxito (actualizado)
  void _mostrarDialogExito(Fondo fondo, String nombreUsuario) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.green.shade400,
                Colors.teal.shade300,
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Text(
                  "🎉",
                  style: TextStyle(fontSize: 50),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "¡YAAAS! 🔥",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "¡Bienvenido al squad, $nombreUsuario! 🎊\n${fondo.nombre}",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Cerrar dialog

                  // Navegar al fondo y limpiar el stack
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => HomeFondoPage(
                        fondo: fondo,
                      ),
                    ),
                        (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.teal.shade700,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: const Text(
                  "¡Let's go! 🚀",
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade400,
              Colors.purple.shade400,
              Colors.pink.shade300,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header con back button personalizado
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
                        "Join the squad! 🎯",
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
                      // Icono animado principal
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulseAnimation.value,
                            child: Container(
                              padding: const EdgeInsets.all(25),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    spreadRadius: 4,
                                    blurRadius: 15,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: const Text(
                                "🤝",
                                style: TextStyle(fontSize: 50),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 30),

                      // Formulario con estilo
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              spreadRadius: 2,
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: AnimatedBuilder(
                          animation: _shakeAnimation,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: _error != null
                                  ? Offset(_shakeAnimation.value, 0)
                                  : Offset.zero,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Campo nombre
                                  const Text(
                                    "¿Cómo te llamas? 😎",
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(15),
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.blue.shade50,
                                          Colors.purple.shade50,
                                        ],
                                      ),
                                      border: Border.all(
                                        color: Colors.purple.shade200,
                                        width: 2,
                                      ),
                                    ),
                                    child: TextField(
                                      controller: _nombreUsuarioController,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: "Tu nombre molón 🌟",
                                        hintStyle: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: const EdgeInsets.all(16),
                                        prefixIcon: Container(
                                          margin: const EdgeInsets.all(12),
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.blue.shade400,
                                                Colors.purple.shade400,
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Text(
                                            "👤",
                                            style: TextStyle(fontSize: 16),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  // Campo código
                                  const Text(
                                    "Código del fondo 🔐",
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(15),
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.pink.shade50,
                                          Colors.orange.shade50,
                                        ],
                                      ),
                                      border: Border.all(
                                        color: Colors.orange.shade200,
                                        width: 2,
                                      ),
                                    ),
                                    child: TextField(
                                      controller: _codigoFondoController,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: "El código secreto 🤫",
                                        hintStyle: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: const EdgeInsets.all(16),
                                        prefixIcon: Container(
                                          margin: const EdgeInsets.all(12),
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.pink.shade400,
                                                Colors.orange.shade400,
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Text(
                                            "🎫",
                                            style: TextStyle(fontSize: 16),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  // Mensaje de error
                                  if (_error != null)
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(15),
                                        border: Border.all(
                                          color: Colors.red.shade200,
                                          width: 2,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Text(
                                            "⚠️",
                                            style: TextStyle(fontSize: 20),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              _error!,
                                              style: TextStyle(
                                                color: Colors.red.shade700,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  const SizedBox(height: 20),

                                  // Botón de unirse
                                  Container(
                                    width: double.infinity,
                                    height: 55,
                                    child: ElevatedButton(
                                      onPressed: _cargando ? null : _unirseAFondo,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        padding: EdgeInsets.zero,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(20),
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
                                              Colors.green.shade400,
                                              Colors.teal.shade400,
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(20),
                                          boxShadow: [
                                            BoxShadow(
                                              color: _cargando
                                                  ? Colors.grey.withOpacity(0.3)
                                                  : Colors.green.withOpacity(0.4),
                                              spreadRadius: 2,
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Center(
                                          child: _cargando
                                              ? Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              const SizedBox(
                                                height: 20,
                                                width: 20,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor: AlwaysStoppedAnimation<Color>(
                                                    Colors.white,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              const Text(
                                                "Conectando... 🚀",
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          )
                                              : const Text(
                                            "¡Súmate al squad! 🎉",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
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

                      // Footer motivacional
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        child: const Column(
                          children: [
                            Text(
                              "🌟 ¡Tu próxima aventura está a un clic! 🌟",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              "Únete y empieza a ahorrar con tu crew ✨",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
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