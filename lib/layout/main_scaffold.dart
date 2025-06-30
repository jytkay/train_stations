import 'package:flutter/material.dart';
import 'package:group_assignment/pages/stations.dart';
import 'package:group_assignment/pages/map.dart';
import 'package:group_assignment/pages/saved.dart';
import 'package:group_assignment/pages/settings.dart';
import 'package:group_assignment/pages/reminders.dart';

class MainScaffold extends StatefulWidget {
  final int initialIndex;
  final String? name;
  final double? lat;
  final double? lng;
  final String? address;
  final String? photoUrl;

  const MainScaffold({
    super.key,
    this.initialIndex = 0,
    this.name,
    this.lat,
    this.lng,
    this.address,
    this.photoUrl,
  });

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  late int _selectedIndex;
  late PageController _pageController;
  bool showAppBar = true;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color navBarColor = Colors.pink.shade100;
    final Color activeColor = Colors.pink.shade700;
    final Color inactiveColor = Colors.black54;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: showAppBar ? _buildAppBar() : null,
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        children: [
          const StationsPage(),
          const SavedPage(),
          MapPage(
            lat: widget.lat,
            lng: widget.lng,
            name: widget.name,
            address: widget.address,
            photoUrl: widget.photoUrl,
          ),
          const RemindersPage(),
          const SettingsPage(),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(navBarColor, activeColor),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomNavigationBar(navBarColor, activeColor, inactiveColor),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 2,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _getPageTitle(),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          if (widget.address != null && widget.address!.isNotEmpty)
            Text(
              widget.address!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
                color: Colors.grey[600],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
      actions: [
        if (_selectedIndex == 2)
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Refreshing location...'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
      ],
    );
  }

  String _getPageTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'Train Stations';
      case 1:
        return 'Saved Stations';
      case 2:
        return 'Map View';
      case 3:
        return 'Reminders';
      case 4:
        return 'Settings';
      default:
        return 'Train Stations';
    }
  }

  Widget _buildFloatingActionButton(Color navBarColor, Color activeColor) {
    return FloatingActionButton(
      backgroundColor: navBarColor,
      elevation: _selectedIndex == 2 ? 8 : 4,
      onPressed: () => _onItemTapped(2),
      shape: const CircleBorder(),
      child: Icon(
        Icons.location_pin,
        color: _selectedIndex == 2 ? activeColor : Colors.black87,
        size: 28,
      ),
    );
  }

  Widget _buildBottomNavigationBar(Color navBarColor, Color activeColor, Color inactiveColor) {
    return BottomAppBar(
      color: navBarColor,
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavItem(
                    icon: Icons.directions_railway,
                    label: 'Trains',
                    index: 0,
                    activeColor: activeColor,
                    inactiveColor: inactiveColor,
                  ),
                  _buildNavItem(
                    icon: Icons.bookmark,
                    label: 'Saved',
                    index: 1,
                    activeColor: activeColor,
                    inactiveColor: inactiveColor,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 48), // FAB space (typically 56 with margin)
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavItem(
                    icon: Icons.alarm,
                    label: 'Reminders',
                    index: 3,
                    activeColor: activeColor,
                    inactiveColor: inactiveColor,
                  ),
                  _buildNavItem(
                    icon: Icons.settings,
                    label: 'Settings',
                    index: 4,
                    activeColor: activeColor,
                    inactiveColor: inactiveColor,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onItemTapped(int index) {
    if (_selectedIndex != index) {
      setState(() {
        _selectedIndex = index;
      });
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    required Color activeColor,
    required Color inactiveColor,
  }) {
    final isActive = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: Container(
        width: 60,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(4),
              decoration: isActive
                  ? BoxDecoration(
                color: activeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              )
                  : null,
              child: Icon(
                icon,
                color: isActive ? activeColor : inactiveColor,
                size: isActive ? 26 : 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: isActive ? 12 : 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                color: isActive ? activeColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Public getters
  String? get currentName => widget.name;
  String? get currentAddress => widget.address;
  double? get currentLat => widget.lat;
  double? get currentLng => widget.lng;
  String? get currentPhotoUrl => widget.photoUrl;
  int get currentIndex => _selectedIndex;

  void navigateToPage(int index) {
    _onItemTapped(index);
  }

  void updateLocation(double? lat, double? lng, String? address, {String? photoUrl}) {
    debugPrint('Location update requested: lat=$lat, lng=$lng, address=$address');
  }
}
