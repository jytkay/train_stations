import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:group_assignment/layout/main_scaffold.dart';
import 'package:group_assignment/firestore/save_stations.dart';

class SavedPage extends StatefulWidget {
  const SavedPage({super.key});

  @override
  State<SavedPage> createState() => _SavedPageState();
}

class _SavedPageState extends State<SavedPage>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _stations = [];
  List<Map<String, dynamic>> _routes = [];
  final Set<String> _selectedPlaceIds = {};
  final Set<String> _selectedRouteIds = {};
  bool _isLoadingStations = true;
  bool _isLoadingRoutes = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadStations();
    _loadRoutes();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStations() async {
    setState(() {
      _isLoadingStations = true;
    });
    final snapshot =
        await FirebaseFirestore.instance
            .collection('savedStations')
            .orderBy('savedAt', descending: true)
            .get();
    setState(() {
      _stations = snapshot.docs.map((doc) => doc.data()).toList();
      _isLoadingStations = false;
    });
  }

  Future<void> _loadRoutes() async {
    setState(() {
      _isLoadingRoutes = true;
    });
    final snapshot =
        await FirebaseFirestore.instance
            .collection('savedRoutes')
            .orderBy('savedAt', descending: true)
            .get();
    setState(() {
      _routes = snapshot.docs.map((doc) => doc.data()).toList();
      _isLoadingRoutes = false;
    });
  }

  Future<void> _removeRouteById(String routeId) async {
    final query =
        await FirebaseFirestore.instance
            .collection('savedRoutes')
            .where('routeId', isEqualTo: routeId)
            .limit(1)
            .get();
    if (query.docs.isNotEmpty) {
      await query.docs.first.reference.delete();
    }
  }

  Future<void> _saveRouteToFirestore({
    required String routeId,
    required String fromStation,
    required String toStation,
    required List<Map<String, dynamic>> routeSteps,
    required Map<String, dynamic> routeDetails,
    String? note,
  }) async {
    final query =
        await FirebaseFirestore.instance
            .collection('savedRoutes')
            .where('routeId', isEqualTo: routeId)
            .limit(1)
            .get();

    final routeData = {
      'routeId': routeId,
      'fromStation': fromStation,
      'toStation': toStation,
      'routeSteps': routeSteps,
      'routeDetails': routeDetails,
      'note': note ?? '',
      'savedAt': Timestamp.now(),
    };

    if (query.docs.isNotEmpty) {
      await query.docs.first.reference.update(routeData);
    } else {
      await FirebaseFirestore.instance.collection('savedRoutes').add(routeData);
    }
  }

  Widget _buildStationsTab() {
    if (_isLoadingStations) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.pinkAccent),
      );
    } else if (_stations.isEmpty) {
      return const Center(
        child: Text(
          'No saved stations yet.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _stations.length,
      itemBuilder: (context, index) {
        final station = _stations[index];
        final name = station['name'] ?? 'Unnamed';
        final address = station['address'] ?? '';
        final note = station['note'] ?? '';
        final photoUrl = station['photoUrl'];
        final lat = station['lat']?.toDouble();
        final lng = station['lng']?.toDouble();
        final placeId = station['placeId'];
        final phone = station['phoneNumber'];
        final website = station['websiteUrl'];
        final isSelected = _selectedPlaceIds.contains(placeId);

        return GestureDetector(
          onLongPress: () {
            setState(() {
              if (isSelected) {
                _selectedPlaceIds.remove(placeId);
              } else {
                _selectedPlaceIds.add(placeId);
              }
            });
          },
          onTap: () async {
            if (_selectedPlaceIds.isNotEmpty) {
              setState(() {
                if (isSelected) {
                  _selectedPlaceIds.remove(placeId);
                } else {
                  _selectedPlaceIds.add(placeId);
                }
              });
              return;
            }

            final noteController = TextEditingController(text: note);
            await showDialog(
              context: context,
              builder: (_) {
                return Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    color: const Color(0xFFFFF1F4),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Edit Note',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: noteController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'Add note...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Colors.pinkAccent,
                                width: 2,
                              ),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(
                                color: Colors.pinkAccent,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  Navigator.of(context).pop();
                                  await removeStationByPlaceId(placeId);
                                  setState(() {
                                    _stations.removeWhere(
                                      (s) => s['placeId'] == placeId,
                                    );
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Station removed from saved',
                                      ),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red[300],
                                ),
                                child: const Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  Navigator.of(context).pop();
                                  final newNote = noteController.text.trim();
                                  await saveStationToFirestore(
                                    placeId: placeId,
                                    name: name,
                                    address: address,
                                    phoneNumber: phone,
                                    websiteUrl: website,
                                    photoUrl: photoUrl,
                                    lat: lat,
                                    lng: lng,
                                    note: newNote,
                                  );
                                  setState(() {
                                    final index = _stations.indexWhere(
                                      (s) => s['placeId'] == placeId,
                                    );
                                    if (index != -1) {
                                      _stations[index] = {
                                        ..._stations[index],
                                        'note': newNote,
                                      };
                                    }
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Saved station updated'),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue[400],
                                ),
                                child: const Text(
                                  'Edit',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Reminder added (stub)'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.alarm_add,
                            color: Colors.green,
                          ),
                          label: const Text('Add Reminder'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
          child: Stack(
            children: [
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.symmetric(vertical: 8),
                color: isSelected ? Colors.pink[100] : null,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading:
                      photoUrl != null
                          ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              photoUrl,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (context, error, stackTrace) =>
                                      const Icon(Icons.image_not_supported),
                            ),
                          )
                          : const Icon(Icons.train),
                  title: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (address.isNotEmpty) Text(address),
                      if (note.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Note: $note',
                          style: const TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.pink,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (lat != null && lng != null)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: IconButton(
                    icon: Transform.rotate(
                      angle: pi / 2,
                      child: const Icon(
                        Icons.navigation_rounded,
                        color: Colors.blue,
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => MainScaffold(
                                initialIndex: 2,
                                lat: lat,
                                lng: lng,
                              ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRoutesTab() {
    if (_isLoadingRoutes) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.pinkAccent),
      );
    } else if (_routes.isEmpty) {
      return const Center(
        child: Text(
          'No saved routes yet.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _routes.length,
      itemBuilder: (context, index) {
        final route = _routes[index];
        final routeId = route['routeId'] ?? '';
        final fromStation = route['fromStation'] ?? 'Unknown';
        final toStation = route['toStation'] ?? 'Unknown';
        final note = route['note'] ?? '';
        final routeDetails =
            route['routeDetails'] as Map<String, dynamic>? ?? {};
        final routeSteps =
            (route['routeSteps'] as List<dynamic>? ?? [])
                .cast<Map<String, dynamic>>();
        final isSelected = _selectedRouteIds.contains(routeId);

        return GestureDetector(
          onLongPress: () {
            setState(() {
              if (isSelected) {
                _selectedRouteIds.remove(routeId);
              } else {
                _selectedRouteIds.add(routeId);
              }
            });
          },
          onTap: () async {
            if (_selectedRouteIds.isNotEmpty) {
              setState(() {
                if (isSelected) {
                  _selectedRouteIds.remove(routeId);
                } else {
                  _selectedRouteIds.add(routeId);
                }
              });
              return;
            }

            final noteController = TextEditingController(text: note);
            await showDialog(
              context: context,
              builder: (_) {
                return Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    color: const Color(0xFFFFF1F4),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Edit Route Note',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: noteController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'Add note...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Colors.pinkAccent,
                                width: 2,
                              ),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(
                                color: Colors.pinkAccent,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  Navigator.of(context).pop();
                                  await _removeRouteById(routeId);
                                  setState(() {
                                    _routes.removeWhere(
                                      (r) => r['routeId'] == routeId,
                                    );
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Route removed from saved'),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red[300],
                                ),
                                child: const Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  Navigator.of(context).pop();
                                  final newNote = noteController.text.trim();
                                  await _saveRouteToFirestore(
                                    routeId: routeId,
                                    fromStation: fromStation,
                                    toStation: toStation,
                                    routeSteps: routeSteps,
                                    routeDetails: routeDetails,
                                    note: newNote,
                                  );
                                  setState(() {
                                    final index = _routes.indexWhere(
                                      (r) => r['routeId'] == routeId,
                                    );
                                    if (index != -1) {
                                      _routes[index] = {
                                        ..._routes[index],
                                        'note': newNote,
                                      };
                                    }
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Saved route updated'),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue[400],
                                ),
                                child: const Text(
                                  'Edit',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Reminder added (stub)'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.alarm_add,
                            color: Colors.green,
                          ),
                          label: const Text('Add Reminder'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.symmetric(vertical: 8),
            color: isSelected ? Colors.pink[100] : null,
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: const Icon(
                Icons.route,
                color: Colors.pinkAccent,
                size: 30,
              ),
              title: Text(
                '$fromStation → $toStation',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (routeDetails['duration'] != null)
                    Text('Duration: ${routeDetails['duration']}'),
                  if (routeDetails['distance'] != null)
                    Text('Distance: ${routeDetails['distance']}'),
                  if (note.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Note: $note',
                      style: const TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.pink,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF1F4),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF1F4),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.pinkAccent,
          labelColor: Colors.pinkAccent,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(icon: Icon(Icons.train), text: 'Stations'),
            Tab(icon: Icon(Icons.route), text: 'Routes'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildStationsTab(), _buildRoutesTab()],
      ),
    );
  }
}
