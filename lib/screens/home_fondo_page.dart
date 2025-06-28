import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/fondo.dart';
import '../model/movimiento.dart';
import '../apirest/api_service.dart';
import '../utils/logger.dart';
import 'crear_movimiento_page.dart';

class HomeFondoPage extends StatefulWidget {
  final Fondo fondo; // Ahora es requerido

  const HomeFondoPage({Key? key, required this.fondo}) : super(key: key);

  @override
  State<HomeFondoPage> createState() => _HomeFondoPageState();
}

class _HomeFondoPageState extends State<HomeFondoPage>
    with TickerProviderStateMixin {

  final ApiService _apiService = ApiService();

  // Variables del fondo
  late String nombreFondo;
  late String codigoFondo;
  late int fondoId;
  double montoTotal = 0.0; // Calculado a partir de movimientos
  int totalMiembros = 1; // TODO: Implementar conteo real de miembros

  // Variables para paginación de movimientos
  final ScrollController _scrollController = ScrollController();
  List<Movimiento> _movimientos = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  int _currentPage = 0;
  final int _pageSize = 20;
  String? _error;

  // Animaciones
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _initializarDatos();
    _initAnimations();
    _scrollController.addListener(_scrollListener);
    _cargarDatosIniciales();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initializarDatos() {
    nombreFondo = widget.fondo.nombre;
    codigoFondo = widget.fondo.codigo;
    fondoId = widget.fondo.id!;
    log('🏠 Inicializando fondo: $nombreFondo (ID: $fondoId)', type: LogType.info);
  }

  void _initAnimations() {
    _shimmerController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _shimmerAnimation = Tween<double>(
      begin: -200.0,
      end: 200.0,
    ).animate(CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.easeInOut,
    ));

    _shimmerController.repeat();
  }

  // Listener para scroll infinito
  void _scrollListener() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMoreData) {
        _cargarMasMovimientos();
      }
    }
  }

  // Cargar datos iniciales
  Future<void> _cargarDatosIniciales() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _cargarMovimientos(esRecarga: true);
    } catch (e) {
      setState(() {
        _error = "Error al cargar movimientos: $e";
      });
      log('💥 Error en _cargarDatosIniciales: $e', type: LogType.error);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Cargar movimientos (primera página o página específica)
  Future<void> _cargarMovimientos({bool esRecarga = false}) async {
    if (esRecarga) {
      _currentPage = 0;
      _hasMoreData = true;
      _movimientos.clear();
      montoTotal = 0.0;
    }

    try {
      log('🚀 Cargando página $_currentPage de movimientos para fondo ID: $fondoId', type: LogType.api);

      final movimientoPage = await _apiService.getMovimientosByFondo(
          fondoId,
          _currentPage,
          _pageSize
      );

      setState(() {
        if (esRecarga) {
          _movimientos = movimientoPage.content;
        } else {
          _movimientos.addAll(movimientoPage.content);
        }

        _hasMoreData = !movimientoPage.last;
        _currentPage++;
        _error = null;

        // Recalcular monto total
        _calcularMontoTotal();
      });

      log('✅ Movimientos cargados: ${movimientoPage.content.length} nuevos, ${_movimientos.length} total',
          type: LogType.success);
      log('💰 Monto total calculado: $montoTotal', type: LogType.info);

    } catch (e) {
      setState(() {
        _error = "Error al cargar movimientos: $e";
      });
      log('💥 Error al cargar movimientos: $e', type: LogType.error);
    }
  }

  // Cargar más movimientos (para scroll infinito)
  Future<void> _cargarMasMovimientos() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      await _cargarMovimientos();
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  // Calcular monto total basado en movimientos
  void _calcularMontoTotal() {
    double total = 0.0;
    for (final movimiento in _movimientos) {
      if (movimiento.tipo.toLowerCase() == 'aporte') {
        total += movimiento.cantidad;
        log('➕ APORTE: +${movimiento.cantidad} | Total actual: $total', type: LogType.info);
      } else if (movimiento.tipo.toLowerCase() == 'gasto') {
        total -= movimiento.cantidad;
        log('➖ GASTO: -${movimiento.cantidad} | Total actual: $total', type: LogType.info);
      } else {
        log('⚠️ Tipo de movimiento desconocido: ${movimiento.tipo}', type: LogType.warning);
      }
    }
    montoTotal = total;
    log('💰 Monto total final calculado: $montoTotal', type: LogType.success);
  }

  // Recargar datos (pull to refresh)
  Future<void> _recargarDatos() async {
    log('🔄 Recargando movimientos...', type: LogType.info);
    await _cargarMovimientos(esRecarga: true);
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
              Colors.pink.shade300,
              Colors.orange.shade200,
            ],
            stops: const [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header personalizado
              _buildHeader(),

              // Card principal del monto del fondo (1/3 de la pantalla)
              Expanded(
                flex: 1,
                child: _buildMontoCard(),
              ),

              // Lista de movimientos (2/3 de la pantalla)
              Expanded(
                flex: 2,
                child: _buildMovimientosList(),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(),
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
                  nombreFondo,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  "Código: $codigoFondo • $totalMiembros miembros",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
              ),
            ),
            child: IconButton(
              onPressed: () {
                // TODO: Implementar opciones
              },
              icon: const Icon(
                Icons.more_vert,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMontoCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.purple.shade50,
              Colors.pink.shade50,
            ],
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              spreadRadius: 4,
              blurRadius: 20,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icono principal
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.purple.shade400,
                    Colors.pink.shade400,
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withOpacity(0.4),
                    spreadRadius: 2,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Text(
                "💰",
                style: TextStyle(fontSize: 25),
              ),
            ),
            const SizedBox(height: 12),

            // Título
            const Text(
              "Fondo Total",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 8),

            // Monto principal (calculado)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.purple.shade100,
                    Colors.pink.shade100,
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.purple.shade200,
                  width: 2,
                ),
              ),
              child: Text(
                "${montoTotal.toStringAsFixed(2)} €",
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: montoTotal >= 0 ? Colors.purple.shade700 : Colors.red.shade700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMovimientosList() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.only(top: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          // Header de movimientos
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                const Text(
                  "Movimientos recientes 📝",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.purple.shade100,
                        Colors.pink.shade100,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    "${_movimientos.length}",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.purple.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Lista de movimientos
          Expanded(
            child: _buildMovimientosContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildMovimientosContent() {
    // Loading inicial
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.purple),
            SizedBox(height: 16),
            Text(
              "Cargando movimientos... ✨",
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    // Error
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("❌", style: TextStyle(fontSize: 40)),
            const SizedBox(height: 16),
            Text(
              "Error al cargar movimientos",
              style: TextStyle(
                color: Colors.red.shade700,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _recargarDatos,
              child: const Text("Reintentar"),
            ),
          ],
        ),
      );
    }

    // Lista vacía
    if (_movimientos.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("🏝️", style: TextStyle(fontSize: 40)),
            SizedBox(height: 16),
            Text(
              "Aún no hay movimientos",
              style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 8),
            Text(
              "¡Sé el primero en añadir dinero! 💰",
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    // Lista con movimientos
    return RefreshIndicator(
      onRefresh: _recargarDatos,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: _movimientos.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          // Mostrar loading al final si se están cargando más datos
          if (index == _movimientos.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(color: Colors.purple),
              ),
            );
          }

          return _buildMovimientoItem(_movimientos[index], index);
        },
      ),
    );
  }

  Widget _buildMovimientoItem(Movimiento movimiento, int index) {
    final esAporte = movimiento.tipo.toLowerCase() == 'aporte';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: esAporte
              ? Colors.green.shade200
              : Colors.red.shade200,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: esAporte
                ? Colors.green.withOpacity(0.1)
                : Colors.red.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icono del movimiento
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: esAporte
                    ? [Colors.green.shade400, Colors.teal.shade400]
                    : [Colors.red.shade400, Colors.pink.shade400],
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Text(
              esAporte ? "💰" : "💸",
              style: const TextStyle(fontSize: 20),
            ),
          ),
          const SizedBox(width: 16),

          // Información del movimiento
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        movimiento.usuario?.nombre ?? "Usuario #${movimiento.usuario.id}",
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Text(
                      "${esAporte ? '+' : '-'}${movimiento.cantidad.toStringAsFixed(2)} €",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: esAporte
                            ? Colors.green.shade600
                            : Colors.red.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  movimiento.concepto,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    // Badge del tipo de movimiento
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: esAporte
                            ? Colors.green.shade100
                            : Colors.red.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: esAporte
                              ? Colors.green.shade300
                              : Colors.red.shade300,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        movimiento.tipo,
                        style: TextStyle(
                          fontSize: 9,
                          color: esAporte
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _formatearFecha(movimiento.fecha),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatearFecha(DateTime fecha) {
    final now = DateTime.now();
    final difference = now.difference(fecha);

    if (difference.inDays > 7) {
      return "${fecha.day}/${fecha.month}/${fecha.year}";
    } else if (difference.inDays > 0) {
      return "Hace ${difference.inDays} días";
    } else if (difference.inHours > 0) {
      return "Hace ${difference.inHours} horas";
    } else if (difference.inMinutes > 0) {
      return "Hace ${difference.inMinutes} minutos";
    } else {
      return "Ahora mismo";
    }
  }

  Widget _buildFloatingActionButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.purple.shade400,
            Colors.pink.shade400,
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.4),
            spreadRadius: 3,
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: () {
          _mostrarModalMovimiento();
        },
        backgroundColor: Colors.transparent,
        elevation: 0,
        label: const Text(
          "Añadir 💫",
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        icon: const Icon(
          Icons.add,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  void _mostrarModalMovimiento() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle del modal
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                "¿Qué quieres hacer? 🤔",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      "💰",
                      "Hacer aporte",
                      "Añadir dinero al fondo",
                      Colors.green,
                          () async {
                        Navigator.pop(context); // Cerrar modal
                        final resultado = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CrearMovimientoPage(
                              fondo: widget.fondo,
                              tipoMovimiento: "APORTE",
                            ),
                          ),
                        );

                        // Si se creó exitosamente, recargar datos
                        if (resultado == true) {
                          _recargarDatos();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildActionButton(
                      "💸",
                      "Registrar gasto",
                      "Nueva compra grupal",
                      Colors.red,
                          () async {
                        Navigator.pop(context); // Cerrar modal
                        final resultado = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CrearMovimientoPage(
                              fondo: widget.fondo,
                              tipoMovimiento: "GASTO",
                            ),
                          ),
                        );

                        // Si se creó exitosamente, recargar datos
                        if (resultado == true) {
                          _recargarDatos();
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
      String emoji,
      String title,
      String subtitle,
      MaterialColor color,
      VoidCallback onTap,
      ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 40),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: color.shade700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: color.shade600,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}