// lib/home_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import 'HistoriquePannesPage.dart';
import 'LoginScreen.dart';
import 'MaintenancePage.dart';
import 'ObserverPage.dart';
import 'ProductionPage.dart';

class HomeScreen extends StatefulWidget {
  final bool isAdmin;
  const HomeScreen({Key? key, required this.isAdmin}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _pageController = PageController(viewportFraction: 0.8);
  Timer? _scrollTimer;
  List<String> _machineIds = [];

  @override
  void initState() {
    super.initState();
    FirebaseFirestore.instance.collection('machines').snapshots().listen((
      snapshot,
    ) {
      if (!mounted) return;
      setState(() => _machineIds = snapshot.docs.map((d) => d.id).toList());
    });

    _scrollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_pageController.hasClients || _machineIds.isEmpty) return;
      final next =
          ((_pageController.page ?? 0).round() + 1) % _machineIds.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _navigateToObserverPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ObserverPage()),
    );
  }

  void _logout() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Maintenance App',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFFE4F2D),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, size: 28, color: Colors.black),
            onPressed: _logout,
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.white),
              child: Center(
                child: ClipOval(
                  child: Image.asset(
                    'assets/Pièces (7).png',
                    width: 200,
                    height: 200,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Accueil'),
              onTap: () {},
            ),
            if (widget.isAdmin)
              ListTile(
                leading: const Icon(Icons.supervisor_account),
                title: const Text('Gérer observateur'),
                onTap: _navigateToObserverPage,
              ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Machines',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            _buildMachineList(),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Déconnexion'),
              onTap: _logout,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // <-- This Expanded lets your carousel grow to fill available space:
          Expanded(
            flex: 3,
            child: PageView.builder(
              controller: _pageController,
              itemCount: _machineIds.length,
              itemBuilder: (context, index) {
                final id = _machineIds[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 16,
                  ),
                  child: HourlyHistogram(machineId: id),
                );
              },
            ),
          ),

          // Whatever you want below the carousel:
          const Expanded(flex: 1, child: SizedBox()),
        ],
      ),
    );
  }

  Widget _buildMachineList() {
    return Column(
      children:
          _machineIds.map((machineId) {
            return ExpansionTile(
              leading: const Icon(Icons.memory),
              title: Text(machineId),
              children: [
                ListTile(
                  leading: const Icon(Icons.analytics),
                  title: const Text('Données de production'),
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProductionPage(machineId: machineId),
                        ),
                      ),
                ),
                ListTile(
                  leading: const Icon(Icons.build_circle),
                  title: const Text('Données de maintenance'),
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MaintenancePage(machineId: machineId),
                        ),
                      ),
                ),
                ListTile(
                  leading: const Icon(Icons.warning_amber_rounded),
                  title: const Text('Historique des pannes'),
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => HistoriquePannesPage(machineId: machineId),
                        ),
                      ),
                ),
              ],
            );
          }).toList(),
    );
  }
}

/// A tiny widget that shows the hourly‐production histogram for one machine.
class HourlyHistogram extends StatelessWidget {
  final String machineId;
  const HourlyHistogram({Key? key, required this.machineId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1) Machine name
            StreamBuilder<DocumentSnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('machines')
                      .doc(machineId)
                      .collection('metrics')
                      .doc('summary')
                      .snapshots(),
              builder: (context, snap) {
                // loading placeholder:
                if (!snap.hasData || !snap.data!.exists)
                  return const SizedBox(
                    height: 24,
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );

                // pull out the bool
                final lastState =
                    snap.data!.get('last_condition_value') as bool;

                return Text(
                  machineId,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    // green if OK, red if not
                    color: lastState ? Colors.green : Colors.red,
                  ),
                );
              },
            ),

            const SizedBox(height: 4),

            // 2) Chart title
            Text(
              '📊 Histogramme horaire',
              style: Theme.of(context).textTheme.bodySmall,
            ),

            const SizedBox(height: 12),

            // 3) This Expanded makes the chart fill all remaining height in the card
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance
                        .collection('machines')
                        .doc(machineId)
                        .collection('metrics')
                        .doc('hourly')
                        .collection('buckets')
                        .snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  var data =
                      snap.data!.docs
                          .map(
                            (d) => HourlyProduction(
                              d.id,
                              (d['count'] ?? 0).toDouble(),
                            ),
                          )
                          .toList()
                        ..sort((a, b) => a.hourLabel.compareTo(b.hourLabel));
                  // 2) Keep only the last 10 entries
                  if (data.length > 10) {
                    data = data.sublist(data.length - 10);
                  }

                  return SfCartesianChart(
                    primaryXAxis: CategoryAxis(),
                    series: <CartesianSeries>[
                      ColumnSeries<HourlyProduction, String>(
                        dataSource: data,
                        xValueMapper: (hp, _) => hp.hourLabel.split('-').last,
                        yValueMapper: (hp, _) => hp.count,
                        dataLabelSettings: const DataLabelSettings(
                          isVisible: true,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HourlyProduction {
  final String hourLabel;
  final double count;
  HourlyProduction(this.hourLabel, this.count);
}
