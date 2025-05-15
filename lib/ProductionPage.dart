// lib/production_page.dart

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:intl/intl.dart';

class ProductionPage extends StatefulWidget {
  final String machineId;

  const ProductionPage({super.key, required this.machineId});

  @override
  State<ProductionPage> createState() => _ProductionPageState();
}

class _ProductionPageState extends State<ProductionPage> {
  Map<String, dynamic>? summary;
  Map<String, dynamic>? daily;
  int dailyPieces = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    // Live summary listener
    FirebaseFirestore.instance
        .collection('machines')
        .doc(widget.machineId)
        .collection('metrics')
        .doc('summary')
        .snapshots()
        .listen((snap) {
          if (snap.exists && mounted) {
            setState(() => summary = snap.data());
          }
        });

    // Initial daily load + periodic refresh
    _loadDaily();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _loadDaily();
    });
  }

  Future<void> _loadDaily() async {
    final nowLocal = DateTime.now();
    // Decide bucket date: if before 6AM local, use yesterday
    final bucketDate = DateFormat('yyyy-MM-dd').format(
      nowLocal.hour < 6 ? nowLocal.subtract(const Duration(days: 1)) : nowLocal,
    );

    final dailyDoc =
        await FirebaseFirestore.instance
            .collection('machines')
            .doc(widget.machineId)
            .collection('metrics')
            .doc('uptime_daily')
            .collection('buckets')
            .doc(bucketDate)
            .get();

    final piecesDoc =
        await FirebaseFirestore.instance
            .collection('machines')
            .doc(widget.machineId)
            .collection('metrics')
            .doc('pieces_daily')
            .collection('buckets')
            .doc(bucketDate)
            .get();

    if (mounted) {
      setState(() {
        daily = dailyDoc.exists ? dailyDoc.data()! : {};
        dailyPieces =
            piecesDoc.exists ? (piecesDoc.data()?['count'] ?? 0) as int : 0;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _fmt(Duration d) {
    return '${d.inHours}h ${d.inMinutes.remainder(60)}m ${d.inSeconds.remainder(60)}s';
  }

  Widget _card(IconData icon, String title, String value) {
    final width = (MediaQuery.of(context).size.width / 2) - 24;
    return SizedBox(
      width: width,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
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
    // Wait for both summary & daily to load
    if (summary == null || daily == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // === Summary fields ===
    final upTotal = (summary!['uptime_ms'] ?? 0) as int;
    final downTotal = (summary!['downtime_ms'] ?? 0) as int;
    final lastTs = (summary!['last_condition_ts'] ?? 0) as int;
    final lastState = summary!['last_condition_value'] as bool;

    // === LIVE TOTAL uptime/downtime (using UTC “now”) ===
    final nowUtcMs = DateTime.now().millisecondsSinceEpoch;
    final deltaTotal = nowUtcMs - lastTs;

    final upTotalLive = lastState ? upTotal + deltaTotal : upTotal;
    final downTotalLive = lastState ? downTotal : downTotal + deltaTotal;

    // === DAILY cutoff logic (local 6AM) ===
    final nowLocal = DateTime.now();
    final startOfPeriod =
        nowLocal.hour < 6
            ? DateTime(nowLocal.year, nowLocal.month, nowLocal.day - 1, 6)
            : DateTime(nowLocal.year, nowLocal.month, nowLocal.day, 6);
    final startMs = startOfPeriod.millisecondsSinceEpoch;
    final nowLocalMs = nowLocal.millisecondsSinceEpoch;

    final upDay = (daily!['uptime_ms'] ?? 0) as int;
    final downDay = (daily!['downtime_ms'] ?? 0) as int;

    final uptimeDelta = lastState ? nowLocalMs - math.max(lastTs, startMs) : 0;
    final downtimeDelta =
        !lastState ? nowLocalMs - math.max(lastTs, startMs) : 0;

    final upDayLive = upDay + uptimeDelta;
    final downDayLive = downDay + downtimeDelta;

    // === Other metrics ===
    const idealCycle = 10000; // ms per piece
    final piecesTotal = summary!['total_pieces'] ?? 0;
    final lastCycle = summary!['last_cycle_time_ms'] ?? 0;

    final availability =
        (upDayLive + downDayLive) > 0
            ? upDayLive / (upDayLive + downDayLive)
            : 0;
    final performanceTotal =
        upTotalLive > 0 ? (piecesTotal * idealCycle) / upTotalLive : 0;
    final productionRate =
        upTotalLive > 0 ? piecesTotal / (upTotalLive / 3600000) : 0;

    return Scaffold(
      appBar: AppBar(
        title: Text('Production – ${widget.machineId}'),
        backgroundColor: Colors.redAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _card(
                  Icons.production_quantity_limits,
                  'Pièces produites',
                  '$piecesTotal',
                ),
                _card(Icons.timer_outlined, 'Cycle (dernier)', '$lastCycle ms'),
                _card(
                  Icons.access_time,
                  'Fonctionnement (total)',
                  _fmt(Duration(milliseconds: upTotalLive)),
                ),
                _card(
                  Icons.timelapse_outlined,
                  'Temps d’arrêt (total)',
                  _fmt(Duration(milliseconds: downTotalLive)),
                ),
                _card(
                  Icons.access_time_filled,
                  'Fonctionnement (jour)',
                  _fmt(Duration(milliseconds: upDayLive.toInt())),
                ),
                _card(
                  Icons.timelapse,
                  'Temps d’arrêt (jour)',
                  _fmt(Duration(milliseconds: downDayLive.toInt())),
                ),
                _card(Icons.analytics, 'Production (jour)', '$dailyPieces'),
                _card(
                  Icons.av_timer,
                  'Taux de production',
                  '${productionRate.toStringAsFixed(2)} pièces/h',
                ),
                _card(
                  Icons.speed,
                  'Performance',
                  '${(performanceTotal * 100).toStringAsFixed(2)} %',
                ),
              ],
            ),

            const SizedBox(height: 24),
            Text(
              '📊 Histogramme horaire',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 250,
              child: StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance
                        .collection('machines')
                        .doc(widget.machineId)
                        .collection('metrics')
                        .doc('hourly')
                        .collection('buckets')
                        .snapshots(),
                builder: (ctx, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // 1) Map + sort
                  var data =
                      snap.data!.docs
                          .map(
                            (d) => Hourly(d.id, (d['count'] ?? 0).toDouble()),
                          )
                          .toList()
                        ..sort((a, b) => a.hour.compareTo(b.hour));

                  // 2) Keep only the last 10 items
                  if (data.length > 10) {
                    data = data.sublist(data.length - 10);
                  }

                  return SfCartesianChart(
                    primaryXAxis: CategoryAxis(labelRotation: 0),
                    series: <CartesianSeries>[
                      ColumnSeries<Hourly, String>(
                        dataSource: data,
                        xValueMapper: (h, _) => h.hour.split('-').last,
                        yValueMapper: (h, _) => h.count,
                        dataLabelSettings: const DataLabelSettings(
                          isVisible: true,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 24),
            Text(
              'Disponibilité (jour)',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: SfRadialGauge(
                axes: [
                  RadialAxis(
                    minimum: 0,
                    maximum: 100,
                    ranges: [
                      GaugeRange(
                        startValue: 0,
                        endValue: 100,
                        gradient: const SweepGradient(
                          colors: [Colors.red, Colors.yellow, Colors.green],
                          stops: [0, 0.5, 1],
                        ),
                        startWidth: 0.15,
                        endWidth: 0.15,
                        sizeUnit: GaugeSizeUnit.factor,
                      ),
                    ],
                    pointers: [NeedlePointer(value: availability * 100)],
                    annotations: [
                      GaugeAnnotation(
                        widget: Text(
                          '${(availability * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        angle: 90,
                        positionFactor: 0.8,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Hourly {
  final String hour;
  final double count;
  Hourly(this.hour, this.count);
}
