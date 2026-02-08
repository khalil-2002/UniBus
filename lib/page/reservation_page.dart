import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReservationPage extends StatefulWidget {
  final String trajetId;

  const ReservationPage({super.key, required this.trajetId});

  @override
  State<ReservationPage> createState() => _ReservationPageState();
}

class _ReservationPageState extends State<ReservationPage> {
  final reservantNameController = TextEditingController();
  final reservantPhoneController = TextEditingController();
  bool forOther = false;
  final passengerNameController = TextEditingController();
  final passengerPhoneController = TextEditingController();

  String? departArret;
  String? arriveeArret;
  int placesReservees = 1;

  int placesDisponibles = 0;
  DateTime? horaire;
  String departVille = '';
  String destinationVille = '';
  List<String> arretsDepart = [];
  List<String> arretsArrivee = [];

  bool isLoading = false;
  bool isLoadingTrajet = true;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadTrajetInfo();
  }

  @override
  void dispose() {
    reservantNameController.dispose();
    reservantPhoneController.dispose();
    passengerNameController.dispose();
    passengerPhoneController.dispose();
    super.dispose();
  }
  Future<void> _loadUserInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snap = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (snap.exists) {
      final data = snap.data() as Map<String, dynamic>;
      setState(() {
        reservantNameController.text = data['nom'] ?? "";
        reservantPhoneController.text = data['telephone'] ?? "";
      });
    }
  }

  Future<void> _loadTrajetInfo() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('trajets').doc(widget.trajetId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          placesDisponibles = data['places_disponibles'] ?? 0;
          departVille = data['depart'] ?? '';
          destinationVille = data['destination'] ?? '';
          horaire = (data['horaire'] as Timestamp).toDate();
          arretsDepart = List<String>.from(data['arrets_depart'] ?? []);
          arretsArrivee = List<String>.from(data['arrets_arrivee'] ?? []);
        });
      }
    } finally {
      setState(() => isLoadingTrajet = false);
    }
  }

  bool _validate() {
    if (departArret == null || arriveeArret == null) {
      _snack("Choisissez un arrêt de départ et un arrêt d'arrivée");
      return false;
    }
    if (departArret == arriveeArret) {
      _snack("Les arrêts de départ et d'arrivée doivent être différents");
      return false;
    }
    if (placesReservees <= 0) {
      _snack("Le nombre de places doit être supérieur à 0");
      return false;
    }
    if (placesReservees > placesDisponibles) {
      _snack("Pas assez de places disponibles ($placesDisponibles restantes)");
      return false;
    }
    if (reservantNameController.text.trim().isEmpty ||
        reservantPhoneController.text.trim().isEmpty) {
      _snack("Votre nom et téléphone sont requis");
      return false;
    }
    if (forOther &&
        (passengerNameController.text.trim().isEmpty ||
         passengerPhoneController.text.trim().isEmpty)) {
      _snack("Nom et téléphone du passager sont requis");
      return false;
    }
    return true;
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _reserve() async {
    if (!_validate()) return;

    setState(() => isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Utilisateur non connecté");

      final trajetRef = FirebaseFirestore.instance.collection('trajets').doc(widget.trajetId);
      final reservationsRef = FirebaseFirestore.instance.collection('reservations');
      // Récupérer le rôle de l'utilisateur connecté
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        final userRole = userDoc.data()?['role'] ?? 'user'; // valeur par défaut = user


          // Vérifier combien de réservations en attente existent déjà pour cet utilisateur
        final existing = await reservationsRef
            .where('userId', isEqualTo: user.uid)
            .where('status', isEqualTo: 'en attente')
            .get();

        // 🔧 Définir la limite en fonction du rôle
        int maxPendingReservations;
        if (userRole == "admin") {
          maxPendingReservations = 5; // les admins peuvent avoir plus de réservations en attente
        } else {
          maxPendingReservations = 2; // utilisateurs normaux limités à 1
        }

        // ✅ Vérifier la limite
        if (existing.docs.length >= maxPendingReservations) {
          throw Exception(
            "Vous avez déjà atteint la limite de $maxPendingReservations réservations en attente. "
            "Veuillez en payer ou annuler avant d'en créer une nouvelle."
          );
        }

      await FirebaseFirestore.instance.runTransaction((tx) async {
        final trajetSnap = await tx.get(trajetRef);
        if (!trajetSnap.exists) throw Exception("Trajet introuvable");

        final data = trajetSnap.data() as Map<String, dynamic>;
        final currentPlaces = (data['places_disponibles'] ?? 0) as int;

        if (placesReservees > currentPlaces) {
          throw Exception("Places insuffisantes: $currentPlaces restantes, demandé $placesReservees");
        }

        // ⚠️ Ne pas décrémenter immédiatement → attendre paiement
        tx.set(reservationsRef.doc(), {
          'trajetId': widget.trajetId,
          'userId': user.uid,
          'reservant_nom': reservantNameController.text.trim(),
          'reservant_tel': reservantPhoneController.text.trim(),
          'pour_autrui': forOther,
          'nom_passager': forOther
              ? passengerNameController.text.trim()
              : reservantNameController.text.trim(),
          'tel_passager': forOther
              ? passengerPhoneController.text.trim()
              : reservantPhoneController.text.trim(),
          'depart_arret': departArret,
          'arrivee_arret': arriveeArret,
          'places_reservees': placesReservees,
          'status': 'en attente',          // ✅ en attente tant que pas payé
          'paymentStatus': 'en attente',   // ✅ paiement non effectué
          'expiresAt': DateTime.now().add(Duration(minutes: 30)), // délai avant annulation
          'createdAt': FieldValue.serverTimestamp(),
          'horaire': data['horaire'],
          'depart_ville': data['depart'],
          'destination_ville': data['destination'],
          'prix': data['prix'], // ✅ ajoute le prix du trajet

        });
      });

      _snack("Réservation créée ✅ En attente de paiement");
      Navigator.pop(context);
    } catch (e) {
      _snack("Erreur: ${e.toString()}");
    } finally {
      setState(() => isLoading = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    if (isLoadingTrajet) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Réserver un trajet"),
          backgroundColor: Colors.indigo,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Réserver un trajet"),
        backgroundColor: Colors.indigo,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            // Carte avec infos du trajet
            Card(
              color: Colors.indigo.shade50,
              child: ListTile(
                leading: const Icon(Icons.directions_bus, color: Colors.indigo),
                title: Text("$departVille → $destinationVille"),
                subtitle: Text(
                  "Horaire: ${horaire ?? ''}\nPlaces dispo: $placesDisponibles",
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Sélection arrêt de départ
            DropdownButtonFormField<String>(
              value: departArret,
              items: arretsDepart
                  .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                  .toList(),
              onChanged: (v) => setState(() => departArret = v),
              decoration: const InputDecoration(labelText: "Arrêt de départ"),
            ),
            const SizedBox(height: 12),

            // Sélection arrêt d'arrivée
            DropdownButtonFormField<String>(
              value: arriveeArret,
              items: arretsArrivee
                  .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                  .toList(),
              onChanged: (v) => setState(() => arriveeArret = v),
              decoration: const InputDecoration(labelText: "Arrêt d'arrivée"),
            ),
            const SizedBox(height: 16),

            // Nombre de places
            Row(
              children: [
                const Text("Nombre de places:", style: TextStyle(fontSize: 16)),
                Expanded(
                  child: Slider(
                    value: placesReservees.toDouble(),
                    min: 1,
                    max: (placesDisponibles > 0 ? placesDisponibles : 1).toDouble(),
                    divisions: (placesDisponibles > 0 ? placesDisponibles : 1),
                    label: "$placesReservees",
                    onChanged: (v) => setState(() => placesReservees = v.toInt()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Réserver pour quelqu’un d’autre
            SwitchListTile(
              title: const Text("Réserver pour quelqu'un d'autre"),
              value: forOther,
              onChanged: (v) => setState(() => forOther = v),
            ),

            const SizedBox(height: 8),
            const Text("Vos informations", style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              controller: reservantNameController,
              decoration: const InputDecoration(labelText: "Votre nom"),
            ),
            TextField(
              controller: reservantPhoneController,
              decoration: const InputDecoration(labelText: "Votre téléphone"),
              keyboardType: TextInputType.phone,
            ),

            if (forOther) ...[
              const SizedBox(height: 16),
              const Text("Informations du passager", style: TextStyle(fontWeight: FontWeight.bold)),
              TextField(
                controller: passengerNameController,
                decoration: const InputDecoration(labelText: "Nom du passager"),
              ),
              TextField(
                controller: passengerPhoneController,
                decoration: const InputDecoration(labelText: "Téléphone du passager"),
                keyboardType: TextInputType.phone,
              ),
            ],

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : _reserve,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Créer la réservation (en attente de paiement)"),
              ),
            ),

            const SizedBox(height: 12),
            const Text(
              "Note : la réservation reste en attente jusqu'au paiement. "
              "Si elle n'est pas payée avant l'expiration, elle sera annulée automatiquement.",
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}