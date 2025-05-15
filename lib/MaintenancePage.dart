import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class MaintenancePage extends StatefulWidget {
  final String machineId;
  const MaintenancePage({Key? key, required this.machineId}) : super(key: key);

  @override
  State<MaintenancePage> createState() => _MaintenancePageState();
}

class _MaintenancePageState extends State<MaintenancePage> {
  Map<String, dynamic>? _summary;
  Map<String, dynamic>? _daily;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    FirebaseFirestore.instance
        .collection('machines')
        .doc(widget.machineId)
        .collection('metrics')
        .doc('summary')
        .snapshots()
        .listen((snap) {
          if (snap.exists && mounted) setState(() => _summary = snap.data());
        });

    _loadDaily();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _loadDaily();
    });
  }

  Future<void> _loadDaily() async {
    final nowUtc = DateTime.now().toUtc();
    final bucket = DateFormat('yyyy-MM-dd').format(
      nowUtc.hour < 6 ? nowUtc.subtract(const Duration(days: 1)) : nowUtc,
    );
    final d =
        await FirebaseFirestore.instance
            .collection('machines')
            .doc(widget.machineId)
            .collection('metrics')
            .doc('uptime_daily')
            .collection('buckets')
            .doc(bucket)
            .get();
    if (mounted) setState(() => _daily = d.data() ?? {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_summary == null || _daily == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final upTotal0 = (_summary!['uptime_ms'] ?? 0) as int;
    final downTotal0 = (_summary!['downtime_ms'] ?? 0) as int;
    final lastTs = (_summary!['last_condition_ts'] ?? 0) as int;
    final lastState = _summary!['last_condition_value'] as bool;

    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    final delta = nowMs - lastTs;

    final upTotal = lastState ? upTotal0 + delta : upTotal0;
    final downTotal = lastState ? downTotal0 : downTotal0 + delta;

    final maintenanceCount = _summary!['maintenance_count'] ?? 0;
    final repairMs = _summary!['total_repair_ms'] ?? 0;

    final upDay0 = (_daily!['uptime_ms'] ?? 0) as int;
    final downDay0 = (_daily!['downtime_ms'] ?? 0) as int;
    final upDay = lastState ? upDay0 + delta : upDay0;
    final downDay = lastState ? downDay0 : downDay0 + delta;

    final mtbf =
        maintenanceCount > 0
            ? Duration(milliseconds: (upTotal / maintenanceCount).round())
            : Duration.zero;
    final mttr =
        maintenanceCount > 0
            ? Duration(milliseconds: (repairMs / maintenanceCount).round())
            : Duration.zero;

    return Scaffold(
      appBar: AppBar(
        title: Text('Maintenance — ${widget.machineId}'),
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
                _card(Icons.build, 'Maintenances', '$maintenanceCount'),
                _card(
                  Icons.home_repair_service,
                  'Réparation',
                  _fmt(Duration(milliseconds: repairMs)),
                ),
                _card(Icons.timelapse, 'MTBF', _fmt(mtbf)),
                _card(Icons.restore, 'MTTR', _fmt(mttr)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(IconData icon, String title, String value) {
    return SizedBox(
      width: MediaQuery.of(context).size.width / 2 - 24,
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

  String _fmt(Duration d) {
    return '${d.inHours}h ${d.inMinutes.remainder(60)}m ${d.inSeconds.remainder(60)}s';
  }
}
