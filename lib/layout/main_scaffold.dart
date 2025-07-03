import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:group_assignment/pages/stations.dart';
import 'package:group_assignment/pages/map.dart';
import 'package:group_assignment/pages/saved.dart';
import 'package:group_assignment/pages/saved_routes.dart';
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

  // Reminder fetch timer
  Timer? _reminderTimer;

  // Firebase
  final String userID = "1000";
  final CollectionReference collectionRoutes =
  FirebaseFirestore.instance.collection("savedRoutes");

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);

    // Start periodic reminder check
    _fetchAndNotify(); // Run once on start
    _reminderTimer =
        Timer.periodic(const Duration(minutes: 1), (_) => _fetchAndNotify());
  }

  @override
  void dispose() {
    _pageController.dispose();
    _reminderTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchAndNotify() async {
    try {
      final now = DateTime.now();
      // Get the current minute (ignoring seconds and milliseconds)
      final currentMinute = DateTime(now.year, now.month, now.day, now.hour, now.minute);

      final snapshot = await collectionRoutes
          .where('userID', isEqualTo: userID)
          .where('notificationStatus', isEqualTo: true)
          .get();

      for (var doc in snapshot.docs) {
        final item = doc.data() as Map<String, dynamic>?;

        if (item != null) {
          final alarmTime = item['alarmTime']?.toDate();
          final alarmMode = item['alarmMode'];
          final fromStation = item['fromStation']?.toString() ?? 'Unknown';
          final toStation = item['toStation']?.toString() ?? 'Unknown';

          if (alarmTime != null) {
            // Get the alarm minute (ignoring seconds and milliseconds)
            final alarmMinute = DateTime(
                alarmTime.year,
                alarmTime.month,
                alarmTime.day,
                alarmTime.hour,
                alarmTime.minute
            ).subtract(const Duration(minutes: 1));

            // Check if the alarm minute matches the current minute
            if (alarmMinute.isAtSameMomentAs(currentMinute)) {
              // For one-time alarms, show notification and then disable it
              if (alarmMode == 'One Time') {
                await _showNotificationAndDisable(doc.id, fromStation, toStation, item);
              }
              // For recurring alarms, just show the notification
              else {
                await _showNotification(fromStation, toStation, item);
              }
            }
          }
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error fetching reminders: $e\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to fetch reminders: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showNotificationAndDisable(String docId, String fromStation, String toStation, Map<String, dynamic> item) async {
    // Show the notification
    await _showNotification(fromStation, toStation, item);

    // Disable the notification for one-time alarms to prevent showing again
    try {
      await collectionRoutes.doc(docId).update({
        'notificationStatus': false,
      });
      debugPrint('✅ One-time alarm notification disabled for document: $docId');
    } catch (e) {
      debugPrint('❌ Error disabling notification: $e');
    }
  }

  Future<void> _showNotification(String fromStation, String toStation, Map<String, dynamic> item) async {
    final routeSteps = item['routeSteps'] as List<dynamic>?;
    final departure = routeSteps != null && routeSteps.isNotEmpty
        ? routeSteps[0]['departureTime']?.toString() ?? 'N/A'
        : 'N/A';

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '🚆 Train from $fromStation to $toStation will depart in $departure'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );
    }
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
          const SavedRoutes(),
        ],
      ),
      floatingActionButton:
      _buildFloatingActionButton(navBarColor, activeColor),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar:
      _buildBottomNavigationBar(navBarColor, activeColor, inactiveColor),
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
        return 'Saved Routes';
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

  Widget _buildBottomNavigationBar(
      Color navBarColor, Color activeColor, Color inactiveColor) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.1, // 10% of screen height
      child: BottomAppBar(
        color: navBarColor,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        elevation: 8,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
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
                      label: 'Saved\nStation',
                      index: 1,
                      activeColor: activeColor,
                      inactiveColor: inactiveColor,
                    ),
                  ],
                ),
              ),
              SizedBox(width: MediaQuery.of(context).size.width * 0.15), // Flexible FAB space
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNavItem(
                      icon: Icons.settings,
                      label: 'Saved\nRoutes',
                      index: 4,
                      activeColor: activeColor,
                      inactiveColor: inactiveColor,
                    ),
                    _buildNavItem(
                      icon: Icons.alarm,
                      label: 'Reminders',
                      index: 3,
                      activeColor: activeColor,
                      inactiveColor: inactiveColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
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
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: Container(
        constraints: BoxConstraints(
          minWidth: screenWidth * 0.15,
          maxWidth: screenWidth * 0.25,
        ),
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon with animated container
            Flexible(
              child: AnimatedContainer(
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
                  size: screenHeight * 0.03,
                ),
              ),
            ),

            // Spacer
            const SizedBox(height: 2),

            // Label text - Modified to handle text wrapping
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: screenHeight * 0.015,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  color: isActive ? activeColor : inactiveColor,
                ),
                textAlign: TextAlign.center,
                maxLines: 2, // Allow text to wrap to 2 lines
                overflow: TextOverflow.visible, // Show all text
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

  void updateLocation(double? lat, double? lng, String? address,
      {String? photoUrl}) {
    debugPrint(
        'Location update requested: lat=$lat, lng=$lng, address=$address');
  }
}