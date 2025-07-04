import 'package:flutter/material.dart';
import '../model/fondo_con_rol.dart';
import 'crear_fondo_page.dart';
import 'unirse_fondo_page.dart';
import 'home_fondo_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../apirest/api_service.dart';
import '../model/fondo.dart';
import '../model/usuario.dart';
import '../utils/logger.dart';
import 'package:flutter/services.dart';

class InicioPage extends StatefulWidget {
  const InicioPage({super.key});

  @override
  State<InicioPage> createState() => _InicioPageState();
}

class _InicioPageState extends State<InicioPage>
    with TickerProviderStateMixin {

  final ApiService _apiService = ApiService();

  // Variables para paginación y scroll infinito
  final ScrollController _scrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();
  List<FondoConRol> _fondos = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  int _currentPage = 0;
  final int _pageSize = 10;
  String? _error;
  Map<String, dynamic>? _userData;




  // Animaciones
  late AnimationController _bounceController;
  late AnimationController _rotateController;
  late Animation<double> _bounceAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _scrollController.addListener(_scrollListener);
    _horizontalScrollController.addListener(_horizontalScrollListener);

    _cargarDatosIniciales();
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _rotateController.dispose();
    _scrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  void _initAnimations() {
    _bounceController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _rotateController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );

    _bounceAnimation = Tween<double>(
      begin: 0.0,
      end: 10.0,
    ).animate(CurvedAnimation(
      parent: _bounceController,
      curve: Curves.elasticInOut,
    ));

    _rotateAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_rotateController);

    _bounceController.repeat(reverse: true);
    _rotateController.repeat();
  }

  // Listener para detectar scroll al final (scroll principal)
  void _scrollListener() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      // Este listener ya no se usa para cargar más fondos
      // Se mantiene para futuras funcionalidades si es necesario
    }
  }

  // Listener para detectar scroll horizontal al final
  void _horizontalScrollListener() {
    if (_horizontalScrollController.position.pixels >=
        _horizontalScrollController.position.maxScrollExtent - 100) {
      // Cargar más datos cuando esté a 100px del final horizontalmente
      if (!_isLoadingMore && _hasMoreData) {
        _cargarMasFondos();
      }
    }
  }




  // Obtener datos del usuario guardados localmente
  Future<Map<String, dynamic>?> _getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('userData');

    if (userDataString != null) {
      try {
        final userData = jsonDecode(userDataString);
        log('👤 Usuario local encontrado: ${userData['userName']} (ID: ${userData['userId']})', type: LogType.info);
        return userData;
      } catch (e) {
        log('❌ Error al decodificar datos del usuario: $e', type: LogType.error);
        return null;
      }
    } else {
      log('⚠️ No hay datos de usuario guardados localmente', type: LogType.warning);
      return null;
    }
  }

  // ✅ NUEVO: Mostrar modal para buscar usuario en BD
  void _mostrarModalBusquedaUsuario() {
    final TextEditingController nombreController = TextEditingController();
    final TextEditingController codigoController = TextEditingController();
    bool buscando = false;
    String? errorBusqueda;
    Usuario? usuarioEncontrado;

    showDialog(
      context: context,
      barrierDismissible: false, // No se puede cerrar tocando fuera
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          title: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade400, Colors.purple.shade400],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Text("👤", style: TextStyle(fontSize: 30)),
              ),
              const SizedBox(height: 16),
              const Text(
                "Buscar mi usuario",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Si un admin te creó en un fondo,\nbúscate aquí 🔍",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Campo nombre
              const Text(
                "Tu nombre completo:",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade50, Colors.purple.shade50],
                  ),
                  border: Border.all(color: Colors.blue.shade200, width: 2),
                ),
                child: TextField(
                  controller: nombreController,
                  enabled: !buscando,
                  decoration: InputDecoration(
                    hintText: "Ej: María García",
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                    prefixIcon: Container(
                      margin: const EdgeInsets.all(12),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade400, Colors.purple.shade400],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text("🔍", style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
              ),
              const SizedBox(height: 20),

              // Campo código del fondo
              const Text(
                "Código del fondo donde te crearon:",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  gradient: LinearGradient(
                    colors: [Colors.pink.shade50, Colors.orange.shade50],
                  ),
                  border: Border.all(color: Colors.pink.shade200, width: 2),
                ),
                child: TextField(
                  controller: codigoController,
                  enabled: !buscando,
                  decoration: InputDecoration(
                    hintText: "Código del fondo",
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                    prefixIcon: Container(
                      margin: const EdgeInsets.all(12),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.pink.shade400, Colors.orange.shade400],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text("🔑", style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Mensaje de error
              if (errorBusqueda != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      const Text("❌", style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          errorBusqueda!,
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Usuario encontrado
              if (usuarioEncontrado != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      const Text("✅", style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Usuario encontrado: ${usuarioEncontrado!.nombre}",
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          actions: [
            // Botón crear cuenta (navegar a crear fondo)
            TextButton(
              onPressed: buscando ? null : () {
                Navigator.pop(context);
                navegarACrearFondo();
              },
              child: Text(
                "Crear cuenta",
                style: TextStyle(
                  color: buscando ? Colors.grey : Colors.blue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            // Botón buscar/acceder
            ElevatedButton(
              onPressed: buscando ? null : () async {
                final nombre = nombreController.text.trim();
                final codigo = codigoController.text.trim();

                if (nombre.isEmpty || codigo.isEmpty) {
                  setDialogState(() {
                    errorBusqueda = "Completa todos los campos";
                    usuarioEncontrado = null;
                  });
                  return;
                }

                setDialogState(() {
                  buscando = true;
                  errorBusqueda = null;
                  usuarioEncontrado = null;
                });

                try {
                  // Buscar usuario y validar acceso al fondo
                  final resultado = await _buscarYValidarUsuario(nombre, codigo);

                  if (resultado != null) {
                    // Usuario encontrado y validado
                    await _guardarUsuarioLocal(resultado);

                    Navigator.pop(context);
                    _mostrarSnackBar("¡Bienvenido de vuelta, ${resultado.nombre}! 🎉");
                    _cargarDatosIniciales(); // Recargar datos
                  }

                } catch (e) {
                  setDialogState(() {
                    errorBusqueda = e.toString();
                    usuarioEncontrado = null;
                  });
                } finally {
                  setDialogState(() {
                    buscando = false;
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: buscando
                  ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text("Buscando..."),
                ],
              )
                  : Text(
                usuarioEncontrado != null ? "Acceder" : "Buscar",
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ NUEVO: Buscar usuario en BD y validar acceso al fondo
  Future<Usuario?> _buscarYValidarUsuario(String nombre, String codigo) async {
    try {
      log('🔍 Buscando usuario: $nombre en fondo con código: $codigo', type: LogType.info);

      // 1. Buscar el fondo por código
      final fondo = await _apiService.getFondoByCodigo(codigo);
      if (fondo == null) {
        throw "Código de fondo no encontrado";
      }

      // 2. Buscar usuario por nombre en ese fondo específico
      final usuario = await _apiService.buscarUsuarioEnFondo(fondo.id!, nombre);
      if (usuario == null) {
        throw "Usuario '$nombre' no encontrado en este fondo";
      }

      log('✅ Usuario encontrado: ${usuario.nombre} (ID: ${usuario.id}) en fondo: ${fondo.nombre}',
          type: LogType.success);

      return usuario;

    } catch (e) {
      log('❌ Error en búsqueda de usuario: $e', type: LogType.error);
      rethrow;
    }
  }

  // ✅ NUEVO: Guardar usuario encontrado en SharedPreferences
  Future<void> _guardarUsuarioLocal(Usuario usuario) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      Map<String, dynamic> userData = {
        'userId': usuario.id.toString(),
        'userName': usuario.nombre,
        'fechaUltimoAcceso': DateTime.now().toIso8601String(),
      };

      await prefs.setString('userData', jsonEncode(userData));

      setState(() {
        _userData = userData;

      });

      log('✅ Usuario guardado localmente: ${usuario.nombre} (ID: ${usuario.id})',
          type: LogType.success);

    } catch (e) {
      log('❌ Error al guardar usuario local: $e', type: LogType.error);
      throw "Error al guardar datos del usuario";
    }
  }

  // Cargar fondos (primera página o página específica)
  Future<void> _cargarFondos({bool esRecarga = false}) async {
    if (_userData == null) {
      log('❌ No se pueden obtener fondos: usuario no identificado', type: LogType.warning);
      return;
    }

    final userId = int.parse(_userData!['userId']);

    if (esRecarga) {
      _currentPage = 0;
      _hasMoreData = true;
      _fondos.clear();
    }

    try {
      log('🚀 Cargando página $_currentPage de fondos con roles para usuario ID: $userId', type: LogType.api);

      // ✅ CAMBIO: Usar método que devuelve FondoConRolPage
      final fondoConRolPage = await _apiService.getFondosByUsuario(userId, _currentPage, _pageSize);

      setState(() {
        if (esRecarga) {
          _fondos = fondoConRolPage.content;
        } else {
          _fondos.addAll(fondoConRolPage.content);
        }

        _hasMoreData = !fondoConRolPage.last;
        _currentPage++;
        _error = null;
      });

      log('✅ Fondos con roles cargados: ${fondoConRolPage.content.length} nuevos, ${_fondos.length} total', type: LogType.success);

      // ✅ NUEVO: Log detallado de roles
      int adminCount = _fondos.where((f) => f.esAdmin).length;
      int userCount = _fondos.where((f) => f.esUser).length;
      log('👑 Admin en $adminCount fondos | 👤 User en $userCount fondos', type: LogType.info);

    } catch (e) {
      setState(() {
        _error = "Error al cargar fondos: $e";
      });
      log('💥 Error al cargar fondos: $e', type: LogType.error);
    }
  }

  // Cargar más fondos (para scroll infinito)
  Future<void> _cargarMasFondos() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      await _cargarFondos();
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  // Recargar datos (pull to refresh)
  Future<void> _recargarDatos() async {
    log('🔄 Recargando datos...', type: LogType.info);
    await _cargarFondos(esRecarga: true);
  }

  // Limpiar datos de SharedPreferences
  Future<void> _limpiarDatos() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Text("🗑️", style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text(
              "Limpiar datos",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        content: const Text(
          "¿Estás seguro de que quieres borrar todos los datos guardados? Tendrás que volver a iniciar sesión.",
          style: TextStyle(
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              "Cancelar",
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text(
              "Borrar",
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();

        setState(() {
          _userData = null;
          _fondos.clear();
          _currentPage = 0;
          _hasMoreData = true;
          _error = null;

        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Text("✅", style: TextStyle(fontSize: 16)),
                  SizedBox(width: 8),
                  Text(
                    "Datos borrados correctamente",
                    style: TextStyle(fontWeight: FontWeight.w600),
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

        log('🗑️ Datos de SharedPreferences limpiados correctamente', type: LogType.info);
      } catch (e) {
        log('❌ Error al limpiar datos: $e', type: LogType.error);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Text("❌", style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Text(
                    "Error al borrar datos: $e",
                    style: const TextStyle(fontWeight: FontWeight.w600),
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
      }
    }
  }

  void _mostrarSnackBar(String mensaje) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          mensaje,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void navegarACrearFondo() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CrearFondoPage()),
    ).then((_) {
      _recargarDatos();
    });
  }

  void navegarAUnirseFondo() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => UnirseFondoPage()),
    ).then((_) {
      _recargarDatos();
    });
  }

  void navegarAFondo(FondoConRol fondoConRol) {
    log('🎯 Navegando al fondo: ${fondoConRol.nombre} (ID: ${fondoConRol.id}) como ${fondoConRol.rolUsuario}',
        type: LogType.info);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HomeFondoPage(
          fondo: fondoConRol.toFondo(),
        ),
      ),
    ).then((_) {
      _cargarDatosIniciales(); // 🔄 Recargar todo al volver del fondo
    });
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
              Colors.purple.shade400,
              Colors.pink.shade300,
              Colors.orange.shade300,
              Colors.yellow.shade200,
            ],
            stops: const [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _recargarDatos,
            color: Colors.white,
            backgroundColor: Colors.purple.shade400,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                    child: _buildHeader(),
                  ),
                ),

                // ✅ NUEVO: Botón de búsqueda si no hay usuario
                if (_userData == null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: _buildBotonBusquedaUsuario(),
                    ),
                  ),

                // Lista de fondos (solo si hay usuario)
                if (_userData != null) _buildFondosSliverList(),

                // Resto del contenido
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        //_buildMainQuestion(),
                        _buildActionButtons(),
                        _buildFooter(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

// ✅ NUEVO: Botón simple para buscar usuario creado por admin
  Widget _buildBotonBusquedaUsuario() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.shade600.withOpacity(0.9),
            Colors.cyan.shade500.withOpacity(0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Text("🔍", style: TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "¿Te creó un admin?",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Si alguien ya te añadió a un fondo, búscate aquí 👤",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _mostrarModalBusquedaUsuario,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.blue.shade700,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("🔍", style: TextStyle(fontSize: 16)),
                  SizedBox(width: 8),
                  Text(
                    "Buscar mi usuario",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

// ✅ MODIFICADO: Simplifica _cargarDatosIniciales
  Future<void> _cargarDatosIniciales() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      _userData = await _getUserData();

      if (_userData != null) {
        // Si hay usuario, cargar sus fondos
        await _cargarFondos(esRecarga: true);
        log('✅ Usuario encontrado: ${_userData!['userName']}', type: LogType.success);
      } else {
        // Si no hay usuario, simplemente no mostrar fondos
        // El botón de búsqueda se mostrará automáticamente
        log('⚠️ No hay usuario guardado', type: LogType.warning);
      }
    } catch (e) {
      setState(() {
        _error = "Error al cargar datos iniciales: $e";
      });
      log('💥 Error en _cargarDatosIniciales: $e', type: LogType.error);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildPantallaFondos() {
    return RefreshIndicator(
      onRefresh: _recargarDatos,
      color: Colors.white,
      backgroundColor: Colors.purple.shade400,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: _buildHeader(),
            ),
          ),

          // Lista de fondos
          _buildFondosSliverList(),

          // Resto del contenido
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                //  _buildMainQuestion(),
                  _buildActionButtons(),
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        children: [
          // Fila superior con botón de limpiar datos
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Botón pequeño para limpiar datos
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: IconButton(
                  onPressed: _limpiarDatos,
                  icon: const Text("🗑️", style: TextStyle(fontSize: 16)),
                  iconSize: 16,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  tooltip: "Limpiar datos guardados",
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Logo animado
          AnimatedBuilder(
            animation: _bounceAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _bounceAnimation.value),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white,
                        Colors.purple.shade50,
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.purple.withOpacity(0.3),
                        spreadRadius: 2,
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Text(
                    "🎒✈️",
                    style: TextStyle(fontSize: 32),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Título
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [
                Colors.white,
                Colors.yellow.shade100,
              ],
            ).createShader(bounds),
            child: const Text(
              "FondosViajeros",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 5),

          // Subtítulo
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: const Text(
              "¡Tu crew, tu viaje, tu aventura! 🚀",
              style: TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildMainQuestion() {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 15,
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            "¿Qué vibe eliges hoy? 🤔",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            "Elige tu mood y ¡let's go! 🔥",
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Botón Crear Fondo
        Container(
          width: double.infinity,
          height: 65,
          margin: const EdgeInsets.only(bottom: 12),
          child: ElevatedButton(
            onPressed: navegarACrearFondo,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black87,
              foregroundColor: Colors.white,
              elevation: 8,
              shadowColor: Colors.black.withOpacity(0.3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.purple.shade400, Colors.pink.shade300],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text("🎯", style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Crear mi squad 🔥",
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        "Sé el líder del grupo ✨",
                        style: TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                AnimatedBuilder(
                  animation: _rotateController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _rotateAnimation.value * 2 * 3.14159,
                      child: const Text("⭐", style: TextStyle(fontSize: 14)),
                    );
                  },
                ),
              ],
            ),
          ),
        ),

        // Botón Unirse
        Container(
          width: double.infinity,
          height: 65,
          margin: const EdgeInsets.only(bottom: 20),
          child: ElevatedButton(
            onPressed: navegarAUnirseFondo,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              elevation: 8,
              shadowColor: Colors.purple.withOpacity(0.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange.shade300, Colors.pink.shade300],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text("🎉", style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Join the party! 🎊",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        "Únete a la aventura 🌟",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Text("💫", style: TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("🌍", style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              children: [
                const Text(
                  "Ready para tu next adventure?",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  "El mundo te está esperando ✈️",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const Text("✨", style: TextStyle(fontSize: 16)),
        ],
      ),
    );
  }



  Widget _buildFondoHorizontalCard(FondoConRol fondoConRol) {
    final esAdmin = fondoConRol.esAdmin;

    return GestureDetector(
      onTap: () => navegarAFondo(fondoConRol),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: esAdmin
                    ? Colors.yellow.withOpacity(0.6)
                    : Colors.cyan.withOpacity(0.6),
                spreadRadius: 2,
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                spreadRadius: 0,
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Fondo principal
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: esAdmin
                      ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.purple.shade600,
                      Colors.pink.shade500,
                      Colors.orange.shade400,
                      Colors.yellow.shade300,
                    ],
                    stops: const [0.0, 0.3, 0.7, 1.0],
                  )
                      : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.indigo.shade600,
                      Colors.blue.shade500,
                      Colors.cyan.shade400,
                      Colors.teal.shade300,
                    ],
                    stops: const [0.0, 0.3, 0.7, 1.0],
                  ),
                ),
              ),
              // Overlay
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.2),
                      Colors.white.withOpacity(0.05),
                      Colors.black.withOpacity(0.1),
                    ],
                  ),
                ),
              ),
              // Glow border
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icono
                    Container(
                      width: 35,
                      height: 35,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white,
                            esAdmin ? Colors.yellow.shade100 : Colors.cyan.shade100,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: esAdmin
                                ? Colors.yellow.withOpacity(0.8)
                                : Colors.cyan.withOpacity(0.8),
                            spreadRadius: 2,
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.white.withOpacity(0.5),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          esAdmin ? "👑" : "💎",
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Nombre
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        fondoConRol.nombre,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black,
                              offset: Offset(0.5, 0.5),
                              blurRadius: 1,
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    // Badge + Monto
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: esAdmin
                                ? LinearGradient(
                              colors: [Colors.yellow.shade400, Colors.orange.shade500],
                            )
                                : LinearGradient(
                              colors: [Colors.cyan.shade400, Colors.blue.shade500],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: esAdmin
                                    ? Colors.orange.withOpacity(0.6)
                                    : Colors.blue.withOpacity(0.6),
                                spreadRadius: 1,
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                            border: Border.all(
                              color: Colors.white.withOpacity(0.8),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            esAdmin ? "BOSS" : "CREW",
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.4,
                              shadows: [
                                Shadow(
                                  color: Colors.black,
                                  offset: Offset(0.4, 0.4),
                                  blurRadius: 0.8,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.5),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withOpacity(0.3),
                                spreadRadius: 1,
                                blurRadius: 3,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Text(
                            '${fondoConRol.monto}€',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.4,
                              shadows: [
                                Shadow(
                                  color: Colors.cyan,
                                  offset: Offset(0, 0),
                                  blurRadius: 3,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    // Código
                    Text(
                      fondoConRol.codigo,
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.white.withOpacity(0.75),
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.7,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              // Efecto brillo
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withOpacity(0.6),
                        Colors.white.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFondosSliverList() {
    // Loading inicial
    if (_isLoading) {
      return SliverToBoxAdapter(
        child: Container(
          height: 120,
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                SizedBox(height: 12),
                Text(
                  "Cargando tus fondos... ✨",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Error
    if (_error != null) {
      return SliverToBoxAdapter(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.red.withOpacity(0.3)),
          ),
          child: Center(
            child: Column(
              children: [
                Text(
                  "Error al cargar fondos 😅",
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: _recargarDatos,
                  child: Text(
                    "Toca para reintentar",
                    style: TextStyle(
                      color: Colors.red.shade600,
                      fontSize: 12,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Lista vacía
    if (_fondos.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    // Lista con fondos horizontal MEJORADA
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header de la sección mejorado
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.2),
                        Colors.white.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("💰", style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Text(
                        "Tus fondos activos",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.5),
                              offset: const Offset(1, 1),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.yellow.shade400, Colors.orange.shade500],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.5),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white.withOpacity(0.8),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    "${_fondos.length}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(
                          color: Colors.black,
                          offset: Offset(0.5, 0.5),
                          blurRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Lista horizontal de fondos - MÁS COMPACTA
          Container(
            height: 145, // ✅ REDUCIDO de 160 a 140
            child: ListView.builder(
              controller: _horizontalScrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _fondos.length + (_isLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                // Mostrar loading al final si se están cargando más datos
                if (index == _fondos.length) {
                  return Container(
                    width: 100,
                    margin: const EdgeInsets.only(left: 8),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.cyan.shade400, Colors.blue.shade600],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.cyan.withOpacity(0.5),
                                  spreadRadius: 2,
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Loading...",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Container(
                  width: 220, // ✅ REDUCIDO de 130 a 110
                  margin: EdgeInsets.only(
                    right: 10, // ✅ REDUCIDO spacing
                    left: index == 0 ? 0 : 0,
                  ),
                  child: _buildFondoHorizontalCard(_fondos[index]),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}