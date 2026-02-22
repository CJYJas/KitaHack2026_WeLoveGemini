import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'camera_screen.dart';
import 'login_screen.dart';
import 'rewards_screen.dart';
import 'leaderboard_screen.dart';
import 'daily_summary_screen.dart';
import '../services/api_service.dart';
import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'navigation_wrapper.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends RefreshableState<HomeScreen> {
  // Mock data for gamification state
  bool _isThriving = true; 

  @override
  void refresh() => _loadData();

  double _habitatHealth = 0.8;
  int _scanCount = 0;
  int _totalMarks = 0;
  List<dynamic> _history = [];
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final apiService = ApiService();
      final profile = await apiService.getUserProfile();
      final history = await apiService.getHistory();
      
      setState(() {
        _totalMarks = (profile['points'] ?? 0).toInt();
        _history = history;
        _isLoadingHistory = false;
        
        // For habitat health, we still use scan_count but it would be better 
        // if the backend returned this. For now, let's keep it from prefs or length of history.
        _scanCount = history.length; 
        _habitatHealth = (0.3 + (_scanCount * 0.07)).clamp(0.0, 1.0);
        _isThriving = _habitatHealth > 0.6;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading home data: $e')),
        );
      }
      setState(() => _isLoadingHistory = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9), // Pale Greenish-White
      appBar: AppBar(
        title: Text(
          'Polar Guard',
          style: GoogleFonts.quicksand(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF558B2F),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Dynamic Habitat Section
            Container(
                height: 350,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xFFE8F5E9)],
                    stops: [0.6, 1.0],
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
            
            // Stats & Controls
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, -10),
                  )
                ],
              ),
              padding: const EdgeInsets.all(28.0),
              child: Column(
                children: [
                  Text(
                    'Habitat Health',
                    style: GoogleFonts.quicksand(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF558B2F),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 20,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCEDC8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Stack(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 800),
                          width: MediaQuery.of(context).size.width * 0.8 * _habitatHealth,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFAED581), Color(0xFF9CCC65)],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFAED581).withOpacity(0.4),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Display Marks
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F8E9),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFDCEDC8)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.stars_rounded, color: Color(0xFFFFB74D), size: 32),
                        const SizedBox(width: 12),
                        Text(
                          '$_totalMarks Marks',
                          style: GoogleFonts.quicksand(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF558B2F),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  // Daily Summary Section
                  InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const DailySummaryScreen()),
                      );
                    },
                    borderRadius: BorderRadius.circular(28),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: const Color(0xFFBBDEFB)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.analytics_rounded, color: Color(0xFF1976D2)),
                              const SizedBox(width: 12),
                              Text(
                                'Daily Summary',
                                style: GoogleFonts.quicksand(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1976D2),
                                ),
                              ),
                              const Spacer(),
                              const Icon(Icons.chevron_right_rounded, color: Color(0xFF1976D2)),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildDailyStat('Scans', '$_scanCount'),
                              _buildDailyStat('Avg Acc.', '84.5%'),
                              _buildDailyStat('Status', 'Trustworthy'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Impact History',
                      style: GoogleFonts.quicksand(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF558B2F),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  _isLoadingHistory 
                    ? const Center(child: CircularProgressIndicator())
                    : _history.isEmpty 
                      ? Text('No scans yet!', style: GoogleFonts.quicksand(color: Colors.grey))
                      : Column(
                          children: _history.take(5).map((scan) {
                            return _buildHistoryItem(
                              scan['category'] ?? 'Waste',
                              scan['confidence'] >= 80 ? '+1 mark' : '0 marks',
                              _getCategoryIcon(scan['category']),
                              _getCategoryColor(scan['category']),
                            );
                          }).toList(),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String? category) {
    category = category?.toLowerCase() ?? '';
    if (category.contains('plastic')) return Icons.recycling;
    if (category.contains('paper')) return Icons.description;
    if (category.contains('aluminium') || category.contains('tin')) return Icons.inventory_2;
    if (category.contains('glass')) return Icons.liquor;
    if (category.contains('food')) return Icons.restaurant;
    return Icons.delete_outline;
  }

  Color _getCategoryColor(String? category) {
    category = category?.toLowerCase() ?? '';
    if (category.contains('plastic')) return Colors.blue;
    if (category.contains('paper')) return Colors.orange;
    if (category.contains('aluminium') || category.contains('tin')) return Colors.grey;
    if (category.contains('glass')) return Colors.teal;
    if (category.contains('food')) return Colors.brown;
    return Colors.blueGrey;
  }

  Widget _buildDailyStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.quicksand(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0D47A1),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.quicksand(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF64B5F6),
          ),
        ),
      ],
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
  final Color color;
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
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 36, color: color),
            const SizedBox(height: 12),
            Text(
              label,
              style: GoogleFonts.quicksand(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: color.withOpacity(0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
