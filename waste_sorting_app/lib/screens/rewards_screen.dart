import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

import 'navigation_wrapper.dart';

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => RewardsScreenState();
}

class RewardsScreenState extends RefreshableState<RewardsScreen> {
  @override
  void refresh() => _loadPoints();

  int _totalMarks = 0;
  bool _isRedeeming = false;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadPoints();
  }

  Future<void> _loadPoints() async {
    try {
      final profile = await _apiService.getUserProfile();
      setState(() {
        _totalMarks = (profile['points'] ?? 0).toInt();
      });
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _totalMarks = prefs.getInt('total_marks') ?? 0;
      });
    }
  }

  Future<void> _handleRedeem() async {
    if (_totalMarks < 14) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Insufficient marks. You need at least 14 marks to redeem!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isRedeeming = true);

    try {
      final result = await _apiService.redeemVoucher();
      if (result['success'] == true) {
        // Reset local spendable marks as per requirements
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('total_marks', 0);
        
        setState(() {
          _totalMarks = 0;
          _isRedeeming = false;
        });

        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text('Success!'),
              content: const Text('Voucher redeemed successfully! Your wallet (Marks) has been reset.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Awesome'),
                ),
              ],
            ),
          );
        }
      } else {
        throw Exception(result['error'] ?? 'Redemption failed');
      }
    } catch (e) {
      setState(() => _isRedeeming = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
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
          'My Rewards',
          style: GoogleFonts.quicksand(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF558B2F),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFFFB74D).withOpacity(0.5)),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.stars_rounded, color: Color(0xFFFFB74D), size: 24),
                const SizedBox(width: 8),
                Text(
                  '$_totalMarks marks',
                  style: GoogleFonts.quicksand(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: const Color(0xFFE65100),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _isRedeeming 
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20.0),
              children: [
                _buildSectionHeader('Exclusive Vouchers'),
                const SizedBox(height: 16),
                _buildRewardTile(
                  context,
                  'Zus Coffee',
                  'RM5 off (min spend RM15)',
                  Icons.local_cafe,
                  const Color(0xFF1A237E),
                ),
                _buildRewardTile(
                  context,
                  'Starbucks',
                  '20% Discount',
                  Icons.coffee_rounded,
                  const Color(0xFF00704A),
                ),
                _buildRewardTile(
                  context,
                  'TGV Cinemas',
                  'Free Popcorn (2 tickets)',
                  Icons.movie_creation_rounded,
                  const Color(0xFFE53935),
                ),
                _buildRewardTile(
                  context,
                  'GSC Cinemas',
                  'RM2 off per ticket',
                  Icons.confirmation_num_rounded,
                  const Color(0xFFFDD835),
                ),
                _buildRewardTile(
                  context,
                  'Lotus\'s',
                  'RM10 Cash Voucher',
                  Icons.shopping_bag_rounded,
                  const Color(0xFF2E7D32),
                ),
                _buildRewardTile(
                  context,
                  'Aeon Big',
                  '10% off total bill',
                  Icons.add_shopping_cart_rounded,
                  const Color(0xFF8E24AA),
                ),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.quicksand(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF558B2F),
      ),
    );
  }

  Widget _buildRewardTile(BuildContext context, String brand, String rebate, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  brand,
                  style: GoogleFonts.quicksand(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  rebate,
                  style: GoogleFonts.quicksand(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: _handleRedeem,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFAED581),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: Text(
              'Redeem',
              style: GoogleFonts.quicksand(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
