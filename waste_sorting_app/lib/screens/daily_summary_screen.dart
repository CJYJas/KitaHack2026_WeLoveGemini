import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class DailySummaryScreen extends StatefulWidget {
  const DailySummaryScreen({super.key});

  @override
  State<DailySummaryScreen> createState() => _DailySummaryScreenState();
}

class _DailySummaryScreenState extends State<DailySummaryScreen> {
  int _totalScans = 0;
  double _avgAccuracy = 0.0;
  int _earnedMarks = 0;
  List<dynamic> _todayScans = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = await ApiService().getHistory();
      
      final today = DateTime.now().toIso8601String().split('T')[0];
      
      final todayScans = history.where((scan) {
        final timestamp = scan['timestamp'] as String?;
        return timestamp != null && timestamp.startsWith(today);
      }).toList();

      double sumConfidence = 0;
      int marks = 0;
      for (var scan in todayScans) {
        double conf = (scan['confidence'] ?? 0).toDouble();
        sumConfidence += conf;
        if (conf >= 80) marks++;
      }

      setState(() {
        _totalScans = history.length; 
        _todayScans = todayScans;
        _earnedMarks = marks;
        _avgAccuracy = todayScans.isEmpty ? 0.0 : sumConfidence / todayScans.length;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading summary: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      appBar: AppBar(
        title: Text(
          'Daily Summary',
          style: GoogleFonts.quicksand(fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildStatsOverview(),
                const SizedBox(height: 32),
                Text(
                  'Today\'s Performance',
                  style: GoogleFonts.quicksand(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF558B2F),
                  ),
                ),
                const SizedBox(height: 16),
                _todayScans.isEmpty 
                  ? Center(child: Text('No scans yet today', style: GoogleFonts.quicksand(color: Colors.grey)))
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _todayScans.length,
                      itemBuilder: (context, index) => _buildScanListItem(_todayScans[index]),
                    ),
                const SizedBox(height: 24),
                _buildGuidanceCard(),
              ],
            ),
          ),
    );
  }

  Widget _buildStatsOverview() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFAED581), Color(0xFF9CCC65)],
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF558B2F).withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Today\'s Scans', '${_todayScans.length}'),
          Container(width: 1, height: 50, color: Colors.white24),
          _buildStatItem('Avg Accuracy', '${_avgAccuracy.toStringAsFixed(1)}%'),
          Container(width: 1, height: 50, color: Colors.white24),
          _buildStatItem('Today\'s Marks', '$_earnedMarks'),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.quicksand(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.quicksand(
            fontSize: 12,
            color: Colors.white.withOpacity(0.9),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildScanListItem(Map<String, dynamic> scan) {
    double confidence = (scan['confidence'] ?? 0).toDouble();
    bool isQualified = confidence >= 80;
    String category = scan['category'] ?? 'Waste';
    String timestampStr = scan['timestamp'] ?? '';
    String time = '';
    if (timestampStr.isNotEmpty) {
      try {
        DateTime dt = DateTime.parse(timestampStr).toLocal();
        time = "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isQualified ? const Color(0xFFC8E6C9) : const Color(0xFFFFEBEE),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (isQualified ? Colors.green : Colors.red).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isQualified ? Icons.check_circle_rounded : Icons.info_outline_rounded,
              color: isQualified ? Colors.green : Colors.red,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category,
                  style: GoogleFonts.quicksand(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '$time • ${confidence.toStringAsFixed(1)}% accuracy',
                  style: GoogleFonts.quicksand(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (isQualified)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFAED581),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '+1 Mark',
                style: GoogleFonts.quicksand(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGuidanceCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9C4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFFF176)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_rounded, color: Color(0xFFFBC02D)),
              const SizedBox(width: 12),
              Text(
                'How to earn more Marks?',
                style: GoogleFonts.quicksand(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFF9A825),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Ensure you scan waste items clearly within the frame. Every scan with 80% or more accuracy grants you 1 Mark instantly!',
            style: GoogleFonts.quicksand(
              fontSize: 14,
              color: const Color(0xFFF57F17),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
