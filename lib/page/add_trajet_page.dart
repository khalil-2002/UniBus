import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddTrajetPage extends StatefulWidget {
  const AddTrajetPage({super.key});

  @override
  State<AddTrajetPage> createState() => _AddTrajetPageState();
}

class _AddTrajetPageState extends State<AddTrajetPage> {
  final departController = TextEditingController();
  final destinationController = TextEditingController();
  final placesController = TextEditingController();
  final horaireController = TextEditingController();

  final List<TextEditingController> arretsDepartControllers = [];
  final List<TextEditingController> arretsArriveeControllers = [];

  bool isLoading = false;

  @override
  void dispose() {
    departController.dispose();
    destinationController.dispose();
    placesController.dispose();
    horaireController.dispose();
    for (var c in arretsDepartControllers) c.dispose();
    for (var c in arretsArriveeControllers) c.dispose();
    super.dispose();
  }

  void _addArretDepartField() {
    setState(() => arretsDepartControllers.add(TextEditingController()));
  }

  void _addArretArriveeField() {
    setState(() => arretsArriveeControllers.add(TextEditingController()));
  }

  Future<void> _saveTrajet() async {
    if (departController.text.isEmpty ||
        destinationController.text.isEmpty ||
        placesController.text.isEmpty ||
        horaireController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez remplir tous les champs")),
      );
      return;
    }

    final arretsDepart = arretsDepartControllers
        .map((c) => c.text.trim())
        .where((a) => a.isNotEmpty)
        .toList();

    final arretsArrivee = arretsArriveeControllers
        .map((c) => c.text.trim())
        .where((a) => a.isNotEmpty)
        .toList();

    if (arretsDepart.isEmpty || arretsArrivee.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ajoutez au moins un arrêt pour chaque ville")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('trajets').add({
        'depart': departController.text.trim(),
        'destination': destinationController.text.trim(),
        'places_disponibles': int.parse(placesController.text.trim()),
        'horaire': DateTime.parse(horaireController.text.trim()),
        'arrets_depart': arretsDepart,
        'arrets_arrivee': arretsArrivee,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Trajet ajouté ✅")),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur : ${e.toString()}")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ajouter un trajet"), backgroundColor: Colors.indigo),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(controller: departController, decoration: const InputDecoration(labelText: "Ville de départ")),
            TextField(controller: destinationController, decoration: const InputDecoration(labelText: "Ville d'arrivée")),
            TextField(controller: placesController, decoration: const InputDecoration(labelText: "Nombre de places"), keyboardType: TextInputType.number),
            TextField(controller: horaireController, decoration: const InputDecoration(labelText: "Horaire (ex: 2026-01-05 14:30)")),

            const SizedBox(height: 20),
            const Text("Arrêts de la ville de départ"),
            ...arretsDepartControllers.map((c) => TextField(controller: c, decoration: const InputDecoration(labelText: "Arrêt départ"))),
            TextButton.icon(onPressed: _addArretDepartField, icon: const Icon(Icons.add), label: const Text("Ajouter un arrêt départ")),

            const SizedBox(height: 20),
            const Text("Arrêts de la ville d'arrivée"),
            ...arretsArriveeControllers.map((c) => TextField(controller: c, decoration: const InputDecoration(labelText: "Arrêt arrivée"))),
            TextButton.icon(onPressed: _addArretArriveeField, icon: const Icon(Icons.add), label: const Text("Ajouter un arrêt arrivée")),

            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: isLoading ? null : _saveTrajet,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, padding: const EdgeInsets.symmetric(vertical: 14)),
              child: isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("Enregistrer le trajet"),
            ),
          ],
        ),
      ),
    );
  }
}
