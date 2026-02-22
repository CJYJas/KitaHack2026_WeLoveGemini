import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'leaderboard_screen.dart';
import 'camera_screen.dart';
import 'rewards_screen.dart';
import 'profile_screen.dart';
import 'package:camera/camera.dart';

abstract class RefreshableState<T extends StatefulWidget> extends State<T> {
  void refresh();
}

class NavigationWrapper extends StatefulWidget {
  const NavigationWrapper({super.key});

  @override
  State<NavigationWrapper> createState() => _NavigationWrapperState();
}

class _NavigationWrapperState extends State<NavigationWrapper> {
  int _selectedIndex = 0;
  final List<GlobalKey<RefreshableState>> _keys = [
    GlobalKey<RefreshableState>(),
    GlobalKey<RefreshableState>(),
    GlobalKey<RefreshableState>(), // Placeholder
    GlobalKey<RefreshableState>(),
    GlobalKey<RefreshableState>(),
  ];

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(key: _keys[0]),
      LeaderboardScreen(key: _keys[1]),
      const SizedBox.shrink(),
      RewardsScreen(key: _keys[3]),
      ProfileScreen(key: _keys[4]),
    ];
  }

  void _onItemTapped(int index) async {
    if (index == 2) {
      final cameras = await availableCameras();
      if (mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => CameraScreen(cameras: cameras)),
        );
        // Refresh EVERYTHING after camera returns
        for (var key in _keys) {
          key.currentState?.refresh();
        }
      }
    } else {
      setState(() {
        _selectedIndex = index;
      });
      // Trigger refresh on the selected screen
      _keys[index].currentState?.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF558B2F),
        unselectedItemColor: Colors.grey[400],
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.leaderboard_rounded), label: 'Leaderboard'),
          BottomNavigationBarItem(
            icon: CircleAvatar(
              backgroundColor: Color(0xFF558B2F),
              child: Icon(Icons.camera_alt_rounded, color: Colors.white),
            ),
            label: 'Scan',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.redeem_rounded), label: 'Rewards'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}
