import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'reservation_page.dart'; 
import 'edit_trajet_page.dart'; 
import 'reservations_liste_page.dart'; // ✅ nouvelle page pour voir les réservations
import 'package:intl/intl.dart';

class TrajetsPage extends StatefulWidget {
  final String role; 
  const TrajetsPage({super.key, required this.role});

  @override
  State<TrajetsPage> createState() => _TrajetsPageState();
}

class _TrajetsPageState extends State<TrajetsPage> {
  DateTime selectedDate = DateTime.now();

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  void _previousDay() {
    setState(() {
      selectedDate = selectedDate.subtract(const Duration(days: 1));
    });
  }

  void _nextDay() {
    setState(() {
      selectedDate = selectedDate.add(const Duration(days: 1));
    });
  }

  Widget _buildTrajetsList() {
    final startOfDay = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('trajets')
          .where('horaire', isGreaterThanOrEqualTo: startOfDay)
          .where('horaire', isLessThan: endOfDay)
          .orderBy('horaire')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Erreur: ${snapshot.error}"));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("Aucun trajet disponible pour ce jour"));
        }

        final trajets = snapshot.data!.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return data;
        }).toList();

        return ListView.builder(
          itemCount: trajets.length,
          itemBuilder: (context, index) {
            return _buildTrajetCard(trajets[index]);
          },
        );
      },
    );
  }

  Widget _buildTrajetCard(Map<String, dynamic> trajet) {
    final horaire = (trajet['horaire'] as Timestamp).toDate();
    final horaireStr = DateFormat('HH:mm').format(horaire);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ Infos du trajet
            Row(
              children: [
                const Icon(Icons.directions_bus, color: Colors.indigo),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "${trajet['depart']} → ${trajet['destination']}",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text("Horaire: $horaireStr"),
            Text("Places: ${trajet['places_disponibles']}"),
            if (trajet.containsKey('prix')) Text("Prix: ${trajet['prix']} FCFA"),

            const Divider(height: 20),

            // ✅ Boutons en bas
            // ✅ Boutons en bas
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: [
            // 👉 Si la date est passée
             if (horaire.isBefore(DateTime.now()))
              const Chip( 
                 label: Text("Trajet terminé"),
                  backgroundColor: Colors.grey, 
                  labelStyle: TextStyle(color: Colors.white), ) 
            // 👉 Si plus de places disponibles
            else if ((trajet['places_disponibles'] ?? 0) > 0)
              ElevatedButton.icon(
                icon: const Icon(Icons.event_seat),
                label: const Text("Réserver"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ReservationPage(trajetId: trajet['id'])),
                  );
                },
              )
            else
              const Chip(
                label: Text("Complet"),
                backgroundColor: Colors.grey,
                labelStyle: TextStyle(color: Colors.white),
              ),

            if (widget.role == "admin")
              ElevatedButton.icon(
                icon: const Icon(Icons.edit),
                label: const Text("Modifier"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => EditTrajetPage(trajetId: trajet['id'])),
                  );
                },
              ),

            if (widget.role == "admin")
              ElevatedButton.icon(
                icon: const Icon(Icons.delete),
                label: const Text("Supprimer"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text("Supprimer le trajet"),
                      content: const Text("Voulez-vous vraiment supprimer ce trajet ?"),
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
                    await FirebaseFirestore.instance.collection('trajets').doc(trajet['id']).delete();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Trajet supprimé ✅")),
                    );
                  }
                },
              ),

            if (widget.role == "admin")
              ElevatedButton.icon(
                icon: const Icon(Icons.list),
                label: const Text("Réservations"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReservationsListPage(trajetId: trajet['id']),
                    ),
                  );
                },
              ),
          ],
        ),

          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd/MM/yyyy').format(selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: Text("Trajets du $dateStr"),
        backgroundColor: Colors.indigo,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _selectDate(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(onPressed: _previousDay, child: const Text("Jour précédent")),
                const SizedBox(width: 12),
                ElevatedButton(onPressed: _nextDay, child: const Text("Jour suivant")),
              ],
            ),
          ),
          Expanded(child: _buildTrajetsList()),
        ],
      ),
    );
  }
}
