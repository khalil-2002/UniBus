import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'login_page.dart';
import 'trajets_page.dart';
import 'mes_reservations_page.dart';
import 'profil_page.dart';
import 'add_trajet_page.dart';


class HomePage extends StatefulWidget {
  final String role;
  const HomePage({super.key, required this.role});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  int _selectedIndex = 0;

  // ===== CONTROLLERS =====
  late final AnimationController _navController;
  late final AnimationController _fabController;
  late final AnimationController _homeController;

  // ===== ANIMATIONS =====
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _navScale;
  // Position initiale du bouton
double fabX = 20; // horizontale
double fabY = 500; // verticale


  @override
  void initState() {
    super.initState();

    // NavigationBar rebond
    _navController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _navScale = Tween<double>(begin: 1, end: 1.2).animate(
      CurvedAnimation(parent: _navController, curve: Curves.elasticOut),
    );

    // FAB animation
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Accueil fade + slide
    _homeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(parent: _homeController, curve: Curves.easeIn);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _homeController, curve: Curves.easeOut));

    _homeController.forward();
    _fabController.forward();
  }

  @override
  void dispose() {
    _navController.dispose();
    _fabController.dispose();
    _homeController.dispose();
    super.dispose();
  }

  void _onTabChange(int index) {
    _navController.forward(from: 0);
    _fabController.forward(from: 0);
    setState(() => _selectedIndex = index);
  }
  // ================= ACCUEIL =================
  Widget _buildAccueil() {
    final user = FirebaseAuth.instance.currentUser;
    final todayStr = DateFormat('dd MMMM yyyy').format(DateTime.now());

    final startOfDay = DateTime.now();
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage("assets/bus_background2.jpg"),
              fit: BoxFit.cover,
            ),
          ),
          child: Container(
           color: Colors.black.withOpacity(0.7), // ✅ texte plus lisible sur fond

            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),

                  // ===== HEADER GLASS =====
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.white.withOpacity(0.12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child:Row(
                    children: [
                      const CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.indigo,
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded( // ✅ empêche le débordement
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Bonjour 👋",
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.white70,
                              ),
                            ),
                            Text(
                              user?.email ?? "Utilisateur",
                              style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              shadows: [Shadow(color: Colors.black54, blurRadius: 2)], // ✅ lisibilité renforcée
                            ),

                              overflow: TextOverflow.ellipsis, // ✅ coupe si trop long
                            ),
                            Text(
                              todayStr,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )

                  ),

                  const SizedBox(height: 20),

                  // ===== MAP MOCK =====
                  Container(
                    height: 190,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      image: const DecorationImage(
                        image: AssetImage("assets/map_mock.png"),
                        fit: BoxFit.cover,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Align(
                      alignment: Alignment.topRight,
                      child: Container(
                        margin: const EdgeInsets.all(12),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.indigo,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          "Trajets actifs",
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ===== DASHBOARD =====
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('trajets')
                        .where('horaire',
                            isGreaterThanOrEqualTo: startOfDay)
                        .where('horaire', isLessThan: endOfDay)
                        .snapshots(),
                    builder: (context, snapshot) {
                      int count =
                          snapshot.hasData ? snapshot.data!.docs.length : 0;
                      return _dashboardCard(
                        icon: Icons.directions_bus,
                        title: "Trajets aujourd’hui",
                        subtitle: "$count disponibles",
                        badgeColor: Colors.indigo,
                        onTap: () => _onTabChange(1),
                      );
                    },
                  ),

                  _dashboardCard(
                    icon: Icons.event_note,
                    title: "Mes réservations",
                    subtitle: "Consulter mes trajets",
                    badgeColor: Colors.orange,
                    onTap: () => _onTabChange(2),
                  ),

                  const SizedBox(height: 12),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Chip(
                      avatar: const Icon(Icons.circle,
                          color: Colors.green, size: 10),
                      label: const Text("Service actif"),
                      backgroundColor: Colors.green.withOpacity(0.2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ================= DASHBOARD CARD =================
  Widget _dashboardCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color badgeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [badgeColor.withOpacity(0.8), badgeColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: badgeColor.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.white.withOpacity(0.2),
            child: Icon(icon, color: Colors.white),
          ),
          title: Text(title,
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600, color: Colors.white)),
          subtitle: Text(subtitle,
              style: GoogleFonts.poppins(color: Colors.white70)),
          trailing: const Icon(Icons.arrow_forward_ios,
              size: 16, color: Colors.white),
        ),
      ),
    );
  }
  // ================= BUILD =================
  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildAccueil(),
      TrajetsPage(role: widget.role),
      const MesReservationsPage(),
      const ProfilPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("UniBus"),
        backgroundColor: Colors.indigo,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
          final confirm = await showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text("Déconnexion"),
              content: const Text("Voulez-vous vraiment vous déconnecter ?"),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Annuler")),
                ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Oui")),
              ],
            ),
          );
          if (confirm == true) {
            await FirebaseAuth.instance.signOut();
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginPage()),
              (_) => false,
            );
          }
        }

          ),
        ],
      ),

      // ✅ Transition fluide entre pages
      body: Stack(
  children: [
    // ✅ Ton contenu principal avec transition fluide
    AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.08, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: pages[_selectedIndex],
    ),

    // ✅ FAB déplaçable et fixé
    if (widget.role == "admin" && (_selectedIndex == 0 || _selectedIndex == 1))
      Positioned(
        left: fabX,
        top: fabY,
        child: GestureDetector(
          onPanUpdate: (details) {
            setState(() {
              fabX += details.delta.dx;
              fabY += details.delta.dy;
            });
          },
          child: ScaleTransition(
            scale: CurvedAnimation(parent: _fabController, curve: Curves.elasticOut),
            child: FloatingActionButton.extended(
              backgroundColor: Colors.indigo,
              icon: const Icon(Icons.add),
              label: const Text("Ajouter un trajet"),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddTrajetPage()),
                );
                _onTabChange(1);
              },
            ),
          ),
        ),
      ),
  ],
),

      // ✅ NavigationBar modernisée
      bottomNavigationBar: NavigationBar(
        backgroundColor: Colors.white.withOpacity(0.9),
        indicatorColor: Colors.indigo.shade100,
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onTabChange,
        destinations: [
          _navItem(Icons.home_outlined, Icons.home, "Accueil", 0),
          _navItem(Icons.directions_bus_outlined, Icons.directions_bus, "Trajets", 1),
          _navItem(Icons.event_note_outlined, Icons.event_note, "Réservations", 2),
          _navItem(Icons.person_outline, Icons.person, "Profil", 3),
        ],
      ),

          
    );
  }
  // ================= NAV ITEM =================
  NavigationDestination _navItem(
      IconData icon, IconData selectedIcon, String label, int index) {
    return NavigationDestination(
      icon: ScaleTransition(
        scale: _selectedIndex == index ? _navScale : const AlwaysStoppedAnimation(1),
        child: Icon(icon),
      ),
      selectedIcon: Icon(selectedIcon, color: Colors.indigo),
      label: label,
    );
  }
}
