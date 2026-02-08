const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

exports.autoCancelReservations = functions.pubsub
    .schedule("every 5 minutes") // 🔄 exécution régulière
    .onRun(async (context) => {
      const now = admin.firestore.Timestamp.now();

      // 🔎 Chercher toutes les réservations expirées
      const snapshot = await admin.firestore()
          .collection("reservations")
          .where("status", "==", "en attente")
          .where("expiresAt", "<=", now)
          .get();

      const batch = admin.firestore().batch();

      for (const doc of snapshot.docs) {
        const data = doc.data();
        const trajetId = data.trajetId;
        const placesReservees = data.places_reservees ?
        data.places_reservees :
        1;

        // ⚠️ Remettre les places dans le trajet
        const trajetRef = admin.firestore().collection("trajets").doc(trajetId);
        const trajetSnap = await trajetRef.get();
        if (trajetSnap.exists) {
          const trajetData = trajetSnap.data();
          const placesDispo = trajetData && trajetData.places_disponibles ?
           trajetData.places_disponibles :
           0;
          batch.update(trajetRef, {
            places_disponibles: placesDispo + placesReservees,
          });
        }

        // ✅ Annuler la réservation
        batch.update(doc.ref, {status: "annulée"});
      }

      await batch.commit();
      console.log(`✅ ${snapshot.size} réservations expirées annulées`);
      return null;
    });

exports.initWavePayment = functions.https.onRequest(async (req, res) => {
  const { reservationId } = req.body;
  // TODO: appeler l’API Wave
  await admin.firestore().collection("reservations").doc(reservationId)
    .update({ paymentStatus: "payé", status: "confirmée" });
  res.send({ status: "success", method: "Wave" });
});

exports.initOMPayment = functions.https.onRequest(async (req, res) => {
  const { reservationId } = req.body;
  // TODO: appeler l’API Orange Money
  await admin.firestore().collection("reservations").doc(reservationId)
    .update({ paymentStatus: "payé", status: "confirmée" });
  res.send({ status: "success", method: "Orange Money" });
});
