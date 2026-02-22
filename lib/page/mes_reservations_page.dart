import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'qr_ticket_page.dart';


class MesReservationsPage extends StatefulWidget {
  const MesReservationsPage({super.key});

  @override
  State<MesReservationsPage> createState() => _MesReservationsPageState();
}

class _MesReservationsPageState extends State<MesReservationsPage> {
 
// ✅ Récupérer les réservations de l'utilisateur connecté
Stream<QuerySnapshot> _getUserReservations() {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    // Si aucun utilisateur n'est connecté, on retourne un Stream vide
    return const Stream.empty();
  }

  return FirebaseFirestore.instance
      .collection('reservations')
      .where('userId', isEqualTo: user.uid)
      .orderBy('createdAt', descending: true)
      .snapshots();
}

Future<void> _choisirPaiement(
  String reservationId,
  String trajetId,
  int placesReservees,
  Map<String, dynamic> res,
) async {
  // 🔒 Conserver le context parent (IMPORTANT)
  final parentContext = context;

  // 🔎 Charger le trajet
  final trajetDoc = await FirebaseFirestore.instance
      .collection('trajets')
      .doc(trajetId)
      .get();

  if (!trajetDoc.exists || trajetDoc.data() == null) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Trajet introuvable")),
      );
    }
    return;
  }

  final trajetData = trajetDoc.data()!;
  final double prixTrajet =
      (trajetData['prix'] is num) ? (trajetData['prix'] as num).toDouble() : 0.0;

  final int nbPlaces = placesReservees > 0 ? placesReservees : 1;
  final double montant = prixTrajet * nbPlaces;

  if (montant <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Montant invalide")),
    );
    return;
  }

  // ===== ÉTAT DU DIALOG =====
  bool isProcessing = false;
  bool isSuccess = false;
  double progress = 0.0;
  double cardOpacity = 1.0;
  String currentAsset = "";

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          Future<void> _simulatePayment(String type, String assetPath) async {
            if (isProcessing) return;

            setState(() {
              isProcessing = true;
              progress = 0.0;
              isSuccess = false;
              cardOpacity = 1.0;
              currentAsset = assetPath;
            });

            // Animation carte
            await Future.delayed(const Duration(milliseconds: 600));
            setState(() => cardOpacity = 0.0);

            // Progression
            for (int i = 1; i <= 10; i++) {
              await Future.delayed(const Duration(milliseconds: 220));
              setState(() => progress = i / 10);
            }

            setState(() => isSuccess = true);
            await Future.delayed(const Duration(seconds: 1));

            // 🔴 Fermer le dialog
            Navigator.of(dialogContext).pop();

            if (!mounted) return;

            ScaffoldMessenger.of(parentContext).showSnackBar(
              SnackBar(
                content: Text("Paiement $type de $montant FCFA réussi ✅"),
                backgroundColor: Colors.green,
              ),
            );

            // ✅ Validation paiement
            await _validerPaiement(reservationId, trajetId, nbPlaces);

            if (!mounted) return;

            // ✅ Navigation SAFE après le frame
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(parentContext).push(
                MaterialPageRoute(
                  builder: (_) => QRTicketPage(
                    reservationData: {
                      "reservationId": reservationId,
                      "trajetId": trajetId,
                      "userId":
                          FirebaseAuth.instance.currentUser?.uid ?? "inconnu",
                      "places_reservees": nbPlaces,
                      "depart_arret": res['depart_arret'] ?? 'Inconnu',
                      "arrivee_arret": res['arrivee_arret'] ?? 'Inconnu',
                      "horaire": res['horaire'] ?? Timestamp.now(),
                      "montant": montant,
                    },
                  ),
                ),
              );
            });
          }

          return WillPopScope(
            onWillPop: () async => !isProcessing,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text("Paiement sécurisé"),
              content: SingleChildScrollView(
                child: isProcessing
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 500),
                            opacity: cardOpacity,
                            child: Image.asset(
                              currentAsset,
                              height: 60,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.payment, size: 48),
                            ),
                          ),
                          const SizedBox(height: 16),
                          LinearProgressIndicator(value: progress),
                          const SizedBox(height: 16),
                          isSuccess
                              ? const Icon(Icons.check_circle,
                                  color: Colors.green, size: 42)
                              : const Text("Traitement du paiement..."),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Montant à payer : $montant FCFA",
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),

                          GestureDetector(
                            onTap: () =>
                                _simulatePayment("Wave", "assets/wave.jpeg"),
                            child:
                                _paymentTile("assets/wave.jpeg", "Wave", const Color.fromARGB(255, 255, 255, 255)),
                          ),

                          GestureDetector(
                            onTap: () => _simulatePayment(
                                "Orange Money", "assets/OM.jpeg"),
                            child: _paymentTile(
                                "assets/OM.jpeg", "OM",  const Color.fromARGB(255, 255, 255, 255)),
                          ),
                        ],
                      ),
              ),
            ),
          );
        },
      );
    },
  );
}

