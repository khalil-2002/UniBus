import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Connexion avec email et mot de passe
  Future<User?> login(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        throw Exception("Utilisateur non trouvé");
      } else if (e.code == 'wrong-password') {
        throw Exception("Mot de passe incorrect");
      } else {
        throw Exception("Erreur : ${e.message}");
      }
    }
  }

  /// Inscription (création de compte)
  Future<User?> register(String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        throw Exception("Mot de passe trop faible");
      } else if (e.code == 'email-already-in-use') {
        throw Exception("Cet email est déjà utilisé");
      } else {
        throw Exception("Erreur : ${e.message}");
      }
    }
  }

  /// Déconnexion
  Future<void> logout() async {
    await _auth.signOut();
  }

  /// Utilisateur actuellement connecté
  User? get currentUser => _auth.currentUser;
}
