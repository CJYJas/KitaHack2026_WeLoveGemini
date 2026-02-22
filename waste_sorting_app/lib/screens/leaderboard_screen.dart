import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import 'navigation_wrapper.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => LeaderboardScreenState();
}

class LeaderboardScreenState extends RefreshableState<LeaderboardScreen> with SingleTickerProviderStateMixin {
  @override
  void refresh() => _loadData();

  late TabController _tabController;
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  Map<String, dynamic>? _weeklyData;
  Map<String, dynamic>? _lifetimeData;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final weekly = await _apiService.getLeaderboard(type: 'weekly');
      final total = await _apiService.getLeaderboard(type: 'total');
      setState(() {
        _weeklyData = weekly;
        _lifetimeData = total;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading leaderboard: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      appBar: AppBar(
        title: Text(
          'Rankings',
          style: GoogleFonts.quicksand(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF558B2F),
          labelColor: const Color(0xFF558B2F),
          unselectedLabelColor: Colors.grey,
          labelStyle: GoogleFonts.quicksand(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Weekly'),
            Tab(text: 'Lifetime'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildLeaderboardList(_weeklyData),
                _buildLeaderboardList(_lifetimeData),
              ],
            ),
    );
  }

  Widget _buildLeaderboardList(Map<String, dynamic>? data) {
    if (data == null) return const Center(child: Text('No data available'));

    final top5 = data['top5'] as List<dynamic>? ?? [];
    final myRank = data['myRank'] ?? '-';
    final myPoints = data['myPoints'] ?? 0;

    return Column(
      children: [
        // Personal Rank Card
        Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFAED581), Color(0xFF9CCC65)],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF558B2F).withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildRankStat('Your Rank', '#$myRank'),
              Container(width: 1, height: 40, color: Colors.white24),
              _buildRankStat('Your Marks', '$myPoints'),
            ],
          ),
        ),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: top5.length,
            itemBuilder: (context, index) {
              final player = top5[index];
              return _buildPlayerTile(index + 1, player['username'], player['points']);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRankStat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.quicksand(
            color: Colors.white.withOpacity(0.9),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.quicksand(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerTile(int rank, String name, dynamic points) {
    bool isTop3 = rank <= 3;
    Color rankColor = isTop3
        ? (rank == 1 ? const Color(0xFFFFD700) : (rank == 2 ? const Color(0xFFC0C0C0) : const Color(0xFFCD7F32)))
        : Colors.transparent;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isTop3 ? rankColor : Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Text(
              '$rank',
              style: GoogleFonts.quicksand(
                fontWeight: FontWeight.bold,
                color: isTop3 ? Colors.white : Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              name,
              style: GoogleFonts.quicksand(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          Text(
            '$points marks',
            style: GoogleFonts.quicksand(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF558B2F),
            ),
          ),
        ],
      ),
    );
  }
}
