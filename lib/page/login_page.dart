import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/my_transparent_textfield.dart';
import '../services/auth_service.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;
  bool showPassword = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  /// 🔑 Affichage des messages SnackBar
  void _showMessage(String text, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: color),
    );
  }

  /// 🔑 Connexion avec récupération du rôle
  Future<void> _login() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showMessage("Veuillez remplir tous les champs", Colors.red);
      return;
    }

    // Validation email simple
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(email)) {
      _showMessage("Adresse e-mail invalide", Colors.red);
      return;
    }

    if (password.length < 6) {
      _showMessage("Le mot de passe doit contenir au moins 6 caractères", Colors.red);
      return;
    }

    setState(() => isLoading = true);

    try {
      await AuthService().login(email, password);

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        final role = snap.data()?['role'] ?? 'user';

        _showMessage("Connexion réussie ✅", Colors.green);

        // ✅ Navigation avec routes définies dans main.dart
        Navigator.pushReplacementNamed(context, '/home', arguments: role);
      }
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = "Utilisateur introuvable";
          break;
        case 'wrong-password':
          message = "Mot de passe incorrect";
          break;
        case 'invalid-email':
          message = "Email invalide";
          break;
        default:
          message = "Erreur : ${e.message}";
      }
      _showMessage(message, Colors.red);
    } catch (e) {
      _showMessage("Erreur inattendue : ${e.toString()}", Colors.red);
    } finally {
      setState(() => isLoading = false);
    }
  }

  /// 🔑 Réinitialisation du mot de passe
  Future<void> _resetPassword() async {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      _showMessage("Entrez votre email pour réinitialiser", Colors.red);
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _showMessage("Email de réinitialisation envoyé ✅", Colors.green);
    } catch (e) {
      _showMessage("Erreur : ${e.toString()}", Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 🖼️ Image de fond
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/bus_background1.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),

          // Couche sombre
          Container(color: Colors.black.withOpacity(0.6)),

          // Contenu principal
          Align(
            alignment: Alignment.center,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.directions_bus,
                      size: 100, color: Colors.blueAccent),
                  const SizedBox(height: 20),
                  const Text(
                    "E_Transport",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 50),

                  // Champ Email
                  MyTransparentTextField(
                    controller: emailController,
                    prefixIcon: Icons.email,
                    labeltext: "Email",
                    hinttext: "Entrez votre adresse e-mail",
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 20),

                  // Champ Mot de passe avec bouton 👁️
                  TextField(
                    controller: passwordController,
                    obscureText: !showPassword,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.lock, color: Colors.white),
                      suffixIcon: IconButton(
                        icon: Icon(
                          showPassword ? Icons.visibility_off : Icons.visibility,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          setState(() {
                            showPassword = !showPassword;
                          });
                        },
                      ),
                      labelText: "Mot de passe",
                      labelStyle: const TextStyle(color: Colors.white),
                      hintText: "Entrez votre mot de passe",
                      hintStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.2),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Mot de passe oublié
                  Container(
                    width: double.infinity,
                    alignment: Alignment.bottomRight,
                    child: TextButton(
                      onPressed: _resetPassword,
                      child: const Text(
                        "Mot de passe oublié ?",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ),
                  ),

                  // Bouton Se connecter
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.indigo,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: isLoading ? null : _login,
                      child: isLoading
                          ? const CircularProgressIndicator(color: Colors.indigo)
                          : const Text(
                              "Se connecter",
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Lien Créer un compte
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const RegisterPage()),
                      );
                    },
                    child: const Text(
                      "Créer un compte",
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
