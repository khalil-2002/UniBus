import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_page.dart';
import 'reservation_page.dart';
import 'add_trajet_page.dart';
import 'mes_reservations_page.dart'; // ✅ importer la nouvelle page

class HomePage extends StatelessWidget {
  final String role; // rôle passé depuis LoginPage

  const HomePage({super.key, required this.role});

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text("Bienvenue ${user?.email ?? ''}"),
        backgroundColor: Colors.indigo,
        actions: [
          // ✅ Bouton Mes Réservations
          IconButton(
            icon: const Icon(Icons.event_note),
            tooltip: "Mes Réservations",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MesReservationsPage()),
              );
            },
          ),

          // ✅ Bouton Ajouter un trajet visible seulement pour les admins
          if (role == "admin")
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: "Ajouter un trajet",
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddTrajetPage()),
                );
              },
            ),

          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),

      // Corps principal : liste des trajets
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('trajets')
            .orderBy('horaire')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Aucun trajet disponible"));
          }

          final trajets = snapshot.data!.docs;

          return ListView.builder(
            itemCount: trajets.length,
            itemBuilder: (context, index) {
              final trajet = trajets[index].data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.all(10),
                child: ListTile(
                  leading: const Icon(Icons.directions_bus, color: Colors.indigo),
                  title: Text("${trajet['depart']} → ${trajet['destination']}"),
                  subtitle: Text(
                    "Horaire: ${trajet['horaire'].toDate()} \nPlaces: ${trajet['places_disponibles']}",
                  ),
                  trailing: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ReservationPage(
                            trajetId: trajets[index].id, // ✅ on passe seulement l’ID
                          ),
                        ),
                      );
                    },
                    child: const Text("Réserver"),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
