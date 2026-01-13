import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ReservationsListPage extends StatefulWidget {
  final String trajetId;
  const ReservationsListPage({super.key, required this.trajetId});

  @override
  State<ReservationsListPage> createState() => _ReservationsListPageState();
}

class _ReservationsListPageState extends State<ReservationsListPage> {
  String _selectedStatus = "toutes";

  Color _statusColor(String status) {
    switch (status) {
      case "confirmée": return Colors.green;
      case "annulée": return Colors.red;
      case "en attente": return Colors.orange;
      default: return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case "confirmée": return Icons.check_circle;
      case "annulée": return Icons.cancel;
      case "en attente": return Icons.pause_circle;
      default: return Icons.help;
    }
  }

  Future<void> _deleteReservation(DocumentSnapshot doc, Map<String, dynamic> res) async {
    final trajetId = res['trajetId'];
    final placesReservees = res['places_reservees'] ?? 1;
    final status = res['status'] ?? 'en attente';

    final trajetRef = FirebaseFirestore.instance.collection('trajets').doc(trajetId);
    final reservationRef = FirebaseFirestore.instance.collection('reservations').doc(doc.id);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final trajetSnap = await transaction.get(trajetRef);
      if (trajetSnap.exists && status == "confirmée") {
        int placesDispo = trajetSnap['places_disponibles'] ?? 0;
        transaction.update(trajetRef, {
          'places_disponibles': placesDispo + placesReservees
        });
      }
      transaction.delete(reservationRef);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Réservation supprimée ✅")),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Réservations du trajet"),
        backgroundColor: Colors.indigo,
      ),
      body: Column(
        children: [
          // ✅ Filtres
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
                    DropdownMenuItem(value: "en attente", child: Text("En attente")),
                  ],
                  onChanged: (value) => setState(() => _selectedStatus = value!),
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('reservations')
                  .where('trajetId', isEqualTo: widget.trajetId)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text("Erreur: ${snapshot.error}"));
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("Aucune réservation pour ce trajet"));
                }

                final now = DateTime.now();

                // ✅ Réservations futures
                final reservationsFutures = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final status = data['status'] ?? 'en attente';
                  final horaire = (data['horaire'] as Timestamp?)?.toDate();

                  if (_selectedStatus != "toutes" && status != _selectedStatus) return false;
                  if (horaire != null && horaire.isBefore(now)) return false;
                  return true;
                }).toList();
                final reservationsPassees = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final horaire = (data['horaire'] as Timestamp?)?.toDate();
                  return horaire != null && horaire.isBefore(now);
                }).toList();


                return ListView(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text("Réservations à venir",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    if (reservationsFutures.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text("Aucune réservation future"),
                      )
                    else
                      ...reservationsFutures.map((doc) {
                        final res = doc.data() as Map<String, dynamic>;
                        final status = res['status'] ?? 'en attente';
                        final paymentStatus = res['paymentStatus'] ?? 'en attente';
                        final horaire = (res['horaire'] as Timestamp?)?.toDate();
                        final dateStr = horaire != null
                            ? DateFormat('dd/MM/yyyy HH:mm').format(horaire)
                            : '';
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _statusColor(status),
                              child: Icon(_statusIcon(status), color: Colors.white),
                            ),
                            title: Text("${res['depart_arret']} → ${res['arrivee_arret']}"),
                            subtitle: Text(
                              "Réservant: ${res['reservant_nom'] ?? ''}\n"
                              "Passager: ${res['nom_passager'] ?? ''}\n"
                              "Places: ${res['places_reservees']}\n"
                              "Paiement: $paymentStatus\n"
                              "Statut: $status\n"
                              "Horaire: $dateStr",
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text("Supprimer la réservation"),
                                    content: const Text("Voulez-vous vraiment supprimer cette réservation ?"),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, false),
                                        child: const Text("Annuler"),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: const Text("Supprimer"),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await _deleteReservation(doc, res);
                                }
                              },
                            ),
                          ),
                        );
                      }),
                    // ---------- Historique ----------
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        "Historique des réservations",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (reservationsPassees.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text("Aucune réservation passée"),
                      )
                    else
                      ...reservationsPassees.map((doc) {
                        final res = doc.data() as Map<String, dynamic>;
                        final status = res['status'] ?? 'en attente';
                        final paymentStatus = res['paymentStatus'] ?? 'en attente';
                        final horaire = (res['horaire'] as Timestamp?)?.toDate();
                        final dateStr = horaire != null
                            ? DateFormat('dd/MM/yyyy HH:mm').format(horaire)
                            : '';

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _statusColor(status),
                              child: Icon(_statusIcon(status), color: Colors.white),
                            ),
                            title: Text("${res['depart_arret']} → ${res['arrivee_arret']}"),
                            subtitle: Text(
                              "Réservant: ${res['reservant_nom'] ?? ''}\n"
                              "Passager: ${res['nom_passager'] ?? ''}\n"
                              "Places: ${res['places_reservees']}\n"
                              "Paiement: $paymentStatus\n"
                              "Statut: $status\n"
                              "Horaire: $dateStr",
                            ),
                            // Action admin (Supprimer) — tu peux entourer d'un check de rôle si tu le passes à cette page
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text("Supprimer la réservation"),
                                    content: const Text("Voulez-vous vraiment supprimer cette réservation ?"),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, false),
                                        child: const Text("Annuler"),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: const Text("Supprimer"),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await _deleteReservation(doc, res);
                                }
                              },
                            ),
                          ),
                        );
                      }),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
