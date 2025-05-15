// lib/historique_pannes_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class HistoriquePannesPage extends StatelessWidget {
  final String machineId;
  const HistoriquePannesPage({super.key, required this.machineId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Historique des pannes – $machineId'),
        backgroundColor: Colors.redAccent,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('machines')
                .doc(machineId)
                .collection('historique_pannes')
                .orderBy('ts_ms', descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text("Aucune panne enregistrée."));
          }
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final doc = docs[i];
              final type = doc['type'] as String;
              final msg = doc['message'] as String;
              final tsMs = doc['ts_ms'] as int;
              final dt = DateTime.fromMillisecondsSinceEpoch(tsMs);
              final dateText = DateFormat('yyyy-MM-dd').format(dt);
              final timeText = DateFormat('HH:mm:ss').format(dt);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.red,
                  ),
                  title: Text(
                    msg,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('Type : $type\n$dateText  $timeText'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
