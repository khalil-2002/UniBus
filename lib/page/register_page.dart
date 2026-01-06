import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();
  final phoneController = TextEditingController();

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  Future<void> register() async {
    try {
      // 1️⃣ Créer le compte utilisateur avec Firebase Auth
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final user = credential.user;

      if (user != null) {
        // 2️⃣ Sauvegarder les infos supplémentaires dans Firestore
       await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'nom': nameController.text.trim(),
          'telephone': phoneController.text.trim(),
          'email': emailController.text.trim(),
          'role': 'user', // ✅ rôle par défaut
          'createdAt': FieldValue.serverTimestamp(),
        });


        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Compte créé avec succès ✅")),
        );

        Navigator.pop(context); // Retour à la page de login
      }
    } on FirebaseAuthException catch (e) {
      String message = "Erreur : ${e.message}";
      if (e.code == 'weak-password') {
        message = "Mot de passe trop faible";
      } else if (e.code == 'email-already-in-use') {
        message = "Cet email est déjà utilisé";
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur : ${e.toString()}")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Créer un compte")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: "Nom")),
            TextField(controller: phoneController, decoration: const InputDecoration(labelText: "Téléphone"), keyboardType: TextInputType.phone),
            TextField(controller: emailController, decoration: const InputDecoration(labelText: "Email"), keyboardType: TextInputType.emailAddress),
            TextField(controller: passwordController, decoration: const InputDecoration(labelText: "Mot de passe"), obscureText: true),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: register,
              child: const Text("S'inscrire"),
            ),
          ],
        ),
      ),
    );
  }
}
