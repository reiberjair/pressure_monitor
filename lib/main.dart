import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

void main() => runApp(const PressureApp());

class PressureApp extends StatelessWidget {
  const PressureApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pressure Monitor',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF101318),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF49D7B0),
          brightness: Brightness.dark,
        ),
        sliderTheme: const SliderThemeData(
          showValueIndicator: ShowValueIndicator.always,
        ),
      ),
      home: const Dashboard(),
    );
  }
}

enum DemoState { normal, lowPressure, sensorFault, disconnected }

class Sample {
  final DateTime time;
  final double psi;

  const Sample(this.time, this.psi);
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final _random = math.Random();
  final List<Sample> _samples = [];
  late final Timer _timer;

  DemoState _state = DemoState.normal;
  bool _paused = false;
  bool _useBar = false;
  bool _fuel = false;
  double _pressurePsi = 45;
  double _warningPsi = 20;
  DateTime? _lastReading;
  int _tab = 0;

  double get _displayPressure =>
      _useBar ? _pressurePsi / 14.5038 : _pressurePsi;

  String get _unit => _useBar ? 'bar' : 'PSI';

  bool get _stale =>
      _lastReading == null ||
          DateTime.now().difference(_lastReading!).inMilliseconds > 2000;

  bool get _valid =>
      !_stale &&
          _state != DemoState.sensorFault &&
          _state != DemoState.disconnected;

  bool get _low => _valid && _pressurePsi < _warningPsi;

  String get _status {
    if (_state == DemoState.disconnected) return 'Desconectado';
    if (_state == DemoState.sensorFault) return 'Fallo de sensor';
    if (_stale) return 'Lectura vencida';
    if (_low) return 'Presión baja';
    if (_paused) return 'Demo pausada';
    return 'Lectura activa';
  }

