import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';

// ✅ Import des pages
import 'package:app_univ_bus/page/login_page.dart';
import 'package:app_univ_bus/page/home_page.dart';
import 'package:app_univ_bus/page/mes_reservations_page.dart';
import 'package:app_univ_bus/page/add_trajet_page.dart';
import 'package:app_univ_bus/page/profil_page.dart';

void main() async { 
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const UniBusApp());
}

class UniBusApp extends StatelessWidget { 
  const UniBusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UniBus',
      debugShowCheckedModeBanner: false,

      // ✅ Thème global avec Google Fonts + Material 3
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        textTheme: GoogleFonts.poppinsTextTheme(), // ✅ police partout
        useMaterial3: true,
      ),

      // ✅ Dark Mode activé automatiquement
      darkTheme: ThemeData.dark(useMaterial3: true),
      themeMode: ThemeMode.system,

      // ✅ Point d’entrée
      initialRoute: '/login',

      // ✅ Définition des routes fixes
      routes: {
        '/login': (context) => const LoginPage(),
        '/profil': (context) => const ProfilPage(),
        '/mes_reservations': (context) => const MesReservationsPage(),
        '/add_trajet': (context) => const AddTrajetPage(),
      },

      // ✅ Gestion des routes avec arguments
      onGenerateRoute: (settings) {
        if (settings.name == '/home') {
          final role = settings.arguments as String? ?? "user";
          return MaterialPageRoute(
            builder: (_) => HomePage(role: role),
          );
        }
        return null;
      },
    );
  }
}
