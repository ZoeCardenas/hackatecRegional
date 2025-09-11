// lib/pages/analisis.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// Modelo simple para cada registro (se adapta si tu backend devuelve score.{total,risk_level} o total/risk_level planos)
class Assessment {
  final DateTime createdAt;
  final int total;
  final int riskLevel;

  Assessment({
    required this.createdAt,
    required this.total,
    required this.riskLevel,
  });

  factory Assessment.fromMap(Map<String, dynamic> m) {
    // intenta varias rutas donde podría estar la info
    dynamic score = m['score'] ?? m;
    int total = 0;
    int risk = 0;

    if (score is Map) {
      total = (score['total'] ?? score['Total'] ?? m['total'] ?? 0).toInt();
      risk = (score['risk_level'] ??
              score['riskLevel'] ??
              m['risk_level'] ??
              m['riskLevel'] ??
              0)
          .toInt();
    } else {
      total = (m['total'] ?? 0).toInt();
      risk = (m['risk_level'] ?? 0).toInt();
    }

    DateTime created;
    try {
      created = DateTime.parse(m['created_at'] ??
          m['createdAt'] ??
          DateTime.now().toIso8601String());
    } catch (_) {
      created = DateTime.now();
    }

    return Assessment(createdAt: created, total: total, riskLevel: risk);
  }
}

/// Página de análisis con dos gráficas simples (línea) hechas con CustomPaint
class AnalisisPage extends StatefulWidget {
  const AnalisisPage({Key? key}) : super(key: key);

  @override
  State<AnalisisPage> createState() => _AnalisisPageState();
}

class _AnalisisPageState extends State<AnalisisPage> {
  final TextEditingController _emailController = TextEditingController();
  final String apiBase =
      'http://127.0.0.1:8000/assessments'; // ajusta si tu endpoint cambia
  bool loading = false;
  String? error;
  List<Assessment> assessments = [];