  Color get _statusColor {
    if (!_valid) return Colors.orangeAccent;
    if (_low) return Colors.redAccent;
    return const Color(0xFF49D7B0);
  }

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(
      const Duration(milliseconds: 100),
          (_) => _tick(),
    );
  }

  void _tick() {
    if (!mounted) return;
    final now = DateTime.now();

    setState(() {
      if (!_paused &&
          _state != DemoState.disconnected &&
          _state != DemoState.sensorFault) {
        final baseline = _state == DemoState.lowPressure
            ? 8.0
            : (_fuel ? 58.0 : 45.0);

        final wave =
            math.sin(now.millisecondsSinceEpoch / 1300.0) * 2.5;
        final noise = (_random.nextDouble() - 0.5) * 1.2;

        _pressurePsi = math.max(0.0, baseline + wave + noise);
        _lastReading = now;
        _samples.add(Sample(now, _pressurePsi));
      }

      _samples.removeWhere(
            (sample) => now.difference(sample.time).inSeconds >= 30,
      );
    });
  }

  void _changeSensor(bool fuel) {
    setState(() {
      _fuel = fuel;
      _samples.clear();
      _lastReading = null;
      _state = DemoState.normal;
      _paused = false;
    });
    _tick();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [_dashboard(), _devices(), _settings()];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'PRESSURE',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Chip(
              avatar: const Icon(Icons.science_outlined, size: 18),
              label: const Text('DEMO'),
              backgroundColor: Colors.white10,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: pages[_tab],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) =>
            setState(() => _tab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.speed_outlined),
            selectedIcon: Icon(Icons.speed),
            label: 'Presión',
          ),
          NavigationDestination(
            icon: Icon(Icons.bluetooth),
            label: 'Dispositivo',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Ajustes',
          ),
        ],
      ),
    );
  }

  List<Widget> _dashboard() {
    return [
      const Text(
        'MONITOR DEL VEHÍCULO',
        style: TextStyle(
          color: Colors.white54,
          letterSpacing: 1.5,
          fontSize: 12,
        ),
      ),
      const SizedBox(height: 16),
      SegmentedButton<bool>(
        segments: const [
          ButtonSegment(
            value: false,
            label: Text('Aceite'),
            icon: Icon(Icons.water_drop_outlined),
          ),
          ButtonSegment(
            value: true,
            label: Text('Combustible'),
            icon: Icon(Icons.local_gas_station_outlined),
          ),
        ],
        selected: {_fuel},
        onSelectionChanged: (values) =>
            _changeSensor(values.first),
      ),
      const SizedBox(height: 20),
      _panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.circle, size: 10, color: _statusColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _status,
                    style: TextStyle(color: _statusColor),
                  ),
                ),
                Text(_unit, style: const TextStyle(color: Colors.white54)),
              ],
            ),
            const SizedBox(height: 20),
            Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _valid
                      ? _displayPressure.toStringAsFixed(1)
                      : '—',
                  style: TextStyle(
                    fontSize: 88,
                    fontWeight: FontWeight.w300,
                    color: _statusColor,
                    letterSpacing: -4,
                  ),
                ),
              ),
            ),
            Center(
              child: Text(
                'Presión de ${_fuel ? 'combustible' : 'aceite'}',
                style: const TextStyle(color: Colors.white54),
              ),
            ),
            const SizedBox(height: 24),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: _valid
                    ? (_pressurePsi / 100).clamp(0.0, 1.0)
                    : 0,
                color: _statusColor,
                backgroundColor: Colors.white10,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('0 $_unit'),
                Text(
                  '${_useBar ? '6.9' : '100'} $_unit',
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Últimos 30 segundos',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Escala fija · 0–${_useBar ? '6.9 bar' : '100 PSI'}',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 150,
              width: double.infinity,
              child: CustomPaint(
                painter: PressureChart(
                  samples: List.of(_samples),
                  now: DateTime.now(),
                  color: _statusColor,
                  warningPsi: _warningPsi,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Simulador',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<DemoState>(
              initialValue: _state,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Escenario de prueba',
              ),
              items: const [
                DropdownMenuItem(
                  value: DemoState.normal,
                  child: Text('Presión normal'),
                ),
                DropdownMenuItem(
                  value: DemoState.lowPressure,
                  child: Text('Presión baja'),
                ),
                DropdownMenuItem(
                  value: DemoState.sensorFault,
                  child: Text('Fallo del sensor'),
                ),
                DropdownMenuItem(
                  value: DemoState.disconnected,
                  child: Text('Pérdida de conexión'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _state = value;
                  _lastReading = null;
                });
                _tick();
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () =>
                    setState(() => _paused = !_paused),
                icon: Icon(
                  _paused ? Icons.play_arrow : Icons.pause,
                ),
                label: Text(
                  _paused ? 'Reanudar demo' : 'Pausar demo',
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Datos generados en la app. Sin conexión Bluetooth.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _devices() {
    return [
      _panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.bluetooth,
              size: 48,
              color: Color(0xFF49D7B0),
            ),
            const SizedBox(height: 16),
            const Text(
              'Fuente de datos: simulador',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Esta versión permite probar la interfaz sin hardware. '
                  'Todavía no escanea ni conecta dispositivos BLE.',
            ),
            const SizedBox(height: 16),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.science_outlined),
              title: Text('Pressure Demo'),
              subtitle: Text('Actualización cada 100 ms'),
            ),
            FilledButton(
              onPressed: () => setState(() => _tab = 0),
              child: const Text('Abrir dashboard'),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _settings() {
    final threshold =
    _useBar ? _warningPsi / 14.5038 : _warningPsi;

    return [
      _panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Visualización',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Mostrar en bar'),
              subtitle: const Text('Desactivado: mostrar en PSI'),
              value: _useBar,
              onChanged: (value) =>
                  setState(() => _useBar = value),
            ),
            const Divider(),
            const SizedBox(height: 12),
            const Text('Umbral de presión baja'),
            const SizedBox(height: 8),
            Text(
              '${threshold.toStringAsFixed(1)} $_unit',
              style: const TextStyle(
                fontSize: 30,
                color: Color(0xFF49D7B0),
              ),
            ),
            Slider(
              min: 0,
              max: 80,
              divisions: 80,
              value: _warningPsi,
              label: '${threshold.toStringAsFixed(1)} $_unit',
              onChanged: (value) =>
                  setState(() => _warningPsi = value),
            ),
            const Text(
              'Umbral de demostración configurable. '
                  'Los ajustes se restablecen al reiniciar la app.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _panel(Widget child) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F27),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: child,
    );
  }
}

class PressureChart extends CustomPainter {
  final List<Sample> samples;
  final DateTime now;
  final Color color;
  final double warningPsi;

  PressureChart({
    required this.samples,
    required this.now,
    required this.color,
    required this.warningPsi,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1;

    for (var i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }

    final warningY = size.height * (1 - warningPsi / 100);
    canvas.drawLine(
      Offset(0, warningY),
      Offset(size.width, warningY),
      Paint()
        ..color = Colors.redAccent.withValues(alpha: 0.4)
        ..strokeWidth = 1,
    );

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    Sample? previous;

    for (final sample in samples) {
      final age =
          now.difference(sample.time).inMilliseconds / 1000;
      if (age < 0 || age > 30) continue;

      final point = Offset(
        size.width * (1 - age / 30),
        size.height * (1 - sample.psi.clamp(0.0, 100.0) / 100),
      );

      // No unir segmentos separados por una pausa o desconexión.
      if (previous == null ||
          sample.time.difference(previous.time).inMilliseconds > 500) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
      previous = sample;
    }

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant PressureChart oldDelegate) => true;
}