import 'package:flutter/material.dart';
import 'package:group_assignment/pages/stations.dart';
import 'package:group_assignment/pages/map.dart';
import 'package:group_assignment/pages/saved.dart';
import 'package:group_assignment/pages/settings.dart';
import 'package:group_assignment/pages/reminders.dart';

class MainScaffold extends StatefulWidget {
  final int initialIndex;
  final double? lat;
  final double? lng;
  final String? name;
  final String? address;
  final String? photoUrl;
  final bool showAppBar;

  const MainScaffold({
    super.key,
    this.initialIndex = 0,
    this.lat,
    this.lng,
    this.name,
    this.address,
    this.photoUrl,
    this.showAppBar = true,
  });

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    final Color navBarColor = Colors.pink.shade100;
    final Color activeColor = Colors.pink.shade700;

    final List<Widget> pages = [
      const StationsPage(),
      const SavedPage(),
      MapPage(lat: widget.lat, lng: widget.lng, name: widget.name, address: widget.address, photoUrl: widget.photoUrl),
      const RemindersPage(),
      const SettingsPage(),
    ];

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: widget.showAppBar
          ? AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8), // adjust radius as needed
              child: Image.asset(
                'assets/icons/icon.png',
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.train),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'UK TRAIN GO',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.pink.shade700, // activePink
              ),
            ),
          ],
        ),
      )
          : null,
      body: pages[_selectedIndex],
      floatingActionButton: FloatingActionButton(
        backgroundColor: navBarColor,
        elevation: 4,
        onPressed: () => _onItemTapped(2),
        shape: const CircleBorder(),
        child: Icon(
          Icons.location_pin,
          color: _selectedIndex == 2 ? activeColor : Colors.black87,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: navBarColor,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: SizedBox(
          height: 65,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: Icons.directions_railway,
                label: 'Trains',
                index: 0,
                activeColor: activeColor,
              ),
              _buildNavItem(
                icon: Icons.bookmark,
                label: 'Saved',
                index: 1,
                activeColor: activeColor,
              ),
              const SizedBox(width: 40), // space for FAB
              _buildNavItem(
                icon: Icons.alarm,
                label: 'Reminders',
                index: 3,
                activeColor: activeColor,
              ),
              _buildNavItem(
                icon: Icons.settings,
                label: 'Settings',
                index: 4,
                activeColor: activeColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    required Color activeColor,
  }) {
    final isActive = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isActive ? activeColor : Colors.black54),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isActive ? activeColor : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}