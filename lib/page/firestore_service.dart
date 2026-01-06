import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final db = FirebaseFirestore.instance;

  /// Ajouter un trajet
  Future<void> ajouterTrajet({
    required String depart,
    required String destination,
    required DateTime horaire,
    required int places,
    required List<String> arretsDepart,
    required List<String> arretsArrivee,
  }) async {
    await db.collection('trajets').add({
      'depart': depart,
      'destination': destination,
      'horaire': Timestamp.fromDate(horaire),
      'places_disponibles': places,
      'arrets_depart': arretsDepart,
      'arrets_arrivee': arretsArrivee,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Réserver une place
  Future<void> reserverPlace({
    required String trajetId,
    required String reservantNom,
    required String reservantTel,
    required int nbPlaces,
    required String departArret,
    required String arriveeArret,
    bool pourAutrui = false,
    String? nomPassager,
    String? telPassager,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("Utilisateur non connecté");

    final trajetRef = db.collection('trajets').doc(trajetId);
    final reservationRef = db.collection('reservations').doc();

    await db.runTransaction((txn) async {
      final snap = await txn.get(trajetRef);
      if (!snap.exists) throw Exception("Trajet introuvable");

      final data = snap.data() as Map<String, dynamic>;
      final placesDispo = (data['places_disponibles'] ?? 0) as int;

      if (placesDispo < nbPlaces) {
        throw Exception("Pas assez de places disponibles");
      }

      // Décrémenter les places
      txn.update(trajetRef, {
        'places_disponibles': placesDispo - nbPlaces,
      });

      // Créer la réservation
      txn.set(reservationRef, {
        'trajetId': trajetId,
        'userId': user.uid, // ✅ toujours l’UID du réservant connecté
        'reservant_nom': reservantNom,
        'reservant_tel': reservantTel,
        'pour_autrui': pourAutrui,
        'nom_passager': pourAutrui ? nomPassager : reservantNom,
        'tel_passager': pourAutrui ? telPassager : reservantTel,
        'depart_arret': departArret,
        'arrivee_arret': arriveeArret,
        'places_reservees': nbPlaces,
        'status': 'confirmée',
        'createdAt': FieldValue.serverTimestamp(),
        'horaire': data['horaire'],
        'depart_ville': data['depart'],
        'destination_ville': data['destination'],
      });
    });
  }
}
