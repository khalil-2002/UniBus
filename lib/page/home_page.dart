import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_page.dart';
import 'trajets_page.dart';
import 'mes_reservations_page.dart';
import 'profil_page.dart';
import 'add_trajet_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class HomePage extends StatefulWidget {
  final String role;
  const HomePage({super.key, required this.role});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Déconnexion"),
        content: const Text("Voulez-vous vraiment vous déconnecter ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Se déconnecter"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Vous êtes déconnecté ✅"),
          backgroundColor: Colors.indigo,
        ),
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    }
  }

  /// ✅ Accueil modernisé avec image de fond + dashboard
  Widget _buildAccueil() {
    final user = FirebaseAuth.instance.currentUser;
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage("assets/bus_background1.jpg"), // ton image
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        color: Colors.black.withOpacity(0.5), // voile sombre pour lisibilité
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Bandeau de bienvenue
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Bienvenue 👋",
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      user?.email ?? "Utilisateur",
                      style: const TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Dashboard : trajets du jour
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('trajets')
                    .where('horaire', isGreaterThanOrEqualTo: startOfDay)
                    .where('horaire', isLessThan: endOfDay)
                    .snapshots(),
                builder: (context, snapshot) {
                  int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 6,
                    child: ListTile(
                      leading: const Icon(Icons.directions_bus, color: Colors.indigo),
                      title: const Text("Trajets disponibles aujourd’hui"),
                      subtitle: Text("$count trajets"),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                        child: const Text("Voir"),
                        onPressed: () {
                           Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => TrajetsPage(role: widget.role)),
                            );

                        },
                      ),
                    ),
                  );
                },
              ),

              // Section Mes prochaines réservations
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 6,
                child: ListTile(
                  leading: const Icon(Icons.event_note, color: Colors.indigo),
                  title: const Text("Mes prochaines réservations"),
                  subtitle: const Text("Vos trajets réservés apparaîtront ici"),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                    child: const Text("Voir"),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MesReservationsPage()),
                      );
                    },
                  ),
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
    final items = [
      const BottomNavigationBarItem(icon: Icon(Icons.home), label: "Accueil"),
      const BottomNavigationBarItem(icon: Icon(Icons.event_note), label: "Réservations"),
      const BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profil"),
      if (widget.role == "admin")
        const BottomNavigationBarItem(icon: Icon(Icons.add), label: "Ajouter"),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("UniBus"),
        backgroundColor: Colors.indigo,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: _selectedIndex == 0 ? _buildAccueil() : const Center(child: Text("Section en cours...")),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.indigo,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: items,
        onTap: (index) {
          setState(() => _selectedIndex = index);
          if (index == 1) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const MesReservationsPage()));
          } else if (index == 2) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilPage()));
          } else if (widget.role == "admin" && index == 3) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const AddTrajetPage()));
          }
        },
      ),
    );
  }
}
