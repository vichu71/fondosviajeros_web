import 'package:flutter/material.dart';
import '../model/fondo_con_rol.dart';
import 'crear_fondo_page.dart';
import 'unirse_fondo_page.dart';
import 'home_fondo_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../apirest/api_service.dart';
import '../model/fondo.dart';
import '../utils/logger.dart';

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

  // Cargar datos iniciales (usuario + primera página de fondos)
  Future<void> _cargarDatosIniciales() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      _userData = await _getUserData();
      if (_userData != null) {
        await _cargarFondos(esRecarga: true);
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
          fondo: fondoConRol.toFondo(), // ← Convertir a Fondo para compatibilidad
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

                // Lista de fondos
                _buildFondosSliverList(),

                // Resto del contenido
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        _buildMainQuestion(),
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
          const SizedBox(height: 6),

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

    // Lista con fondos horizontal
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header de la sección
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(
              children: [
                Text(
                  "Tus fondos activos 💰",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.3),
                        offset: const Offset(1, 1),
                        blurRadius: 3,
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "${_fondos.length}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Lista horizontal de fondos
          Container(
            height: 160, // Altura fija para el scroll horizontal
            child: ListView.builder(
              controller: _horizontalScrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _fondos.length + (_isLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                // Mostrar loading al final si se están cargando más datos
                if (index == _fondos.length) {
                  return Container(
                    width: 120,
                    margin: const EdgeInsets.only(left: 8),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            "Cargando...",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
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
                  width: 130, // Ancho fijo para cada tarjeta
                  margin: EdgeInsets.only(
                    right: 12,
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
          const SizedBox(height: 6),
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
    // ✅ CAMBIO PRINCIPAL: Usar rol real del fondoConRol
    final esAdmin = fondoConRol.esAdmin;

    return GestureDetector(
      onTap: () => navegarAFondo(fondoConRol),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            // ✅ COLORES DIFERENCIADOS: Verde para admin, azul para user
            colors: esAdmin
                ? [Colors.green.shade400, Colors.teal.shade300]
                : [Colors.blue.shade400, Colors.indigo.shade300],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: (esAdmin ? Colors.green : Colors.blue).withOpacity(0.3),
              spreadRadius: 1,
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ✅ ICONO DIFERENCIADO: Corona para admin, fiesta para user
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 3,
                    ),
                  ],
                ),
                child: Text(
                  esAdmin ? "👑" : "👤",  // ← Iconos diferenciados
                  style: const TextStyle(fontSize: 20),
                ),
              ),
              const SizedBox(height: 8),

              // Nombre del fondo
              Text(
                fondoConRol.nombre,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
              const SizedBox(height: 6),

              // ✅ NUEVO: Badge de rol
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  esAdmin ? "ADMIN" : "MEMBER",
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    color: esAdmin ? Colors.green.shade700 : Colors.blue.shade700,
                  ),
                ),
              ),
              const SizedBox(height: 4),

              // Monto
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${fondoConRol.monto} €',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 4),

              // Código
              Text(
                fondoConRol.codigo,
                style: const TextStyle(
                  fontSize: 8,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}