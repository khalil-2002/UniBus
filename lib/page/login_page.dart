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
  String? errorMessage; // ✅ message inline sous les champs

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  /// 🔑 Affichage SnackBar global
  void _showSnack(String text, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: color),
    );
  }

  /// 🔑 Connexion avec gestion des erreurs
  Future<void> _login() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    setState(() => errorMessage = null);

    if (email.isEmpty || password.isEmpty) {
      setState(() => errorMessage = "Veuillez remplir tous les champs");
      return;
    }

    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(email)) {
      setState(() => errorMessage = "Adresse e-mail invalide");
      return;
    }

    if (password.length < 6) {
      setState(() => errorMessage = "Le mot de passe doit contenir au moins 6 caractères");
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

        _showSnack("Connexion réussie ✅", Colors.green);

        Navigator.pushReplacementNamed(context, '/home', arguments: role);
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        switch (e.code) {
          case 'user-not-found':
            errorMessage = "Utilisateur introuvable";
            break;
          case 'wrong-password':
            errorMessage = "Mot de passe incorrect";
            break;
          case 'invalid-email':
            errorMessage = "Email invalide";
            break;
          default:
            errorMessage = "Erreur : ${e.message}";
        }
      });
    } catch (e) {
      setState(() => errorMessage = "Erreur inattendue");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      setState(() => errorMessage = "Entrez votre email pour réinitialiser");
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _showSnack("Email de réinitialisation envoyé ✅", Colors.green);
    } catch (e) {
      setState(() => errorMessage = "Impossible d’envoyer l’email de réinitialisation");
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

                  // Champ Mot de passe
                  MyTransparentTextField(
                    controller: passwordController,
                    prefixIcon: Icons.lock,
                    labeltext: "Mot de passe",
                    hinttext: "Entrez votre mot de passe",
                    isPassword: true,
                    textInputAction: TextInputAction.done,
                  ),

                  // ✅ Message d’erreur inline
                  if (errorMessage != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                    ),
                  ],

                  const SizedBox(height: 30),

                  // Mot de passe oublié
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _resetPassword,
                      child: const Text(
                        "Mot de passe oublié ?",
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),

                  // Bouton Se connecter dynamique
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
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: isLoading
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  CircularProgressIndicator(color: Colors.indigo),
                                  SizedBox(width: 12),
                                  Text("Connexion en cours...",
                                      style: TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              )
                            : const Text(
                                "Se connecter",
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
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