  Future<void> _loadData() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => error = 'Ingresa el correo (user_id) del usuario.');
      return;
    }

    setState(() {
      loading = true;
      error = null;
      assessments = [];
    });

    try {
      final uri =
          Uri.parse(apiBase).replace(queryParameters: {'user_id': email});
      final resp = await http.get(uri).timeout(const Duration(seconds: 10));

      if (resp.statusCode != 200) {
        setState(() => error = 'Error servidor: ${resp.statusCode}');
        return;
      }

      final List<dynamic> data = jsonDecode(resp.body) as List<dynamic>;
      final parsed = data
          .map((e) {
            if (e is Map<String, dynamic>) return Assessment.fromMap(e);
            if (e is Map)
              return Assessment.fromMap(Map<String, dynamic>.from(e));
            return null;
          })
          .whereType<Assessment>()
          .toList();

      parsed.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      setState(() {
        assessments = parsed;
      });
    } catch (e) {
      setState(() => error = 'Error de red o parseo: $e');
    } finally {
      setState(() => loading = false);
    }
  }

  // util: mínimo y máximo con pequeño padding (para que la gráfica no quede "pegada")
  double _minWithPadding(List<int> vals) {
    if (vals.isEmpty) return 0;
    int minv = vals.reduce((a, b) => a < b ? a : b);
    double pad = (minv == 0) ? 1.0 : minv * 0.05;
    double val = (minv - pad);
    return val < 0 ? 0 : val;
  }

  double _maxWithPadding(List<int> vals) {
    if (vals.isEmpty) return 10;
    int maxv = vals.reduce((a, b) => a > b ? a : b);
    double pad = (maxv == 0) ? 5.0 : maxv * 0.05;
    return maxv + pad;
  }

  String _shortDate(DateTime d) => '${d.day}/${d.month}';

  @override
  Widget build(BuildContext context) {
    final totals = assessments.map((e) => e.total).toList();
    final risks = assessments.map((e) => e.riskLevel).toList();

    final minTotal = _minWithPadding(totals);
    final maxTotal = _maxWithPadding(totals);
    final minRisk = _minWithPadding(risks);
    final maxRisk = _maxWithPadding(risks);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Análisis psicológico (DASS-21)'),
        backgroundColor: const Color.fromARGB(255, 102, 146, 111),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(children: [
          // Input para correo y botón cargar
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Correo del usuario (user_id)',
                    border: OutlineInputBorder(),
                    hintText: 'ejemplo@correo.com',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 102, 146, 111)),
                onPressed: loading ? null : _loadData,
                child: loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Cargar'),
              )
            ],
          ),
          const SizedBox(height: 12),
          if (error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: Colors.red[50],
              child: Text(error!, style: const TextStyle(color: Colors.red)),
            ),
          const SizedBox(height: 8),

          // Charts
          Expanded(
            child: assessments.isEmpty
                ? Center(
                    child: Text(loading
                        ? 'Cargando...'
                        : 'No hay datos. Carga el correo del usuario.'))
                : SingleChildScrollView(
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Chart total
                            Expanded(
                              child: Card(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text('Puntaje total (DASS-21)',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        height: 220,
                                        child: CustomPaint(
                                          painter: _LineChartPainter(
                                            points: totals
                                                .map((e) => e.toDouble())
                                                .toList(),
                                            minY: minTotal,
                                            maxY: maxTotal,
                                            labels: assessments
                                                .map((e) =>
                                                    _shortDate(e.createdAt))
                                                .toList(),
                                          ),
                                          child: Container(),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            children: [
                                              // intenta cargar asset; si falla, fallback con icon
                                              Image.asset(
                                                'assets/imagenes/min_total.png',
                                                height: 40,
                                                width: 40,
                                                errorBuilder: (c, o, s) =>
                                                    const Icon(
                                                        Icons.arrow_downward,
                                                        size: 36),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                  'Min: ${totals.reduce((a, b) => a < b ? a : b)}')
                                            ],
                                          ),
                                          Column(
                                            children: [
                                              Image.asset(
                                                'assets/imagenes/max_total.png',
                                                height: 40,
                                                width: 40,
                                                errorBuilder: (c, o, s) =>
                                                    const Icon(
                                                        Icons.arrow_upward,
                                                        size: 36),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                  'Máx: ${totals.reduce((a, b) => a > b ? a : b)}')
                                            ],
                                          ),
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(width: 12),

                            // Chart risk
                            Expanded(
                              child: Card(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text('Nivel de riesgo',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        height: 220,
                                        child: CustomPaint(
                                          painter: _LineChartPainter(
                                            points: risks
                                                .map((e) => e.toDouble())
                                                .toList(),
                                            minY: minRisk,
                                            maxY: maxRisk,
                                            labels: assessments
                                                .map((e) =>
                                                    _shortDate(e.createdAt))
                                                .toList(),
                                          ),
                                          child: Container(),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            children: [
                                              Image.asset(
                                                'assets/imagenes/min_risk.png',
                                                height: 40,
                                                width: 40,
                                                errorBuilder: (c, o, s) =>
                                                    const Icon(
                                                        Icons
                                                            .sentiment_dissatisfied,
                                                        size: 36),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                  'Min: ${risks.reduce((a, b) => a < b ? a : b)}')
                                            ],
                                          ),
                                          Column(
                                            children: [
                                              Image.asset(
                                                'assets/imagenes/max_risk.png',
                                                height: 40,
                                                width: 40,
                                                errorBuilder: (c, o, s) =>
                                                    const Icon(Icons.warning,
                                                        size: 36),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                  'Máx: ${risks.reduce((a, b) => a > b ? a : b)}')
                                            ],
                                          ),
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Lista de registros
                        Card(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Historial de evaluaciones',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                const Divider(),
                                ...assessments.reversed.map((a) {
                                  return ListTile(
                                    leading: const Icon(Icons.event_note),
                                    title: Text(
                                        'Total: ${a.total} — Riesgo: ${a.riskLevel}'),
                                    subtitle: Text('${a.createdAt.toLocal()}'),
                                  );
                                }).toList()
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ]),
      ),
    );
  }
}

/// Painter simple para línea + ejes + labels horizontales
class _LineChartPainter extends CustomPainter {
  final List<double> points;
  final double minY;
  final double maxY;
  final List<String> labels;

  _LineChartPainter({
    required this.points,
    required this.minY,
    required this.maxY,
    required this.labels,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paintAxis = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 1;

    final paintGrid = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 0.5;

    final paintLine = Paint()
      ..color = Colors.blueAccent
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final paintDot = Paint()
      ..color = Colors.blueAccent
      ..style = PaintingStyle.fill;

    final double leftPadding = 36;
    final double bottomPadding = 28;
    final double topPadding = 12;
    final double rightPadding = 12;

    final chartW = size.width - leftPadding - rightPadding;
    final chartH = size.height - topPadding - bottomPadding;

    // Ejes
    canvas.drawLine(Offset(leftPadding, topPadding),
        Offset(leftPadding, topPadding + chartH), paintAxis);
    canvas.drawLine(Offset(leftPadding, topPadding + chartH),
        Offset(leftPadding + chartW, topPadding + chartH), paintAxis);

    if (points.isEmpty) return;

    // Dibujar grid horizontal (4 líneas)
    for (int i = 0; i <= 4; i++) {
      double y = topPadding + chartH - (chartH * i / 4);
      canvas.drawLine(
          Offset(leftPadding, y), Offset(leftPadding + chartW, y), paintGrid);
      // label left
      final yyValue = minY + (maxY - minY) * (i / 4);
      final tp = TextPainter(
        text: TextSpan(
            text: yyValue.toStringAsFixed(0),
            style: TextStyle(color: Colors.grey.shade700, fontSize: 10)),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(4, y - tp.height / 2));
    }

    // Mapeo de puntos
    final int n = points.length;
    double xStep = n == 1 ? chartW / 2 : chartW / (n - 1);
    List<Offset> pts = [];
    for (int i = 0; i < n; i++) {
      final val = points[i];
      double normalized = (val - minY) / (maxY - minY);
      normalized = normalized.isNaN ? 0.0 : normalized.clamp(0.0, 1.0);
      double x = leftPadding + xStep * i;
      double y = topPadding + chartH - (chartH * normalized);
      pts.add(Offset(x, y));
    }

    // Dibujar línea suavizada como polylines (sin curve complejo)
    final path = Path();
    for (int i = 0; i < pts.length; i++) {
      if (i == 0)
        path.moveTo(pts[i].dx, pts[i].dy);
      else
        path.lineTo(pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(path, paintLine);

    // Dibujar puntos
    for (final p in pts) {
      canvas.drawCircle(p, 3.5, paintDot);
    }

    // Labels X (fechas)
    final textStyle = TextStyle(color: Colors.grey.shade800, fontSize: 10);
    for (int i = 0; i < labels.length; i++) {
      final lbl = labels[i];
      final tp = TextPainter(
          text: TextSpan(text: lbl, style: textStyle),
          textDirection: TextDirection.ltr);
      tp.layout();
      double x = leftPadding + xStep * i - tp.width / 2;
      double y = topPadding + chartH + 6;
      tp.paint(canvas, Offset(x, y));
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter old) {
    return old.points != points ||
        old.minY != minY ||
        old.maxY != maxY ||
        old.labels != labels;
  }
}
