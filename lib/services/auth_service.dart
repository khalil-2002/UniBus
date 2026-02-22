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
  /// Réinitialisation du mot de passe
Future<void> resetPassword(String email) async {
  try {
    await _auth.sendPasswordResetEmail(email: email);
  } catch (e) {
    throw Exception("Erreur lors de la réinitialisation : ${e.toString()}");
  }
}
/// Envoi d'email de vérification
Future<void> sendEmailVerification(User user) async {
  if (!user.emailVerified) {
    await user.sendEmailVerification();
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
  /// Suppression du compte utilisateur
  Future<void> deleteAccount() async {
  final user = _auth.currentUser;
  if (user != null) {
    await user.delete();
  }
}


  /// Déconnexion
  Future<void> logout() async {
    await _auth.signOut();
  }

  /// Utilisateur actuellement connecté
  User? get currentUser => _auth.currentUser;
}
