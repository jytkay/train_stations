import 'package:flutter/material.dart';
import 'package:group_assignment/pages/stations.dart';
import 'package:group_assignment/pages/map.dart';
import 'package:group_assignment/pages/saved.dart';
import 'package:group_assignment/pages/settings.dart';
import 'package:group_assignment/pages/reminders.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  Timer? _reminderTimer;
  final String userID = "1000"; // Your user ID
  final CollectionReference _remindersCollection =
  FirebaseFirestore.instance.collection('savedReminders');

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;

    _fetchAndNotify(); // Run once on start
    _reminderTimer = Timer.periodic(
        const Duration(minutes: 1),
            (_) => _fetchAndNotify()
    );
  }

  @override
  void dispose() {
    // Add timer cleanup
    _reminderTimer?.cancel();
    super.dispose();
  }

  // Add these notification methods
  Future<void> _fetchAndNotify() async {
    try {
      final now = DateTime.now();
      // Get the current minute (ignoring seconds and milliseconds)
      final currentMinute = DateTime(
          now.year,
          now.month,
          now.day,
          now.hour,
          now.minute
      );

      final snapshot = await _remindersCollection
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

  Future<void> _showNotificationAndDisable(
      String docId,
      String fromStation,
      String toStation,
      Map<String, dynamic> item
      ) async {
    // Show the notification
    await _showNotification(fromStation, toStation, item);

    // Disable the notification for one-time alarms to prevent showing again
    try {
      await _remindersCollection.doc(docId).update({
        'notificationStatus': false,
      });
      debugPrint('✅ One-time alarm notification disabled for document: $docId');
    } catch (e) {
      debugPrint('❌ Error disabling notification: $e');
    }
  }

  Future<void> _showNotification(
      String fromStation,
      String toStation,
      Map<String, dynamic> item
      ) async {
    final routeSteps = item['routeSteps'] as List<dynamic>?;
    final departure = routeSteps != null && routeSteps.isNotEmpty
        ? routeSteps[0]['departureTime']?.toString() ?? 'N/A'
        : 'N/A';

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '🚆 Train from $fromStation to $toStation will depart at $departure'
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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