Widget _paymentTile(String asset, String label, Color color) {
  return Container(
    margin: const EdgeInsets.symmetric(vertical: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      color: color.withOpacity(0.12),
    ),
    child: Row(
      children: [
        Image.asset(asset, height: 40,
            errorBuilder: (_, __, ___) => const Icon(Icons.payment)),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(fontSize: 16)),
      ],
    ),
  );
}

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
  // ✅ Validation du paiement ()
Future<void> _validerPaiement(
  String reservationId,
  String trajetId,
  int placesReservees,
) async {
  try {
    final trajetRef =
        FirebaseFirestore.instance.collection('trajets').doc(trajetId);
    final reservationRef =
        FirebaseFirestore.instance.collection('reservations').doc(reservationId);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final trajetSnap = await transaction.get(trajetRef);
      final reservationSnap = await transaction.get(reservationRef);

      if (!trajetSnap.exists || !reservationSnap.exists) {
        throw Exception("Données introuvables");
      }

      final reservationData = reservationSnap.data() as Map<String, dynamic>? ?? {};
      final trajetData = trajetSnap.data() as Map<String, dynamic>? ?? {};

      final paymentStatus = reservationData['paymentStatus'] ?? 'en attente';
      int placesDispo = (trajetData['places_disponibles'] is int)
          ? trajetData['places_disponibles']
          : 0;

      // 🔒 Anti double paiement
      if (paymentStatus == 'payé') {
        throw Exception("Paiement déjà effectué");
      }

      // ✅ Vérifier les places avant de confirmer
      if (placesDispo < placesReservees) {
        throw Exception("Pas assez de places disponibles");
      }

      // ✅ Retirer les places et confirmer la réservation
      transaction.update(trajetRef, {
        'places_disponibles': placesDispo - placesReservees,
      });

      transaction.update(reservationRef, {
        'paymentStatus': 'payé',
        'status': 'confirmée',
      });
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Paiement validé ✅ Réservation confirmée"),
          backgroundColor: Colors.green,
        ),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur paiement : $e")),
      );
    }
  }
}


  // ✅ Mise à jour sécurisée
 Future<void> _updateStatus(
  String docId,
  String trajetId,
  String newStatus,
  int placesReservees,
  String paymentStatus,
) async {
  try {
    final reservationRef =
        FirebaseFirestore.instance.collection('reservations').doc(docId);
    final trajetRef =
        FirebaseFirestore.instance.collection('trajets').doc(trajetId);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final reservationSnap = await transaction.get(reservationRef);
      final trajetSnap = await transaction.get(trajetRef);

      if (!reservationSnap.exists) throw Exception("Réservation introuvable");
      if (!trajetSnap.exists) throw Exception("Trajet introuvable");

      final reservationData = reservationSnap.data() as Map<String, dynamic>? ?? {};
      final trajetData = trajetSnap.data() as Map<String, dynamic>? ?? {};

      int placesDispo = (trajetData['places_disponibles'] is int)
          ? trajetData['places_disponibles']
          : 0;

      final currentStatus = reservationData['status'] ?? 'en attente';

      // ✅ Paiement requis avant confirmation
      if (newStatus == "confirmée" && paymentStatus != "payé") {
        throw Exception("Paiement requis avant confirmation");
      }

      // ✅ Gestion des places
      if (newStatus == "annulée" && currentStatus == "confirmée") {
        // Annulation → remettre les places
        transaction.update(trajetRef, {
          'places_disponibles': placesDispo + placesReservees,
        });
      } else if (newStatus == "confirmée" && currentStatus != "confirmée") {
        // Confirmation → retirer les places
        if (placesDispo < placesReservees) {
          throw Exception("Pas assez de places disponibles");
        }
        transaction.update(trajetRef, {
          'places_disponibles': placesDispo - placesReservees,
        });
      }

      // ✅ Mise à jour du statut
      transaction.update(reservationRef, {
        'status': newStatus,
      });
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Statut changé en $newStatus ✅")),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur: $e")),
      );
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
                            trailing: Wrap(
                            spacing: 6,
                            runSpacing: 4,
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
                              if (
                                  status == "en attente" &&
                                  paymentStatus == "en attente" &&
                                  res['userId'] == currentUser?.uid
                                )
                                (res['places_disponibles'] != null &&
                                (res['places_reservees'] ?? 1) > (res['places_disponibles'] ?? 0))
                                  ? const Chip(
                                      label: Text("Complet"),
                                      backgroundColor: Colors.grey,
                                      labelStyle: TextStyle(color: Colors.white),
                                    )
                                  : IconButton(
                                      icon: const Icon(Icons.payment, color: Colors.blue),
                                      onPressed: () => _choisirPaiement(doc.id, trajetId, placesReservees,res),
                                    ),
                                    if (status == "confirmée" && paymentStatus == "payé")
                            IconButton(
                              icon: const Icon(Icons.qr_code, color: Colors.black),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => QRTicketPage(
                                      reservationData: {
                                        ...res,
                                        "reservationId": doc.id,
                                      },
                                    ),
                                  ),
                                );
                              },
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
