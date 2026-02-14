import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'camera_screen.dart';
import 'login_screen.dart';
import 'rewards_screen.dart';
import '../services/api_service.dart';
import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Mock data for gamification state
  bool _isThriving = true; 
  double _habitatHealth = 0.8;
  int _scanCount = 0;
  int _totalPoints = 0;

  @override
  void initState() {
    super.initState();
    _loadScanCount();
  }

  Future<void> _loadScanCount() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _scanCount = prefs.getInt('scan_count') ?? 0;
      _totalPoints = prefs.getInt('total_points') ?? 0;
      // Calculate health: Starts at 0.3, maxes at 1.0 after 10 scans
      _habitatHealth = (0.3 + (_scanCount * 0.07)).clamp(0.0, 1.0);
      _isThriving = _habitatHealth > 0.6;
    });
  }

  void _logout(BuildContext context) async {
    await ApiService().logout();
    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  void _openCamera(BuildContext context) async {
    final cameras = await availableCameras();
    if (context.mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => CameraScreen(cameras: cameras)),
      );
      _loadScanCount(); // Refresh state after returning
    }
  }

  void _toggleState() {
    setState(() {
      _isThriving = !_isThriving;
      _habitatHealth = _isThriving ? 0.8 : 0.3;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE1F5FE), // Ice Blue background
      appBar: AppBar(
        title: const Text('Polar Guard'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Dynamic Habitat Section
            GestureDetector(
              onTap: _toggleState, // Tap to demo state change
              child: Container(
                height: 350,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.white],
                    stops: [0.6, 0.9],
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                  // Iceberg moving up/growing based on scan count
                  Stack(
                    alignment: Alignment.bottomCenter,
                    clipBehavior: Clip.none,
                    children: [
                       // Iceberg at bottom
                       AnimatedContainer(
                         duration: const Duration(seconds: 1),
                         curve: Curves.easeInOut,
                         width: 250.0 + (_scanCount * 10),
                         height: 150.0 + (_scanCount * 5),
                         child: SvgPicture.asset('assets/images/iceberg.svg', fit: BoxFit.contain),
                       ),
                       // Bear on top of iceberg
                       Padding(
                         padding: EdgeInsets.only(bottom: 80 + (_scanCount * 2), left: 20), 
                         child: SizedBox(
                           width: 120,
                           height: 120,
                           child: SvgPicture.asset('assets/images/polar_bear.svg', fit: BoxFit.contain),
                         ),
                       ),
                    ],
                  ),
                  ],
                ),
              ),
            ),
            
            // Stats & Controls
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))],
              ),
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Text(
                    'Habitat Health',
                    style: GoogleFonts.quicksand(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.blueGrey[700],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: _habitatHealth,
                      backgroundColor: Colors.grey[200],
                      color: _habitatHealth > 0.5 ? Colors.green : Colors.orange,
                      minHeight: 15,
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Action Grid
                  // Display Points
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.stars_rounded, color: Colors.orange, size: 28),
                        const SizedBox(width: 10),
                        Text(
                          '$_totalPoints Points',
                          style: GoogleFonts.quicksand(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.camera_alt_rounded,
                          label: 'Scan Trash',
                          color: Colors.green,
                          onTap: () => _openCamera(context),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.redeem_rounded,
                          label: 'My Rewards',
                          color: Colors.orange,
                          onTap: () {
                             Navigator.of(context).push(
                               MaterialPageRoute(builder: (context) => const RewardsScreen()),
                             );
                          },
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Impact History',
                      style: GoogleFonts.quicksand(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildHistoryItem('Plastic Bottle', '+10 pts', Icons.recycling, Colors.blue),
                  _buildHistoryItem('Cardboard Box', '+15 pts', Icons.inventory_2, Colors.brown),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(String title, String points, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.quicksand(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            Text(
              points,
              style: GoogleFonts.quicksand(
                fontWeight: FontWeight.bold,
                color: Colors.green[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final MaterialColor color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: color[800],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
