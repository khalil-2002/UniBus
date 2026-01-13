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

  // ✅ Couleur selon statut
  Color _statusColor(String status) {
    switch (status) {
      case "confirmée": return Colors.green;
      case "annulée": return Colors.red;
      case "en attente": return Colors.orange;
      default: return Colors.grey;
    }
  }

  // ✅ Icône selon statut
  IconData _statusIcon(String status) {
    switch (status) {
      case "confirmée": return Icons.check_circle;
      case "annulée": return Icons.cancel;
      case "en attente": return Icons.pause_circle;
      default: return Icons.help;
    }
  }
  // ✅ Validation du paiement
  Future<void> _validerPaiement(String reservationId, String trajetId, int placesReservees) async {
    try {
      final trajetRef = FirebaseFirestore.instance.collection('trajets').doc(trajetId);
      final reservationRef = FirebaseFirestore.instance.collection('reservations').doc(reservationId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final trajetSnap = await transaction.get(trajetRef);
        if (!trajetSnap.exists) throw Exception("Trajet introuvable");

        int placesDispo = trajetSnap['places_disponibles'] ?? 0;

        if (placesDispo <= 0) throw Exception("Aucune place disponible pour ce trajet");
        if (placesDispo < placesReservees) throw Exception("Pas assez de places disponibles (restantes: $placesDispo)");

        transaction.update(trajetRef, {'places_disponibles': placesDispo - placesReservees});
        transaction.update(reservationRef, {'paymentStatus': 'payé', 'status': 'confirmée'});
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Paiement validé ✅ Réservation confirmée")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e")));
      }
    }
  }

  // ✅ Récupérer les réservations de l'utilisateur connecté
  Stream<QuerySnapshot> _getUserReservations() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('reservations')
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // ✅ Mise à jour sécurisée
  Future<void> _updateStatus(String docId, String trajetId, String newStatus,
      int placesReservees, String paymentStatus) async {
    try {
      final trajetRef = FirebaseFirestore.instance.collection('trajets').doc(trajetId);
      final reservationRef = FirebaseFirestore.instance.collection('reservations').doc(docId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final trajetSnap = await transaction.get(trajetRef);
        if (!trajetSnap.exists) throw Exception("Trajet introuvable");

        final reservationSnap = await transaction.get(reservationRef);
        if (!reservationSnap.exists) throw Exception("Réservation introuvable");

        int placesDispo = trajetSnap['places_disponibles'] ?? 0;
        final expiresAt = (reservationSnap['expiresAt'] as Timestamp?)?.toDate();
        final currentStatus = reservationSnap['status'] ?? 'en attente';

        if (expiresAt != null && DateTime.now().isAfter(expiresAt) && currentStatus == "en attente") {
          throw Exception("Réservation expirée, impossible de confirmer");
        }
        if (newStatus == "confirmée" && paymentStatus != "payé") {
          throw Exception("Paiement requis avant confirmation");
        }

        if (newStatus == "annulée" || newStatus == "en attente") {
          placesDispo += placesReservees;
        } else if (newStatus == "confirmée") {
          if (placesDispo <= 0) throw Exception("Impossible de confirmer : aucune place disponible");
          if (placesDispo >= placesReservees) {
            placesDispo -= placesReservees;
          } else {
            throw Exception("Pas assez de places disponibles (restantes: $placesDispo)");
          }
        }

        transaction.update(trajetRef, {'places_disponibles': placesDispo});
        transaction.update(reservationRef, {'status': newStatus});
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Statut changé en $newStatus ✅")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e")));
      }
    }
  }

  // ✅ Confirmation avant action
  void _confirmAction(String docId, String trajetId, String newStatus,
      int placesReservees, String paymentStatus) {
    String message = "";
    if (newStatus == "annulée") message = "Voulez-vous vraiment annuler cette réservation ?";
    else if (newStatus == "en attente") message = "Voulez-vous mettre cette réservation en attente ?";
    else if (newStatus == "confirmée") message = "Voulez-vous re-confirmer cette réservation ?";

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmation"),
        content: Text(message),
        actions: [
          TextButton(child: const Text("Non"), onPressed: () => Navigator.pop(context)),
          ElevatedButton(
            child: const Text("Oui"),
            onPressed: () async {
              Navigator.pop(context);
              await _updateStatus(docId, trajetId, newStatus, placesReservees, paymentStatus);
            },
          ),
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Mes Réservations"),
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

          // ✅ Liste des réservations (futur + historique)
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getUserReservations(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text("Erreur: ${snapshot.error}"));
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("Vous n'avez aucune réservation"));
                }

                final now = DateTime.now();

                // Futur
                final reservationsFutures = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final status = data['status'] ?? 'en attente';
                  final horaire = (data['horaire'] as Timestamp?)?.toDate();
                  if (_selectedStatus != "toutes" && status != _selectedStatus) return false;
                  if (horaire != null && horaire.isBefore(now)) return false;
                  return true;
                }).toList();

                // Historique
                final reservationsPassees = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final horaire = (data['horaire'] as Timestamp?)?.toDate();
                  return horaire != null && horaire.isBefore(now);
                }).toList();

                return ListView(
                  children: [
                    // ---------- Réservations à venir ----------
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
                        final createdAt = (res['createdAt'] as Timestamp?)?.toDate();
                        final horaire = (res['horaire'] as Timestamp?)?.toDate();
                        final dateStr = createdAt != null
                            ? DateFormat('dd/MM/yyyy HH:mm').format(createdAt)
                            : '';
                        final trajetId = res['trajetId'] ?? '';
                        final placesReservees = res['places_reservees'] ?? 1;

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _statusColor(status),
                              child: Icon(_statusIcon(status), color: Colors.white),
                            ),
                            title: Text("${res['depart_arret'] ?? 'Inconnu'} → ${res['arrivee_arret'] ?? 'Inconnu'}"),
                            subtitle: Text(
                              "Réservant: ${res['reservant_nom'] ?? ''}\n"
                              "Passager: ${res['nom_passager'] ?? ''}\n"
                              "Places: $placesReservees\n"
                              "Paiement: $paymentStatus\n"
                              "Date: $dateStr\n"
                              "Statut: $status\n"
                              "Horaire: ${horaire != null ? DateFormat('dd/MM/yyyy HH:mm').format(horaire) : 'Non défini'}",
                            ),
                            trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 🔴 Bouton Annuler (si pas déjà annulée)
                              if (status != "annulée")
                                IconButton(
                                  icon: const Icon(Icons.cancel, color: Colors.red),
                                  onPressed: () => _confirmAction(
                                    doc.id, trajetId, "annulée", placesReservees, paymentStatus),
                                ),

                              // 🟠 Bouton Mettre en attente (si confirmée)
                              if (status == "confirmée")
                                IconButton(
                                  icon: const Icon(Icons.pause_circle, color: Colors.orange),
                                  onPressed: () => _confirmAction(
                                    doc.id, trajetId, "en attente", placesReservees, paymentStatus),
                                ),

                              // 🟢 Bouton Re‑confirmer (si annulée ou en attente)
                              if (status == "annulée" || status == "en attente")
                                IconButton(
                                  icon: const Icon(Icons.check_circle, color: Colors.green),
                                  onPressed: () => _confirmAction(
                                    doc.id, trajetId, "confirmée", placesReservees, paymentStatus),
                                ),

                              // 💳 Bouton Payer ou indicateur Complet
                              if (paymentStatus == "en attente" && res['userId'] == currentUser?.uid)
                                (res['places_disponibles'] != null &&
                                (res['places_reservees'] ?? 1) > (res['places_disponibles'] ?? 0))
                                  ? const Chip(
                                      label: Text("Complet"),
                                      backgroundColor: Colors.grey,
                                      labelStyle: TextStyle(color: Colors.white),
                                    )
                                  : IconButton(
                                      icon: const Icon(Icons.payment, color: Colors.blue),
                                      onPressed: () => _validerPaiement(
                                        doc.id, trajetId, placesReservees),
                                    ),
                            ],
                          ),

                          ),
                        );
                      }),

                    // ---------- Historique des réservations ----------
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text("Historique des réservations",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                        final createdAt = (res['createdAt'] as Timestamp?)?.toDate();
                        final horaire = (res['horaire'] as Timestamp?)?.toDate();
                        final dateStr = createdAt != null
                            ? DateFormat('dd/MM/yyyy HH:mm').format(createdAt)
                            : '';
                        final trajetId = res['trajetId'] ?? '';
                        final placesReservees = res['places_reservees'] ?? 1;

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _statusColor(status),
                              child: Icon(_statusIcon(status), color: Colors.white),
                            ),
                            title: Text("${res['depart_arret'] ?? 'Inconnu'} → ${res['arrivee_arret'] ?? 'Inconnu'}"),
                            subtitle: Text(
                              "Réservant: ${res['reservant_nom'] ?? ''}\n"
                              "Passager: ${res['nom_passager'] ?? ''}\n"
                              "Places: $placesReservees\n"
                              "Paiement: $paymentStatus\n"
                              "Date: $dateStr\n"
                              "Statut: $status\n"
                              "Horaire: ${horaire != null ? DateFormat('dd/MM/yyyy HH:mm').format(horaire) : 'Non défini'}",
                            ),
                            // Historique: pas d'actions (optionnel). Tu peux garder Annuler si utile.
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
