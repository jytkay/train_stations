import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:group_assignment/layout/main_scaffold.dart';
import 'package:group_assignment/pages/specific_station.dart';
import 'package:group_assignment/pages/specific_route.dart';
import 'package:group_assignment/dialogs/edit_station_route.dart';
import 'dart:developer' as dev;

class SavedPage extends StatefulWidget {
  final String userId;
  const SavedPage({super.key, required this.userId});

  @override
  State<SavedPage> createState() => _SavedPageState();
}

enum SortOption {
  timeDescending,
  timeAscending,
  nameAZ,
  nameZA,
  duration,
  distance,
}

class _SavedPageState extends State<SavedPage>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _stations = [];
  List<Map<String, dynamic>> _routes = [];
  List<Map<String, dynamic>> _filteredStations = [];
  List<Map<String, dynamic>> _filteredRoutes = [];
  bool _isLoadingStations = true;
  bool _isLoadingRoutes = true;
  late TabController _tabController;

  SortOption _stationSortOption = SortOption.timeDescending;
  SortOption _routeSortOption = SortOption.timeDescending;

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
      _stations = [];
      _filteredStations = [];
    });

    final snapshot = await FirebaseFirestore.instance
        .collection('savedStations')
        .where('userId', isEqualTo: widget.userId)
        .orderBy('savedAt', descending: true)
        .get();

    dev.log('userId' + widget.userId);

    if (snapshot.docs.isEmpty) {
      setState(() {
        _isLoadingStations = false;
      });
      return;
    }

    setState(() {
      _stations = snapshot.docs.map((doc) => doc.data()).toList();
      _filteredStations = List.from(_stations);
      _sortStations();
      _isLoadingStations = false;
    });
  }

  Future<void> _loadRoutes() async {
    setState(() {
      _isLoadingRoutes = true;
      _routes = [];
      _filteredRoutes = [];
    });

    final snapshot = await FirebaseFirestore.instance
        .collection('savedRoutes')
        .where('userId', isEqualTo: widget.userId)
        .orderBy('savedAt', descending: true)
        .get();

    if (snapshot.docs.isEmpty) {
      setState(() {
        _isLoadingRoutes = false;
      });
      return;
    }

    setState(() {
      _routes = snapshot.docs.map((doc) => doc.data()).toList();
      _filteredRoutes = List.from(_routes);
      _sortRoutes();
      _isLoadingRoutes = false;
    });
  }

  void _sortStations() {
    switch (_stationSortOption) {
      case SortOption.timeDescending:
        _filteredStations.sort((a, b) {
          final aTime = a['savedAt'] as Timestamp?;
          final bTime = b['savedAt'] as Timestamp?;
          if (aTime == null || bTime == null) return 0;
          return bTime.compareTo(aTime);
        });
        break;
      case SortOption.timeAscending:
        _filteredStations.sort((a, b) {
          final aTime = a['savedAt'] as Timestamp?;
          final bTime = b['savedAt'] as Timestamp?;
          if (aTime == null || bTime == null) return 0;
          return aTime.compareTo(bTime);
        });
        break;
      case SortOption.nameAZ:
        _filteredStations.sort((a, b) {
          final aName = (a['name'] ?? '').toString().toLowerCase();
          final bName = (b['name'] ?? '').toString().toLowerCase();
          return aName.compareTo(bName);
        });
        break;
      case SortOption.nameZA:
        _filteredStations.sort((a, b) {
          final aName = (a['name'] ?? '').toString().toLowerCase();
          final bName = (b['name'] ?? '').toString().toLowerCase();
          return bName.compareTo(aName);
        });
        break;
      default:
        break;
    }
  }

  void _sortRoutes() {
    switch (_routeSortOption) {
      case SortOption.timeDescending:
        _filteredRoutes.sort((a, b) {
          final aTime = a['savedAt'] as Timestamp?;
          final bTime = b['savedAt'] as Timestamp?;
          if (aTime == null || bTime == null) return 0;
          return bTime.compareTo(aTime);
        });
        break;
      case SortOption.timeAscending:
        _filteredRoutes.sort((a, b) {
          final aTime = a['savedAt'] as Timestamp?;
          final bTime = b['savedAt'] as Timestamp?;
          if (aTime == null || bTime == null) return 0;
          return aTime.compareTo(bTime);
        });
        break;
      case SortOption.nameAZ:
        _filteredRoutes.sort((a, b) {
          final aRoute = '${a['fromStation'] ?? ''} → ${a['toStation'] ?? ''}'.toLowerCase();
          final bRoute = '${b['fromStation'] ?? ''} → ${b['toStation'] ?? ''}'.toLowerCase();
          return aRoute.compareTo(bRoute);
        });
        break;
      case SortOption.nameZA:
        _filteredRoutes.sort((a, b) {
          final aRoute = '${a['fromStation'] ?? ''} → ${a['toStation'] ?? ''}'.toLowerCase();
          final bRoute = '${b['fromStation'] ?? ''} → ${b['toStation'] ?? ''}'.toLowerCase();
          return bRoute.compareTo(aRoute);
        });
        break;
      case SortOption.duration:
        _filteredRoutes.sort((a, b) {
          final aDetails = a['routeDetails'] as Map<String, dynamic>? ?? {};
          final bDetails = b['routeDetails'] as Map<String, dynamic>? ?? {};
          final aDuration = _parseDuration(aDetails['duration']?.toString() ?? '');
          final bDuration = _parseDuration(bDetails['duration']?.toString() ?? '');
          return aDuration.compareTo(bDuration);
        });
        break;
      case SortOption.distance:
        _filteredRoutes.sort((a, b) {
          final aDetails = a['routeDetails'] as Map<String, dynamic>? ?? {};
          final bDetails = b['routeDetails'] as Map<String, dynamic>? ?? {};
          final aDistance = _parseDistance(aDetails['distance']?.toString() ?? '');
          final bDistance = _parseDistance(bDetails['distance']?.toString() ?? '');
          return aDistance.compareTo(bDistance);
        });
        break;
    }
  }

  int _parseDuration(String duration) {
    int totalMinutes = 0;
    final hourMatch = RegExp(r'(\d+)\s*hours?').firstMatch(duration);
    final minuteMatch = RegExp(r'(\d+)\s*mins?').firstMatch(duration);

    if (hourMatch != null) {
      totalMinutes += int.parse(hourMatch.group(1)!) * 60;
    }
    if (minuteMatch != null) {
      totalMinutes += int.parse(minuteMatch.group(1)!);
    }

    return totalMinutes;
  }

  double _parseDistance(String distance) {
    // Parse distance string like "15.5 km" to kilometers
    final match = RegExp(r'(\d+\.?\d*)\s*km').firstMatch(distance);
    if (match != null) {
      return double.parse(match.group(1)!);
    }
    return 0.0;
  }

  void _showStationSortDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFFF1F4),
          title: const Text('Sort Stations By'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSortOption(
                title: 'Time Added (Latest First)',
                icon: Icons.keyboard_arrow_down,
                isSelected: _stationSortOption == SortOption.timeDescending,
                onTap: () {
                  setState(() {
                    _stationSortOption = SortOption.timeDescending;
                    _sortStations();
                  });
                  Navigator.pop(context);
                },
              ),
              _buildSortOption(
                title: 'Time Added (Oldest First)',
                icon: Icons.keyboard_arrow_up,
                isSelected: _stationSortOption == SortOption.timeAscending,
                onTap: () {
                  setState(() {
                    _stationSortOption = SortOption.timeAscending;
                    _sortStations();
                  });
                  Navigator.pop(context);
                },
              ),
              _buildSortOption(
                title: 'Name (A-Z)',
                icon: Icons.sort_by_alpha,
                isSelected: _stationSortOption == SortOption.nameAZ,
                onTap: () {
                  setState(() {
                    _stationSortOption = SortOption.nameAZ;
                    _sortStations();
                  });
                  Navigator.pop(context);
                },
              ),
              _buildSortOption(
                title: 'Name (Z-A)',
                icon: Icons.sort_by_alpha,
                isSelected: _stationSortOption == SortOption.nameZA,
                onTap: () {
                  setState(() {
                    _stationSortOption = SortOption.nameZA;
                    _sortStations();
                  });
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showRouteSortDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFFF1F4),
          title: const Text('Sort Routes By'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSortOption(
                title: 'Time Added (Latest First)',
                icon: Icons.keyboard_arrow_down,
                isSelected: _routeSortOption == SortOption.timeDescending,
                onTap: () {
                  setState(() {
                    _routeSortOption = SortOption.timeDescending;
                    _sortRoutes();
                  });
                  Navigator.pop(context);
                },
              ),
              _buildSortOption(
                title: 'Time Added (Oldest First)',
                icon: Icons.keyboard_arrow_up,
                isSelected: _routeSortOption == SortOption.timeAscending,
                onTap: () {
                  setState(() {
                    _routeSortOption = SortOption.timeAscending;
                    _sortRoutes();
                  });
                  Navigator.pop(context);
                },
              ),
              _buildSortOption(
                title: 'Route (A-Z)',
                icon: Icons.sort_by_alpha,
                isSelected: _routeSortOption == SortOption.nameAZ,
                onTap: () {
                  setState(() {
                    _routeSortOption = SortOption.nameAZ;
                    _sortRoutes();
                  });
                  Navigator.pop(context);
                },
              ),
              _buildSortOption(
                title: 'Route (Z-A)',
                icon: Icons.sort_by_alpha,
                isSelected: _routeSortOption == SortOption.nameZA,
                onTap: () {
                  setState(() {
                    _routeSortOption = SortOption.nameZA;
                    _sortRoutes();
                  });
                  Navigator.pop(context);
                },
              ),
              _buildSortOption(
                title: 'Duration',
                icon: Icons.access_time,
                isSelected: _routeSortOption == SortOption.duration,
                onTap: () {
                  setState(() {
                    _routeSortOption = SortOption.duration;
                    _sortRoutes();
                  });
                  Navigator.pop(context);
                },
              ),
              _buildSortOption(
                title: 'Distance',
                icon: Icons.straighten,
                isSelected: _routeSortOption == SortOption.distance,
                onTap: () {
                  setState(() {
                    _routeSortOption = SortOption.distance;
                    _sortRoutes();
                  });
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSortOption({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Colors.pinkAccent : Colors.grey,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.pinkAccent : Colors.black,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check, color: Colors.pinkAccent)
          : null,
      onTap: onTap,
    );
  }

  Widget _buildStationsTab() {
    if (_isLoadingStations) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.pinkAccent),
      );
    }
    if (_filteredStations.isEmpty) {
      return const Center(
        child: Text(
          'No saved stations yet.\nLong press a station to save!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _filteredStations.length,
      itemBuilder: (context, index) {
        final station = _filteredStations[index];
        final name = station['name'] ?? 'Unnamed';
        final address = station['address'] ?? '';
        final note = station['note'] ?? '';
        final photoUrl = station['photoUrl'];
        final lat = station['lat']?.toDouble();
        final lng = station['lng']?.toDouble();
        final placeId = station['placeId'];
        final phone = station['phoneNumber'];
        final website = station['websiteUrl'];

        //dev.log("SpecificStationPage station: $station");

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SpecificStationPage(station: station),
              ),
            );
          },
          onLongPress: () async {
            final result = await showEditStationBottomSheet(
              userId: widget.userId,
              context: context,
              station: {
                'place_id': placeId,
                'name': name,
                'formatted_address': address,
                'formatted_phone_number': phone,
                'website': website,
                'photoUrl': photoUrl,
                'geometry': {
                  'location': {'lat': lat, 'lng': lng}
                },
              },
            );

            if (result == true) {
              _loadStations();
            }
          },
          child: Stack(
            children: [
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: photoUrl != null
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      photoUrl,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
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
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.sticky_note_2_outlined,
                                size: 18, color: Colors.pinkAccent),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                note,
                                style: const TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color: Colors.pink,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
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
                          builder: (_) => MainScaffold(
                            userId: widget.userId,
                            initialIndex: 2,
                            lat: lat,
                            lng: lng,
                            address: address,
                            photoUrl: photoUrl,
                            name: name,
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
    }
    if (_filteredRoutes.isEmpty) {
      return const Center(
        child: Text(
          'No saved routes yet.\nLook up a route and long press it to save!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _filteredRoutes.length,
      itemBuilder: (context, index) {
        final route = _filteredRoutes[index];
        final routeId = route['routeId'] ?? '';
        final fromStation = route['fromStation'] ?? 'Unknown';
        final toStation = route['toStation'] ?? 'Unknown';
        final note = route['note'] ?? '';
        final routeDetails = (route['routeDetails'] as Map<String, dynamic>? ?? {});
        final routeSteps = (route['routeSteps'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

        final selectedDay = route['selectedDepartureDay'] as DateTime?;
        final selectedRange = route['selectedTimeRange']    as String? ?? '';

        final departureTime = routeDetails['departureTime']?.toString() ?? '';
        final arrivalTime = routeDetails['arrivalTime']?.toString() ?? '';
        final duration = routeDetails['duration']?.toString() ?? '';
        final distance = routeDetails['distance']?.toString() ?? '';
        final numberOfStops = routeSteps.length.toString();

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SpecificRoutePage(route: route),
              ),
            );
          },
          onLongPress: () async {
            final result = await showEditRouteBottomSheet(
              userId: widget.userId,
              context: context,
              routeId: routeId,
              routeDetailsRaw: route['routeDetailsRaw'] as Map<String, dynamic>? ?? {},
              routeSteps: routeSteps,
              fromStation: fromStation,
              toStation: toStation,
              selectedDepartureDay: selectedDay,
              selectedTimeRange: selectedRange,
            );

            if (result == true) {
              _loadRoutes();
            }
          },
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: const Icon(Icons.route, color: Colors.pinkAccent, size: 30),
              title: Text(
                '$fromStation → $toStation',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (departureTime.isNotEmpty && arrivalTime.isNotEmpty)
                    Text('$departureTime → $arrivalTime'),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (duration.isNotEmpty) ...[
                        Text(duration),
                        if (distance.isNotEmpty || numberOfStops != '0')
                          const Text(' • '),
                      ],
                      if (distance.isNotEmpty) ...[
                        Text(distance),
                        if (numberOfStops != '0') const Text(' • '),
                      ],
                      if (routeSteps.length == 1)
                        const Text('Direct Route')
                      else if (routeSteps.length == 2)
                        const Text('1 transfer')
                      else
                        Text('${routeSteps.length - 1} transfers'),
                    ],
                  ),
                  if (note.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.sticky_note_2_outlined,
                            size: 18, color: Colors.pinkAccent),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            note,
                            style: const TextStyle(
                              fontStyle: FontStyle.italic,
                              color: Colors.pink,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
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
        actions: [
          IconButton(
            icon: const Icon(
              Icons.filter_list,
              color: Colors.pinkAccent,
            ),
            onPressed: () {
              if (_tabController.index == 0) {
                _showStationSortDialog();
              } else {
                _showRouteSortDialog();
              }
            },
          ),
        ],
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