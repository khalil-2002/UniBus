import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';



class QRTicketPage extends StatelessWidget {
  final Map<String, dynamic> reservationData;

  const QRTicketPage({super.key, required this.reservationData});

  @override
  Widget build(BuildContext context) {
    // Données brutes
    final rawData = jsonEncode({
      "reservationId": reservationData['reservationId'],
      "userId": reservationData['userId'],
      "trajetId": reservationData['trajetId'],
      "places": reservationData['places_reservees'],
    });

    // Hash pour sécuriser le QR
    final hash = sha256.convert(utf8.encode(rawData)).toString();

    final qrData = jsonEncode({
      "data": rawData,
      "signature": hash,
    });

    DateTime? horaire;
              final h = reservationData['horaire'];

              if (h is Timestamp) {
                horaire = h.toDate();
              } else if (h is String) {
                horaire = DateTime.tryParse(h);
              } else {
                horaire = null;
              }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Billet électronique"),
        backgroundColor: Colors.indigo,
      ),
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "🎫 Billet électronique",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              QrImageView(
                data: qrData,
                size: 200,
                backgroundColor: Colors.white,
              ),
              const SizedBox(height: 20),
              Text("Trajet : ${reservationData['depart_arret']} → ${reservationData['arrivee_arret']}"),
              Text("Passager : ${reservationData['nom_passager'] ?? 'Inconnu'}"),
              Text("Places : ${reservationData['places_reservees']}"),
              if (horaire != null)
                Text("Horaire : ${horaire.toLocal()}"),
              Text("Statut : ${reservationData['status'] ?? 'en attente'}"),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text("Télécharger en PDF"),
                onPressed: () async {
                  final pdf = pw.Document();

                  pdf.addPage(
                    pw.Page(
                      build: (pw.Context context) => pw.Center(
                        child: pw.Column(
                          mainAxisSize: pw.MainAxisSize.min,
                          children: [
                            pw.Text("Billet électronique", style: pw.TextStyle(fontSize: 24)),
                            pw.SizedBox(height: 20),
                            pw.Text("Trajet : ${reservationData['depart_arret']} → ${reservationData['arrivee_arret']}"),
                            pw.Text("Passager : ${reservationData['nom_passager'] ?? 'Inconnu'}"),
                            pw.Text("Places : ${reservationData['places_reservees']}"),
                            if (horaire != null)
                              pw.Text("Horaire : ${horaire.toLocal()}"),
                            pw.Text("Statut : ${reservationData['status'] ?? 'en attente'}"),
                            pw.SizedBox(height: 20),
                            pw.BarcodeWidget(
                              barcode: pw.Barcode.qrCode(),
                              data: qrData,
                              width: 200,
                              height: 200,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );

                  await Printing.layoutPdf(onLayout: (format) => pdf.save());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
