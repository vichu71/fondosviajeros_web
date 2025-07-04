import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/fondo.dart';
import '../model/movimiento.dart';
import '../model/usuario.dart';
import '../apirest/api_service.dart';
import '../utils/logger.dart';

class CrearMovimientoPage extends StatefulWidget {
  final Fondo fondo;
  final String tipoMovimiento; // "APORTE" o "GASTO"

  const CrearMovimientoPage({
    Key? key,
    required this.fondo,
    required this.tipoMovimiento,
  }) : super(key: key);

  @override
  State<CrearMovimientoPage> createState() => _CrearMovimientoPageState();
}

class _CrearMovimientoPageState extends State<CrearMovimientoPage>
    with TickerProviderStateMixin {

  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

  // Controladores
  final TextEditingController _conceptoController = TextEditingController();
  final TextEditingController _cantidadController = TextEditingController();

  // Variables de estado
  bool _isLoading = false;
  bool _isLoadingUsuarios = false;
  bool _isLoadingRol = false;
  Usuario? _usuarioActual;
  Usuario? _usuarioSeleccionado; // Usuario seleccionado para el movimiento
  List<Usuario> _usuariosFondo = []; // Lista de usuarios del fondo
  bool _esAdminDelFondo = false; // Si el usuario actual es admin de este fondo específico

  // Animaciones
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _cargarUsuarioActual();
  }

  @override
  void dispose() {
    _conceptoController.dispose();
    _cantidadController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  void _initAnimations() {
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _bounceAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _bounceController,
      curve: Curves.elasticOut,
    ));
  }

  Future<void> _cargarUsuarioActual() async {
    try {
      log('🔍 Iniciando carga de usuario actual...', type: LogType.info);

      // Intentar obtener el usuario del ApiService primero
      Usuario? usuario = await _apiService.getUser();
      log('🔍 getUser() resultado: ${usuario?.nombre ?? "null"}', type: LogType.info);

      // Si no está disponible, intentar obtener de userData (como en inicio_page)
      if (usuario == null) {
        log('🔍 Usuario no encontrado en caché, buscando en userData...', type: LogType.info);

        final prefs = await SharedPreferences.getInstance();
        final userDataString = prefs.getString('userData');

        log('🔍 userData encontrado: ${userDataString != null}', type: LogType.info);

        if (userDataString != null) {
          final userData = jsonDecode(userDataString);
          final userId = int.parse(userData['userId']);

          log('👤 Usuario encontrado en userData, userId: $userId', type: LogType.info);
          log('🔍 Obteniendo detalles del usuario desde API...', type: LogType.info);

          // Obtener el usuario completo del API
          usuario = await _apiService.getUsuarioById(userId);

          if (usuario != null) {
            log('✅ Usuario obtenido del API: ${usuario.nombre}', type: LogType.success);
            // Guardarlo en el formato correcto para próximas veces
            await _apiService.saveUser(usuario);
            log('✅ Usuario guardado en caché', type: LogType.success);
          } else {
            log('❌ No se pudo obtener usuario del API', type: LogType.error);
          }
        } else {
          log('❌ No hay userData en SharedPreferences', type: LogType.warning);
        }
      }

      // Asegurar que setState se ejecute de forma segura
      if (mounted) {
        setState(() {
          _usuarioActual = usuario;
          _usuarioSeleccionado = usuario; // Inicializar aquí
        });
      }

      log('👤 Usuario final cargado: ${usuario?.nombre ?? "null"}', type: LogType.info);

      // Verificar si el usuario es admin de este fondo específico
      if (usuario != null && mounted) {
        await _verificarRolEnFondo(usuario);
      }

    } catch (e) {
      log('❌ Error al cargar usuario: $e', type: LogType.error);
      if (mounted) {
        _mostrarError('Error al cargar usuario actual');
      }
    }
  }

  Future<void> _verificarRolEnFondo(Usuario usuario) async {
    setState(() {
      _isLoadingRol = true;
    });

    try {
      log('🔍 Verificando rol del usuario en el fondo...', type: LogType.info);

      final esAdmin = await _apiService.isUsuarioAdminOfFondo(usuario.id!, widget.fondo.id!);

      setState(() {
        _esAdminDelFondo = esAdmin;
      });

      log('👑 Usuario ${esAdmin ? "ES" : "NO ES"} admin del fondo', type: LogType.info);

      // Si es admin, cargar los usuarios del fondo
      if (esAdmin) {
        await _cargarUsuariosFondo();
      }

    } catch (e) {
      log('❌ Error al verificar rol: $e', type: LogType.error);
      setState(() {
        _esAdminDelFondo = false;
      });
    } finally {
      setState(() {
        _isLoadingRol = false;
      });
    }
  }

  Future<void> _cargarUsuariosFondo() async {
    if (!_esAdminDelFondo || !mounted) return;

    setState(() {
      _isLoadingUsuarios = true;
    });

    try {
      log('👥 Cargando usuarios del fondo ${widget.fondo.id}...', type: LogType.info);

      // ✅ SIMPLIFICADO: Sin parámetros de paginación
      final usuarios = await _apiService.getUsuariosByFondoId(widget.fondo.id!);

      if (!mounted) return; // Verificar que el widget aún esté montado

      setState(() {
        _usuariosFondo = usuarios;

        // ✅ IMPORTANTE: Verificar que el usuario seleccionado esté en la lista
        if (_usuarioSeleccionado != null &&
            !usuarios.any((u) => u.id == _usuarioSeleccionado!.id)) {

          // Si el usuario actual está en la lista, seleccionarlo
          if (_usuarioActual != null &&
              usuarios.any((u) => u.id == _usuarioActual!.id)) {
            _usuarioSeleccionado = usuarios.firstWhere((u) => u.id == _usuarioActual!.id);
          } else {
            // Si no, seleccionar el primer usuario de la lista
            _usuarioSeleccionado = usuarios.isNotEmpty ? usuarios.first : null;
          }
        }
      });

      log('✅ ${usuarios.length} usuarios cargados del fondo', type: LogType.success);

    } catch (e) {
      log('❌ Error al cargar usuarios del fondo: $e', type: LogType.error);

      if (mounted) {
        _mostrarError('Error al cargar usuarios del fondo');

        // Si falla la carga, al menos permitir que el admin se seleccione a sí mismo
        if (_usuarioActual != null) {
          setState(() {
            _usuariosFondo = [_usuarioActual!];
            _usuarioSeleccionado = _usuarioActual;
          });
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingUsuarios = false;
        });
      }
    }
  }

  // Método actualizado para verificar si el usuario es administrador del fondo específico
  bool get _esUsuarioAdminDelFondo => _esAdminDelFondo;

  bool get _esAporte => widget.tipoMovimiento == "APORTE";

  Future<void> _crearMovimiento() async {
    if (!_formKey.currentState!.validate()) return;
    if (_usuarioSeleccionado == null) {
      _mostrarError('Usuario no seleccionado');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final cantidad = double.parse(_cantidadController.text.trim());
      final concepto = _conceptoController.text.trim();

      log('🚀 Creando movimiento: $concepto - $cantidad € para usuario: ${_usuarioSeleccionado!.nombre}', type: LogType.info);

      // Crear MovimientoEditable para el ApiService
      final movimientoEditable = MovimientoEditable(
        concepto: concepto,
        cantidad: cantidad,
        tipo: widget.tipoMovimiento,
        fecha: DateTime.now(),
        usuario: _usuarioSeleccionado!, // Usar el usuario seleccionado
        fondo: widget.fondo,
      );

      log('📤 Enviando MovimientoEditable al ApiService', type: LogType.api);

      // Usar el método original del ApiService
      final movimientoCreado = await _apiService.crearMovimiento(movimientoEditable);

      log('✅ Movimiento creado exitosamente: ${movimientoCreado.id}', type: LogType.success);

      // Animación de éxito
      _bounceController.forward().then((_) {
        _bounceController.reverse();
      });

      // Mostrar éxito y volver
      String mensajeExito = '${_esAporte ? "Aporte" : "Gasto"} registrado exitosamente! 🎉';
      if (_esUsuarioAdminDelFondo && _usuarioSeleccionado!.id != _usuarioActual!.id) {
        mensajeExito += '\nAsignado a: ${_usuarioSeleccionado!.nombre}';
      }
      _mostrarExito(mensajeExito);

      // Esperar un poco y volver a la pantalla anterior
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) {
        Navigator.pop(context, true); // true indica que se creó exitosamente
      }

    } catch (e) {
      log('💥 Error al crear movimiento: $e', type: LogType.error);
      _mostrarError('Error al crear ${_esAporte ? "aporte" : "gasto"}: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Text("❌", style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                mensaje,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _mostrarExito(String mensaje) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Text("✅", style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                mensaje,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _esAporte
                ? [
              Colors.green.shade400,
              Colors.teal.shade300,
              Colors.cyan.shade200,
            ]
                : [
              Colors.red.shade400,
              Colors.pink.shade300,
              Colors.orange.shade200,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(),

              // Formulario
              Expanded(
                child: _buildFormulario(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${_esAporte ? "Hacer aporte" : "Registrar gasto"} 💰",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                Text(
                  "Fondo: ${widget.fondo.nombre}",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                // Mostrar si es admin
                if (_esUsuarioAdminDelFondo) ...[
                  Text(
                    "👑 Modo Admin",
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.yellow.shade200,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Icono animado
          AnimatedBuilder(
            animation: _bounceAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _bounceAnimation.value,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    _esAporte ? "💰" : "💸",
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFormulario() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Título del formulario
              _buildTituloFormulario(),
              const SizedBox(height: 24),

              // Campo Concepto
              _buildCampoConcepto(),
              const SizedBox(height: 16),

              // Campo Cantidad
              _buildCampoCantidad(),
              const SizedBox(height: 20),

              // Selector de usuario (solo para admins) o info del usuario
              _buildSelectorUsuario(),

              const SizedBox(height: 20),

              // Botón de crear
              _buildBotonCrear(),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTituloFormulario() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _esAporte ? "💰" : "💸",
            style: const TextStyle(fontSize: 40),
          ),
          const SizedBox(height: 8),
          Text(
            _esAporte
                ? "¡Vamos a añadir dinero al fondo! 🚀"
                : "¿En qué se gastó el dinero? 🤔",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _esAporte ? Colors.green.shade700 : Colors.red.shade700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            _esAporte
                ? "Cada euro cuenta para la aventura ✨"
                : "Registra el gasto para que todos sepan 📝",
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCampoConcepto() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "¿Para qué es? 📝",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _conceptoController,
          decoration: InputDecoration(
            hintText: _esAporte
                ? "Ej: Aporte para el hotel"
                : "Ej: Cena grupal en el restaurante",
            prefixIcon: Icon(
              _esAporte ? Icons.savings : Icons.receipt,
              color: _esAporte ? Colors.green.shade600 : Colors.red.shade600,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(
                color: _esAporte ? Colors.green.shade300 : Colors.red.shade300,
                width: 2,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(
                color: _esAporte ? Colors.green.shade600 : Colors.red.shade600,
                width: 3,
              ),
            ),
            filled: true,
            fillColor: _esAporte
                ? Colors.green.shade50
                : Colors.red.shade50,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Por favor describe el ${_esAporte ? "aporte" : "gasto"}';
            }
            if (value.trim().length < 3) {
              return 'Mínimo 3 caracteres';
            }
            return null;
          },
          maxLength: 100,
          textCapitalization: TextCapitalization.sentences,
        ),
      ],
    );
  }

  Widget _buildCampoCantidad() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "¿Cuánto dinero? 💰",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _cantidadController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          decoration: InputDecoration(
            hintText: "0.00",
            prefixIcon: Icon(
              Icons.euro,
              color: _esAporte ? Colors.green.shade600 : Colors.red.shade600,
            ),
            suffixText: "€",
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(
                color: _esAporte ? Colors.green.shade300 : Colors.red.shade300,
                width: 2,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(
                color: _esAporte ? Colors.green.shade600 : Colors.red.shade600,
                width: 3,
              ),
            ),
            filled: true,
            fillColor: _esAporte
                ? Colors.green.shade50
                : Colors.red.shade50,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Introduce la cantidad';
            }
            final cantidad = double.tryParse(value.trim());
            if (cantidad == null) {
              return 'Introduce un número válido';
            }
            if (cantidad <= 0) {
              return 'La cantidad debe ser mayor a 0';
            }
            if (cantidad > 10000) {
              return 'Cantidad máxima: 10,000€';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildBotonCrear() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _crearMovimiento,
        style: ElevatedButton.styleFrom(
          backgroundColor: _esAporte ? Colors.green.shade600 : Colors.red.shade600,
          foregroundColor: Colors.white,
          elevation: 8,
          shadowColor: (_esAporte ? Colors.green : Colors.red).withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _esAporte ? "💰" : "💸",
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(width: 12),
            Text(
              _esAporte
                  ? "Confirmar aporte"
                  : "Registrar gasto",
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectorUsuario() {
    return Container(
      width: double.infinity,
      child: _buildSelectorContent(),
    );
  }

  Widget _buildSelectorContent() {
    // Si no hay usuario actual cargado, mostrar un placeholder
    if (_usuarioActual == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(
              "Cargando usuario...",
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    // Si el usuario es admin del fondo, mostrar dropdown
    if (_esUsuarioAdminDelFondo) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.blue.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.admin_panel_settings,
                    color: Colors.blue.shade600,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Asignar movimiento a:",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildDropdownContent(),
          ],
        ),
      );
    } else {
      // Si no es admin, mostrar la info del usuario actual (comportamiento original)
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _esAporte ? Colors.green.shade100 : Colors.red.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.person,
                color: _esAporte ? Colors.green.shade600 : Colors.red.shade600,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Registrado por:",
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    _usuarioActual!.nombre,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildDropdownContent() {
    if (_isLoadingUsuarios || _isLoadingRol) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16.0),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_usuariosFondo.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Text(
          "No se pudieron cargar los usuarios del fondo",
          style: TextStyle(
            fontSize: 12,
            color: Colors.red.shade600,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return _buildDropdownUsuarios();
  }

  Widget _buildDropdownUsuarios() {
    // Verificar que el usuario seleccionado esté en la lista
    Usuario? usuarioSeguro = _usuarioSeleccionado;
    if (usuarioSeguro != null && !_usuariosFondo.any((u) => u.id == usuarioSeguro?.id)) {
      // Si el usuario seleccionado no está en la lista, seleccionar el usuario actual por defecto
      usuarioSeguro = _usuarioActual;
    }

    return SizedBox(
      width: double.infinity,
      child: DropdownButtonFormField<Usuario>(
        value: usuarioSeguro,
        isExpanded: true,
        decoration: InputDecoration(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.blue.shade300, width: 2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.blue.shade600, width: 3),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        items: _usuariosFondo.map((usuario) {
          return DropdownMenuItem<Usuario>(
            value: usuario,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: usuario.id == _usuarioActual?.id
                      ? Colors.blue.shade100
                      : Colors.grey.shade200,
                  child: Text(
                    usuario.nombre.isNotEmpty ? usuario.nombre[0].toUpperCase() : "?",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: usuario.id == _usuarioActual?.id
                          ? Colors.blue.shade700
                          : Colors.grey.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    usuario.nombre,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: usuario.id == _usuarioActual?.id
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (usuario.id == _usuarioActual?.id) ...[
                  Text(
                    " (Tú)",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
        onChanged: (Usuario? nuevoUsuario) {
          if (mounted) {
            setState(() {
              _usuarioSeleccionado = nuevoUsuario;
            });
          }
        },
        validator: (Usuario? value) {
          if (value == null) {
            return 'Selecciona un usuario';
          }
          return null;
        },
      ),
    );
  }
}