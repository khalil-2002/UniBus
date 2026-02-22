import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class EditTrajetPage extends StatefulWidget {
  final String trajetId;
  const EditTrajetPage({super.key, required this.trajetId});

  @override
  State<EditTrajetPage> createState() => _EditTrajetPageState();
}

class _EditTrajetPageState extends State<EditTrajetPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController departController;
  late TextEditingController destinationController;
  late TextEditingController placesController;
  late TextEditingController prixController;
  List<TextEditingController> arretsDepartControllers = [];
  List<TextEditingController> arretsArriveeControllers = [];

  DateTime? horaire;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTrajet();
  }

  Future<void> _loadTrajet() async {
    final doc = await FirebaseFirestore.instance.collection('trajets').doc(widget.trajetId).get();
    final data = doc.data()!;
    departController = TextEditingController(text: data['depart']);
    destinationController = TextEditingController(text: data['destination']);
    placesController = TextEditingController(text: data['places_disponibles'].toString());
    prixController = TextEditingController(text: data['prix']?.toString() ?? "");
    horaire = (data['horaire'] as Timestamp).toDate();

    // Charger les arrêts existants
    arretsDepartControllers = (data['arrets_depart'] as List<dynamic>)
        .map((a) => TextEditingController(text: a.toString()))
        .toList();
    arretsArriveeControllers = (data['arrets_arrivee'] as List<dynamic>)
        .map((a) => TextEditingController(text: a.toString()))
        .toList();

    setState(() {});
  }

  Future<void> _selectHoraire(BuildContext context) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: horaire ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate != null) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(horaire ?? DateTime.now()),
      );
      if (pickedTime != null) {
        setState(() {
          horaire = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  Future<void> _updateTrajet() async {
    if (_formKey.currentState!.validate() && horaire != null) {
      final arretsDepart = arretsDepartControllers
          .map((c) => c.text.trim())
          .where((a) => a.isNotEmpty)
          .toList();
      final arretsArrivee = arretsArriveeControllers
          .map((c) => c.text.trim())
          .where((a) => a.isNotEmpty)
          .toList();

      setState(() => isLoading = true);

      await FirebaseFirestore.instance.collection('trajets').doc(widget.trajetId).update({
        'depart': departController.text.trim(),
        'destination': destinationController.text.trim(),
        'places_disponibles': int.parse(placesController.text.trim()),
        'prix': int.parse(prixController.text.trim()),
        'horaire': horaire,
        'arrets_depart': arretsDepart,
        'arrets_arrivee': arretsArrivee,
      });

      setState(() => isLoading = false);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Trajet mis à jour ✅")),
      );
    }
  }

  void _addArretDepartField() {
    setState(() => arretsDepartControllers.add(TextEditingController()));
  }

  void _addArretArriveeField() {
    setState(() => arretsArriveeControllers.add(TextEditingController()));
  }

  @override
  Widget build(BuildContext context) {
    if (horaire == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Modifier un trajet", style: TextStyle(color: Colors.white)), backgroundColor: Colors.indigo),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: departController,
                decoration: const InputDecoration(labelText: "Ville de départ"),
                validator: (value) => value!.isEmpty ? "Champ obligatoire" : null,
              ),
              TextFormField(
                controller: destinationController,
                decoration: const InputDecoration(labelText: "Ville d'arrivée"),
                validator: (value) => value!.isEmpty ? "Champ obligatoire" : null,
              ),
              TextFormField(
                controller: placesController,
                decoration: const InputDecoration(labelText: "Nombre de places"),
                keyboardType: TextInputType.number,
                validator: (value) => value!.isEmpty ? "Champ obligatoire" : null,
              ),
              TextFormField(
                controller: prixController,
                decoration: const InputDecoration(labelText: "Prix du trajet (FCFA)"),
                keyboardType: TextInputType.number,
                validator: (value) => value!.isEmpty ? "Champ obligatoire" : null,
              ),

              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.access_time, color: Colors.indigo),
                title: Text("Horaire: ${DateFormat('dd/MM/yyyy HH:mm').format(horaire!)}"),
                trailing: ElevatedButton(
                  onPressed: () => _selectHoraire(context),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                  child: const Text("Calendrier", style: TextStyle(color: Colors.white)),
                ),
              ),

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
                onPressed: isLoading ? null : _updateTrajet,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, padding: const EdgeInsets.symmetric(vertical: 14)),
                child: isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("Mettre à jour le trajet", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
