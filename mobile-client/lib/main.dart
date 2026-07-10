import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;

void main() {
  runApp(const ChronosDriftApp());
}

class ChronosDriftApp extends StatelessWidget {
  const ChronosDriftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chronos Drift Visualizer',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.cyan,
        scaffoldBackgroundColor: const Color(0xFF0A0A0E),
        cardColor: const Color(0xFF16161D),
        useMaterial3: true,
      ),
      home: const DashboardPage(),
    );
  }
}

class NodeTelemetry {
  final String id;
  final List<double> driftHistory;
  double currentDrift;
  bool isOnline;

  NodeTelemetry(this.id)
      : driftHistory = [],
        currentDrift = 0.0,
        isOnline = true;

  void update() {
    final drift = (math.Random().nextDouble() * 2.5) - 1.25;
    currentDrift = drift;
    driftHistory.add(drift);
    if (driftHistory.length > 50) driftHistory.removeAt(0);
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late List<NodeTelemetry> nodes;
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    nodes = [
      NodeTelemetry('US-EAST-01'),
      NodeTelemetry('EU-WEST-02'),
      NodeTelemetry('AP-SOUTH-01'),
      NodeTelemetry('SA-EAST-01'),
    ];
    _updateTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      setState(() {
        for (var node in nodes) {
          node.update();
        }
      });
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CHRONOS DRIFT VISUALIZER'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildGlobalStatus(),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: nodes.length,
                itemBuilder: (context, index) => _buildNodeCard(nodes[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlobalStatus() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.cyan.withOpacity(0.1),
        border: Border.all(color: Colors.cyan.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('NETWORK SYNC STATUS', style: TextStyle(fontSize: 12, color: Colors.cyan)),
              Text('ACTIVE FORENSIC MONITORING', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          Icon(Icons.radar, color: Colors.cyan[400], size: 40),
        ],
      ),
    );
  }

  Widget _buildNodeCard(NodeTelemetry node) {
    final Color driftColor = node.currentDrift.abs() > 0.8 ? Colors.redAccent : Colors.greenAccent;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(node.id, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(
                  '${node.currentDrift.toStringAsFixed(4)} ms',
                  style: TextStyle(
                    color: driftColor,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              width: double.infinity,
              child: CustomPaint(
                painter: SparklinePainter(node.driftHistory, driftColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;

  SparklinePainter(this.data, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final path = Path();
    final double stepX = size.width / (data.length - 1);
    final double midY = size.height / 2;

    for (int i = 0; i < data.length; i++) {
        // Scale drift to fit Y axis (max ±2ms)
      double y = midY - (data[i] * (size.height / 4));
      if (i == 0) {
        path.moveTo(0, y);
      } else {
        path.lineTo(i * stepX, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant SparklinePainter oldDelegate) => true;
}