import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
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
  bool _isThriving = true; 
  double _habitatHealth = 0.8;
  int _scanCount = 0;
  int _totalMarks = 0;
  List<dynamic> _history = [];
  bool _isLoadingHistory = true;

  @override
  void refresh() => _loadData();

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
      
      if (mounted) {
        setState(() {
          _scanCount = history.length;
          _totalMarks = (profile['points'] ?? 0).toInt();
          _history = history;
          _isLoadingHistory = false;
          _habitatHealth = (0.3 + (_scanCount * 0.07)).clamp(0.0, 1.0);
          _isThriving = _habitatHealth > 0.6;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading home data: $e')),
        );
        setState(() => _isLoadingHistory = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
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
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: const Color(0xFF558B2F),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
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
                    Stack(
                      alignment: Alignment.bottomCenter,
                      clipBehavior: Clip.none,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 350,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              ModelViewer(
                                src: 'assets/low_poly_iceberg_scene.glb',
                                alt: "Iceberg Habitat",
                                autoRotate: false,
                                cameraControls: false,
                                backgroundColor: Colors.transparent,
                              ),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 80), // Lift bear to top of iceberg
                                child: SizedBox(
                                  width: 140, // Slightly larger
                                  height: 140,
                                  child: ModelViewer(
                                    src: 'assets/polar_bear.glb',
                                    alt: "Polar Bear",
                                    cameraOrbit: "-45deg 75deg auto", // Turn left 45' and adjust angle
                                    autoRotate: false,
                                    cameraControls: false,
                                    backgroundColor: Colors.transparent,
                                  ),
                                ),
                              ),
                            ],
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
                                _buildDailyStat('Today', '${_history.where((s) => s['timestamp']?.startsWith(DateTime.now().toIso8601String().split('T')[0]) ?? false).length}'),
                                _buildDailyStat('Daily Mark', _getDailyMarkStatus()),
                                _buildDailyStat('Avg Acc.', _getTodayAvgAcc()),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    _buildImpactHistory(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImpactHistory() {
    return Column(
      children: [
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
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text('No scans yet!', style: GoogleFonts.quicksand(color: Colors.grey)),
              )
            : Column(
                children: _history.take(5).map((scan) {
                  bool isComplaint = scan['isComplaint'] == true;
                  double conf = (scan['confidence'] ?? 0).toDouble();
                  String title = scan['category'] ?? 'Waste';
                  if (isComplaint) title += ' (Complaint)';
                  
                  return _buildHistoryItem(
                    title,
                    isComplaint ? '' : '${conf.toStringAsFixed(1)}%', 
                    _getCategoryIcon(scan['category']),
                    isComplaint ? const Color(0xFFEF5350) : _getCategoryColor(scan['category']),
                    isComplaint: isComplaint,
                  );
                }).toList(),
              ),
      ],
    );
  }

  String _getTodayAvgAcc() {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final todayScans = _history.where((s) => 
      (s['timestamp']?.startsWith(today) ?? false) && 
      (s['isComplaint'] != true) 
    ).toList();
    
    if (todayScans.isEmpty) return '0%';
    double sum = 0;
    for (var s in todayScans) {
      sum += (s['confidence'] ?? 0).toDouble();
    }
    return '${(sum / todayScans.length).toStringAsFixed(1)}%';
  }

  String _getDailyMarkStatus() {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final todayScans = _history.where((s) => 
      (s['timestamp']?.startsWith(today) ?? false) && 
      (s['isComplaint'] != true) 
    ).toList();
    
    if (todayScans.isEmpty) return '0';
    double sum = 0;
    for (var s in todayScans) {
      sum += (s['confidence'] ?? 0).toDouble();
    }
    return (sum / todayScans.length) >= 80 ? '1' : '0';
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

  Widget _buildHistoryItem(String title, String points, IconData icon, Color color, {bool isComplaint = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white, 
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isComplaint ? const Color(0xFFEF5350).withOpacity(0.4) : Colors.grey[200]!,
            width: isComplaint ? 2 : 1,
          ),
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
                  color: isComplaint ? const Color(0xFFEF5350) : const Color(0xFF333333),
                ),
              ),
            ),
            if (!isComplaint)
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
