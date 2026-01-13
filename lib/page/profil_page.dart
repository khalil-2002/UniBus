import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_page.dart';

class ProfilPage extends StatefulWidget {
  const ProfilPage({super.key});

  @override
  State<ProfilPage> createState() => _ProfilPageState();
}

class _ProfilPageState extends State<ProfilPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _telController = TextEditingController();

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        _nomController.text = data['nom'] ?? '';
        _telController.text = data['telephone'] ?? '';
      }
    }
  }

  Future<void> _updateUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'nom': _nomController.text,
        'telephone': _telController.text,
        'email': user.email,
      }, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profil mis à jour ✅")),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Mon Profil"),
        backgroundColor: Colors.indigo,
      ),
      body: user == null
          ? const Center(child: Text("Aucun utilisateur connecté"))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.indigo.shade100,
                      child: const Icon(Icons.person, size: 50, color: Colors.indigo),
                    ),
                    const SizedBox(height: 20),

                    TextFormField(
                      controller: _nomController,
                      decoration: const InputDecoration(
                        labelText: "Nom",
                        prefixIcon: Icon(Icons.badge),
                      ),
                    ),
                    const SizedBox(height: 10),

                    TextFormField(
                      controller: _telController,
                      decoration: const InputDecoration(
                        labelText: "Téléphone",
                        prefixIcon: Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 20),

                    ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text("Sauvegarder"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      onPressed: _updateUserData,
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.logout),
                      label: const Text("Déconnexion"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      onPressed: () => _logout(context),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
