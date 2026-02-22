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
  final _roleController = TextEditingController(); // ✅ champ statut

  @override
  void dispose() {
    _nomController.dispose();
    _telController.dispose();
    _roleController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        _nomController.text = data['nom'] ?? '';
        _telController.text = data['telephone'] ?? '';
        final role = data['role'] ?? 'user';
        _roleController.text = role == 'admin' ? 'Administrateur' : 'Utilisateur'; // ✅ conversion claire
        setState(() {});
      }
    }
  }

  Future<void> _updateUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'nom': _nomController.text,
          'telephone': _telController.text,
          'email': user.email,
          // ⚠️ On ne modifie pas le rôle ici (sécurité)
        }, SetOptions(merge: true));

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profil mis à jour ✅")),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors de la mise à jour: $e")),
        );
      }
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF4A148C), Color(0xFF7B1FA2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: user == null
            ? const Center(child: Text("Aucun utilisateur connecté"))
            : Center(
                child: SingleChildScrollView(
                  child: Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
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

                            // ✅ Email non éditable
                            TextFormField(
                              initialValue: user.email,
                              decoration: InputDecoration(
                                labelText: "Email",
                                prefixIcon: const Icon(Icons.email, color: Colors.indigo),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              enabled: false,
                            ),
                            const SizedBox(height: 12),

                            TextFormField(
                              controller: _nomController,
                              decoration: InputDecoration(
                                labelText: "Nom",
                                prefixIcon: const Icon(Icons.badge, color: Colors.indigo),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return "Le nom est obligatoire";
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),

                            TextFormField(
                              controller: _telController,
                              decoration: InputDecoration(
                                labelText: "Téléphone",
                                prefixIcon: const Icon(Icons.phone, color: Colors.indigo),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              keyboardType: TextInputType.phone,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return "Le téléphone est obligatoire";
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),

                            // ✅ Champ Statut (Utilisateur ou Administrateur)
                            TextFormField(
                              controller: _roleController,
                              decoration: InputDecoration(
                                labelText: "Statut",
                                prefixIcon: const Icon(Icons.verified_user, color: Colors.indigo),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                filled: true,
                                fillColor: _roleController.text == "Administrateur"
                                    ? Colors.blue.shade50
                                    : Colors.green.shade50,
                              ),
                              enabled: false, // ⚠️ non modifiable
                            ),
                            const SizedBox(height: 20),

                            ElevatedButton.icon(
                              icon: const Icon(Icons.save),
                              label: const Text("Sauvegarder"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                minimumSize: const Size(double.infinity, 50),
                              ),
                              onPressed: () {
                                if (_formKey.currentState!.validate()) {
                                  _updateUserData();
                                }
                              },
                            ),
                            const SizedBox(height: 12),

                            ElevatedButton.icon(
                              icon: const Icon(Icons.logout),
                              label: const Text("Déconnexion"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                minimumSize: const Size(double.infinity, 50),
                              ),
                              onPressed: () async {
                                final confirm = await showDialog(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text("Déconnexion"),
                                    content: const Text("Voulez-vous vraiment vous déconnecter ?"),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Annuler")),
                                      ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Oui")),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await FirebaseAuth.instance.signOut();
                                  Navigator.pushAndRemoveUntil(
                                    context,
                                    MaterialPageRoute(builder: (_) => const LoginPage()),
                                    (_) => false,
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
