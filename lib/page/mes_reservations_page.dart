import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class MesReservationsPage extends StatefulWidget {
  const MesReservationsPage({super.key});

  @override
  State<MesReservationsPage> createState() => _MesReservationsPageState();
}

class _MesReservationsPageState extends State<MesReservationsPage> {
  String _selectedStatus = "toutes";

  Stream<QuerySnapshot> _getUserReservations() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();

    var query = FirebaseFirestore.instance
        .collection('reservations')
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true);

    return query.snapshots();
  }

  Color _statusColor(String status) {
    switch (status) {
      case "confirmée":
        return Colors.green;
      case "annulée":
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mes Réservations"),
        backgroundColor: Colors.indigo,
      ),
      body: Column(
        children: [
          // Filtres
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                const Text("Filtrer par statut: "),
                DropdownButton<String>(
                  value: _selectedStatus,
                  items: const [
                    DropdownMenuItem(value: "toutes", child: Text("Toutes")),
                    DropdownMenuItem(value: "confirmée", child: Text("Confirmées")),
                    DropdownMenuItem(value: "annulée", child: Text("Annulées")),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedStatus = value!;
                    });
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getUserReservations(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text("Erreur: ${snapshot.error}"));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("Vous n'avez aucune réservation"));
                }

                final reservations = snapshot.data!.docs.where((doc) {
                  final status = (doc['status'] ?? 'confirmée') as String;
                  if (_selectedStatus == "toutes") return true;
                  return status == _selectedStatus;
                }).toList();

                return ListView.builder(
                  itemCount: reservations.length,
                  itemBuilder: (context, index) {
                    final res = reservations[index].data() as Map<String, dynamic>;
                    final status = res['status'] ?? 'confirmée';
                    final createdAt = (res['createdAt'] as Timestamp?)?.toDate();
                    final dateStr = createdAt != null
                        ? DateFormat('dd/MM/yyyy HH:mm').format(createdAt)
                        : '';

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _statusColor(status),
                          child: const Icon(Icons.event_seat, color: Colors.white),
                        ),
                        title: Text("${res['depart_arret']} → ${res['arrivee_arret']}"),
                        subtitle: Text(
                          "Réservant: ${res['reservant_nom'] ?? ''}\n"
                          "Passager: ${res['nom_passager'] ?? ''}\n"
                          "Places: ${res['places_reservees'] ?? 0}\n"
                          "Date: $dateStr\n"
                          "Statut: $status",
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
