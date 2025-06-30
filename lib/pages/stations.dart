import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:group_assignment/api/google_api_key.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:group_assignment/pages/specific_station.dart';
import 'package:group_assignment/layout/main_scaffold.dart';
import 'package:group_assignment/firestore/save_stations.dart';
import 'dart:math';

class StationsPage extends StatefulWidget {
  const StationsPage({super.key});

  @override
  State<StationsPage> createState() => _StationsPageState();
}

class _StationsPageState extends State<StationsPage> {
  bool _isSwapped = false;
  bool _isLoading = false;
  bool _isRouteLoading = false;
  List<Map<String, String>> _routeSteps = [];
  List<dynamic> _routeOptions = []; // all routes from API
  int _selectedRouteIndex = -1; // selected route index
  final _controller = TextEditingController();
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  final _departureTimeController = TextEditingController();
  DateTime? _selectedDepartureTime;
  List<dynamic> _routeStations = [];
  bool _isRouteStationsLoading = false;
  List<dynamic> _stations = [];
  String? _nextPageToken;
  String _currentQuery = 'train station UK'; // Track current search query
  final cardColor = Colors.pink.shade100;
  final activePink = Colors.pink.shade700;
  final List<String> _timeRanges = [
    'Any depart time',
    'Early morning (5:00-8:00)',
    'Morning (8:00-12:00)',
    'Afternoon (12:00-17:00)',
    'Evening (17:00-21:00)',
    'Late evening (21:00-24:00)',
  ];
  String _selectedTimeRange = 'Any depart time';

  bool _isRouteInTimeRange(Map<String, dynamic> route) {
    if (_selectedTimeRange == 'Any depart time') return true;

    final leg = route['legs'][0];
    final departureTimeText = leg['departure_time']?['text'];

    if (departureTimeText == null) return false;

    // Parse the time from the departure time text (e.g., "6:01 PM")
    final timeMatch = RegExp(
      r'(\d{1,2}):(\d{2})\s*(AM|PM)',
    ).firstMatch(departureTimeText);
    if (timeMatch == null) return false;

    final hour = int.parse(timeMatch.group(1)!);
    final period = timeMatch.group(3)!;

    // Convert to 24-hour format
    int hour24 = hour;
    if (period == 'PM' && hour != 12) {
      hour24 += 12;
    } else if (period == 'AM' && hour == 12) {
      hour24 = 0;
    }

    // Check if the time falls within the selected range
    switch (_selectedTimeRange) {
      case 'Early morning (5:00-8:00)':
        return hour24 >= 5 && hour24 < 8;
      case 'Morning (8:00-12:00)':
        return hour24 >= 8 && hour24 < 12;
      case 'Afternoon (12:00-17:00)':
        return hour24 >= 12 && hour24 < 17;
      case 'Evening (17:00-21:00)':
        return hour24 >= 17 && hour24 < 21;
      case 'Late evening (21:00-24:00)':
        return hour24 >= 21 && hour24 < 24;
      default:
        return true;
    }
  }

  @override
  void initState() {
    super.initState();
    searchStations('train station UK', isInitialLoad: true);
  }

  String? _getPhotoUrl(String? photoRef) {
    if (photoRef == null) return null;
    return 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=150&photoreference=$photoRef&key=$googleApiKey';
  }

  Future<void> searchStations(
    String query, {
    bool isInitialLoad = false,
    bool loadMore = false,
  }) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      if (!loadMore) {
        _stations = [];
        _nextPageToken = null;
        // Update current query only when it's a new search (not load more)
        _currentQuery =
            isInitialLoad ? 'train station UK' : '$query train station UK';
      }
    });

    try {
      final apiKey = googleApiKey;
      String url;

      if (loadMore && _nextPageToken != null) {
        url =
            'https://maps.googleapis.com/maps/api/place/textsearch/json?pagetoken=$_nextPageToken&key=$apiKey';
      } else {
        String searchQuery = _currentQuery;

        url =
            'https://maps.googleapis.com/maps/api/place/textsearch/json?query=${Uri.encodeComponent(searchQuery)}&type=transit_station&key=$apiKey';
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        Set<String> seenPlaceIds = {}; // Changed from seenAddresses
        List<dynamic> detailedStations = [];

        for (var station in (data['results'] ?? [])) {
          if (station['types'] != null &&
              station['types'].contains('transit_station')) {
            final placeId = station['place_id'];

            // Skip if no place_id or already seen
            if (placeId == null || seenPlaceIds.contains(placeId)) {
              continue;
            }

            final detailedStation = await getPlaceDetails(placeId);

            final merged = {
              ...station,
              if (detailedStation != null) ...detailedStation,
              'place_id': placeId,
            };

            seenPlaceIds.add(placeId);
            detailedStations.add(merged);
          }
        }

        setState(() {
          if (loadMore) {
            _stations.addAll(detailedStations);
          } else {
            _stations = detailedStations;
          }
          _nextPageToken = data['next_page_token'];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to fetch data from Google API'),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<dynamic> getPlaceDetails(String placeId) async {
    try {
      final fields =
          'name,formatted_address,formatted_phone_number,website,photos';
      final url =
          'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=$fields&key=$googleApiKey';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['result'];
      }
    } catch (_) {}
    return null;
  }

  Future<void> loadMoreStations() async {
    if (_nextPageToken != null && !_isLoading) {
      await Future.delayed(const Duration(seconds: 2));
      await searchStations('', loadMore: true);
    }
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not launch $url')));
      }
    }
  }

  Widget buildSwapButton() {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          buildIconButton(Icons.swap_horiz, () {
            setState(() {
              _isSwapped = !_isSwapped;
            });
          }),
        ],
      ),
    );
  }

  Widget buildSearchStation() {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: buildSearchField(_controller, 'Search stations...'),
    );
  }

  Widget buildSearchRoute() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildSearchField(_fromController, 'From'),
        const SizedBox(height: 8),
        buildSearchField(_toController, 'To'),
        const SizedBox(height: 8),
        buildDateTimeSelector(),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget buildSearchField(TextEditingController controller, String hint) {
    IconData getIconForHint(String hint) {
      if (hint == 'From') return Icons.my_location;
      if (hint == 'To') return Icons.location_on;
      return Icons.search;
    }

    return TextField(
      controller: controller,
      onSubmitted: (value) {
        if (value.trim().isNotEmpty) {
          if (!_isSwapped) {
            searchStations(value.trim());
          }
        }
      },
      onChanged: (value) {
        // Auto-trigger route search when both fields are filled in swapped mode
        if (_isSwapped) {
          final fromStation = _fromController.text.trim();
          final toStation = _toController.text.trim();
          if (fromStation.isNotEmpty && toStation.isNotEmpty) {
            fetchTransitRoute(
              fromStation,
              toStation,
              departureTime: _selectedDepartureTime,
            );
          }
        }
      },
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(getIconForHint(hint)),
        suffixIcon:
            controller.text.isNotEmpty
                ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    controller.clear();
                    if (!_isSwapped) {
                      searchStations('train station UK', isInitialLoad: true);
                    } else {
                      // Clear routes when clearing route fields
                      setState(() {
                        _routeOptions = [];
                        _routeSteps = [];
                        _selectedRouteIndex = -1;
                      });
                    }
                  },
                )
                : null,
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cardColor, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: activePink, width: 2),
        ),
      ),
    );
  }

  Future<void> fetchTransitRoute(
    String from,
    String to, {
    DateTime? departureTime,
  }) async {
    setState(() {
      _isRouteLoading = true;
      _routeSteps = [];
      _routeOptions = [];
      _selectedRouteIndex = -1;
    });

    final encodedFrom = Uri.encodeComponent(from);
    final encodedTo = Uri.encodeComponent(to);

    // Use provided departure time or current time
    DateTime depTime = departureTime ?? DateTime.now();

    // Apply time range if not "Any depart time"
    if (_selectedTimeRange != 'Any depart time') {
      final selectedDate = DateTime(depTime.year, depTime.month, depTime.day);

      switch (_selectedTimeRange) {
        case 'Early morning (5:00-8:00)':
          depTime = selectedDate.add(const Duration(hours: 5));
          break;
        case 'Morning (8:00-12:00)':
          depTime = selectedDate.add(const Duration(hours: 8));
          break;
        case 'Afternoon (12:00-17:00)':
          depTime = selectedDate.add(const Duration(hours: 12));
          break;
        case 'Evening (17:00-21:00)':
          depTime = selectedDate.add(const Duration(hours: 17));
          break;
        case 'Late evening (21:00-24:00)':
          depTime = selectedDate.add(const Duration(hours: 21));
          break;
      }
    } else {
      // If "Any depart time" is selected, use the current departure time or now
      depTime = departureTime ?? DateTime.now();
    }

    final departureTimeSeconds = depTime.millisecondsSinceEpoch ~/ 1000;

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json'
      '?origin=$encodedFrom'
      '&destination=$encodedTo'
      '&mode=transit'
      '&departure_time=$departureTimeSeconds'
      '&alternatives=true'
      '&avoid=tolls'
      '&transit_mode=train|subway|tram|rail'
      '&key=$googleApiKey',
    );

    try {
      final response = await http.get(url);
      final data = json.decode(response.body);

      if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
        // Filter routes to only include train/rail routes
        // Filter routes to only include train/rail routes
        List<dynamic> trainRoutes = [];

        for (var route in data['routes']) {
          bool hasTrainTransit = false;
          final steps = route['legs'][0]['steps'] as List;

          for (var step in steps) {
            if (step['travel_mode'] == 'TRANSIT' &&
                step['transit_details'] != null) {
              final transitDetails = step['transit_details'];
              final vehicleType = transitDetails['line']?['vehicle']?['type'];

              // Check if it's a train/rail type
              if (vehicleType != null &&
                  (vehicleType.toString().toLowerCase().contains('train') ||
                      vehicleType.toString().toLowerCase().contains('rail') ||
                      vehicleType.toString().toLowerCase().contains('subway') ||
                      vehicleType.toString().toLowerCase().contains('metro') ||
                      vehicleType.toString().toLowerCase().contains('tram'))) {
                hasTrainTransit = true;
                break;
              }
            }
          }

          // Only add routes that have train transit AND match the time range
          if (hasTrainTransit && _isRouteInTimeRange(route)) {
            trainRoutes.add(route);
          }
        }

        setState(() {
          _routeOptions = trainRoutes;
          _selectedRouteIndex = -1;
          _routeSteps = [];
          _isRouteLoading =
              false; // Set loading to false here when we have results
        });
      } else {
        setState(() {
          _routeOptions = [];
          _routeSteps = [];
        });
      }
    } catch (e) {
      setState(() {
        _routeOptions = [];
        _routeSteps = [];
        _isRouteLoading = false; // Set loading to false here on error
      });
    }
  }

  Widget buildDateTimeSelector() {
    return Row(
      children: [
        // Date selector
        Expanded(
          child: InkWell(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _selectedDepartureTime ?? DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (date != null) {
                setState(() {
                  _selectedDepartureTime = DateTime(
                    date.year,
                    date.month,
                    date.day,
                    _selectedDepartureTime?.hour ?? DateTime.now().hour,
                    _selectedDepartureTime?.minute ?? DateTime.now().minute,
                  );
                });
                // Trigger route search if both fields are filled
                final fromStation = _fromController.text.trim();
                final toStation = _toController.text.trim();
                if (fromStation.isNotEmpty && toStation.isNotEmpty) {
                  fetchTransitRoute(
                    fromStation,
                    toStation,
                    departureTime: _selectedDepartureTime,
                  );
                }
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              decoration: BoxDecoration(
                border: Border.all(color: cardColor),
                borderRadius: BorderRadius.circular(10),
                color: Colors.white,
              ),
              child: Text(
                _selectedDepartureTime != null
                    ? '${_selectedDepartureTime!.day}/${_selectedDepartureTime!.month}/${_selectedDepartureTime!.year}'
                    : 'Today',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Time range selector
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: cardColor),
              borderRadius: BorderRadius.circular(10),
              color: Colors.white,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedTimeRange,
                isExpanded: true,
                items:
                    _timeRanges.map((range) {
                      return DropdownMenuItem<String>(
                        value: range,
                        child: Text(
                          range,
                          style: const TextStyle(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedTimeRange = value;
                    });
                    // Trigger route search if both fields are filled
                    final fromStation = _fromController.text.trim();
                    final toStation = _toController.text.trim();
                    if (fromStation.isNotEmpty && toStation.isNotEmpty) {
                      fetchTransitRoute(
                        fromStation,
                        toStation,
                        departureTime: _selectedDepartureTime,
                      );
                    }
                  }
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildRouteSelector() {
    if (_isRouteLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 8),
              Text('Searching for train routes...'),
            ],
          ),
        ),
      );
    }

    if (_isRouteLoading && _routeOptions.isNotEmpty) {
      _isRouteLoading = false;
    }

    // Only show "no results" if we've actually searched and found nothing
    if (_routeOptions.isEmpty &&
        !_isRouteLoading &&
        (_fromController.text.isNotEmpty && _toController.text.isNotEmpty)) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.train, size: 48, color: Colors.grey),
              SizedBox(height: 8),
              Text(
                'No train routes found',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    // Don't show anything if user hasn't filled both fields yet
    if (_routeOptions.isEmpty) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Text(
                'Available Train Routes',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: activePink,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Divider(thickness: 1, color: activePink),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: cardColor),
            borderRadius: BorderRadius.circular(10),
            color: Colors.white,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _selectedRouteIndex >= 0 ? _selectedRouteIndex : null,
              hint: const Text('Select a route to view details'),
              isExpanded: true,
              items:
                  _routeOptions.asMap().entries.map((entry) {
                    final index = entry.key;
                    final route = entry.value;
                    final leg = route['legs'][0];
                    final steps = leg['steps'] as List;

                    final transitSteps =
                        steps
                            .where((step) => step['travel_mode'] == 'TRANSIT')
                            .toList();

                    final lineName =
                        transitSteps.isNotEmpty
                            ? transitSteps
                                    .first['transit_details']['line']['short_name'] ??
                                transitSteps
                                    .first['transit_details']['line']['name'] ??
                                'Unknown line'
                            : 'Unknown line';

                    final duration =
                        leg['duration']?['text'] ?? 'Unknown duration';
                    final distance =
                        leg['distance']?['text'] ?? 'Unknown distance';
                    final departureTime = leg['departure_time']?['text'] ?? '';
                    final arrivalTime = leg['arrival_time']?['text'] ?? '';
                    final transfers =
                        transitSteps.length > 1 ? transitSteps.length - 1 : 0;

                    return DropdownMenuItem<int>(
                      value: index,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.grey.shade300,
                              width: index < _routeOptions.length - 1 ? 1 : 0,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text.rich(
                              TextSpan(
                                text: '$lineName: ',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                children: [
                                  TextSpan(
                                    text: '$duration • $distance',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$departureTime → $arrivalTime • '
                              '${transfers == 0 ? 'Direct route' : '$transfers transfer${transfers == 1 ? '' : 's'}'}',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
              onChanged: (index) {
                if (index != null) {
                  _selectRoute(index);
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_routeSteps.isNotEmpty) buildRouteSteps(),
      ],
    );
  }

  void _selectRoute(int index) {
    final steps = _routeOptions[index]['legs'][0]['steps'];

    final transitSteps =
        steps
            .where(
              (step) =>
                  step['travel_mode'] == 'TRANSIT' &&
                  step['transit_details'] != null,
            )
            .map<Map<String, String>>((step) {
              final details = step['transit_details'];
              final line = details['line'];
              return {
                'line':
                    (line['short_name'] ?? line['name'] ?? 'Unknown line')
                        .toString(),
                'departure':
                    (details['departure_stop']?['name'] ?? 'Unknown')
                        .toString(),
                'arrival':
                    (details['arrival_stop']?['name'] ?? 'Unknown').toString(),
                'numStops': (details['num_stops']?.toString() ?? '?'),
                'departureTime':
                    (details['departure_time']?['text'] ?? '-').toString(),
                'arrivalTime':
                    (details['arrival_time']?['text'] ?? '-').toString(),
              };
            })
            .toList();

    setState(() {
      _selectedRouteIndex = index;
      _routeSteps = transitSteps;
      _routeStations = []; // Clear previous stations
      _isRouteStationsLoading = true; // Start loading
    });

    // Fetch detailed station information
    _getDetailedRouteStations().then((detailedStations) {
      setState(() {
        _routeStations = detailedStations;
        _isRouteStationsLoading = false;
      });
    });
  }

  Widget buildRouteSteps() {
    if (_routeSteps.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: cardColor),
            borderRadius: BorderRadius.circular(10),
            color: cardColor.withOpacity(0.5),
          ),
          child: Column(
            children:
                _routeSteps.asMap().entries.map((entry) {
                  final step = entry.value;

                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            text: '🚆 ${step['line']}: ',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            children: [
                              TextSpan(
                                text: () {
                                  final numStops =
                                      int.tryParse('${step['numStops']}') ?? 0;
                                  return '$numStops stop${numStops > 1 ? 's' : ''}';
                                }(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${step['departure']} → ${step['arrival']}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[700],
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        Text(
                          '${step['departureTime']} → ${step['arrivalTime']}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
          ),
        ),
      ],
    );
  }

  List<dynamic> _getStationsFromRoute() {
    if (_selectedRouteIndex == -1 || _routeOptions.isEmpty) return [];

    final route = _routeOptions[_selectedRouteIndex];
    final steps = route['legs'][0]['steps'] as List;
    List<dynamic> stations = [];

    for (var step in steps) {
      if (step['travel_mode'] == 'TRANSIT' && step['transit_details'] != null) {
        final details = step['transit_details'];

        // Add departure stop
        if (details['departure_stop'] != null) {
          stations.add({
            'name': details['departure_stop']['name'],
            'formatted_address': details['departure_stop']['name'],
            'place_id': 'route_stop_${stations.length}',
            'geometry':
                details['departure_stop']['location'] != null
                    ? {'location': details['departure_stop']['location']}
                    : null,
          });
        }

        // Add arrival stop
        if (details['arrival_stop'] != null) {
          stations.add({
            'name': details['arrival_stop']['name'],
            'formatted_address': details['arrival_stop']['name'],
            'place_id': 'route_stop_${stations.length}',
            'geometry':
                details['arrival_stop']['location'] != null
                    ? {'location': details['arrival_stop']['location']}
                    : null,
          });
        }
      }
    }

    // Remove duplicates based on name
    final seen = <String>{};
    return stations.where((station) {
      final name = station['name'] as String;
      return seen.add(name);
    }).toList();
  }

  Future<List<dynamic>> _getDetailedRouteStations() async {
    final routeStations = _getStationsFromRoute();
    List<dynamic> detailedStations = [];
    Set<String> seenPlaceIds = {}; // Add place_id deduplication

    for (var station in routeStations) {
      final stationName = station['name'];
      if (stationName != null) {
        try {
          final searchQuery = '$stationName train station UK';
          final url =
              'https://maps.googleapis.com/maps/api/place/textsearch/json?query=${Uri.encodeComponent(searchQuery)}&type=transit_station&key=$googleApiKey';

          final response = await http.get(Uri.parse(url));
          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            final results = data['results'] as List;

            if (results.isNotEmpty) {
              final base = results[0];
              final placeId = base['place_id'];

              // Skip if we've already seen this place_id
              if (placeId != null && seenPlaceIds.contains(placeId)) {
                continue;
              }

              final detailed =
                  placeId != null ? await getPlaceDetails(placeId) : null;

              final merged = {
                ...base,
                if (detailed != null) ...detailed,
                'place_id': placeId,
              };

              if (placeId != null) {
                seenPlaceIds.add(placeId);
              }
              detailedStations.add(merged);
            } else {
              // Fallback to input station (no detailed info found)
              detailedStations.add(station);
            }
          }
        } catch (e) {
          detailedStations.add(station); // fallback on error
        }
      }
    }

    return detailedStations;
  }

  Widget buildIconButton(IconData icon, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(icon: Icon(icon), onPressed: onPressed),
    );
  }

  Widget buildStationCard(dynamic station) {
    final placeId = station['place_id'];
    final name = station['name'];
    final address = station['formatted_address'] ?? 'No address available';
    final phone = station['formatted_phone_number'];
    final website = station['website'];

    final photoRef =
        (station['photos'] != null && station['photos'].isNotEmpty)
            ? station['photos'][0]['photo_reference']
            : null;
    final photoUrl = _getPhotoUrl(photoRef);

    final lat = station['geometry']?['location']?['lat'];
    final lng = station['geometry']?['location']?['lng'];

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
        final alreadySaved = await isStationSaved(placeId);
        final hasReminder = false; // Stub

        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          builder: (BuildContext context) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Save / Edit Saved Station
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: Icon(
                      alreadySaved ? Icons.edit : Icons.bookmark_add,
                      color: alreadySaved ? Colors.blue : Colors.green,
                    ),
                    title: Text(
                      alreadySaved ? 'Edit Saved Station' : 'Save Station',
                      style: TextStyle(
                        color: alreadySaved ? Colors.blue : Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final parentContext = context;

                      final TextEditingController _noteController =
                          TextEditingController();

                      if (alreadySaved) {
                        final existing = await getSavedStationByPlaceId(
                          placeId,
                        );
                        _noteController.text = existing?['note'] ?? '';
                      }

                      // Show dialog first
                      await showDialog(
                        context: parentContext,
                        builder: (BuildContext context) {
                          return Dialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF1F4),
                                // Light pink background
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    alreadySaved ? 'Edit Note' : 'Add Note',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _noteController,
                                    maxLines: 3,
                                    decoration: InputDecoration(
                                      hintText: 'Add note...',
                                      enabledBorder: OutlineInputBorder(
                                        borderSide: const BorderSide(
                                          color: Color(
                                            0xFFF06292,
                                          ), // Active pink border
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderSide: const BorderSide(
                                          color: Color(0xFFF06292),
                                          // Active pink border
                                          width: 2,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Row(
                                    children: [
                                      if (alreadySaved)
                                        Expanded(
                                          child: ElevatedButton(
                                            onPressed: () async {
                                              Navigator.of(context).pop();
                                              await removeStationByPlaceId(
                                                placeId,
                                              );
                                              messenger.showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Station removed from saved',
                                                  ),
                                                  behavior:
                                                      SnackBarBehavior.floating,
                                                ),
                                              );
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(
                                                0xFFFF8A80,
                                              ), // Light red
                                              foregroundColor: Colors.white,
                                            ),
                                            child: const Text('Delete'),
                                          ),
                                        ),
                                      if (alreadySaved)
                                        const SizedBox(width: 12),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () async {
                                            Navigator.of(context).pop();
                                            final note =
                                                _noteController.text.trim();
                                            await saveStationToFirestore(
                                              placeId: placeId,
                                              name: name,
                                              address: address,
                                              phoneNumber: phone,
                                              websiteUrl: website,
                                              lat: lat,
                                              lng: lng,
                                              photoUrl: photoUrl,
                                              note: note,
                                            );
                                            messenger.showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  alreadySaved
                                                      ? 'Saved station updated'
                                                      : (note.isNotEmpty
                                                          ? 'Station saved with note'
                                                          : 'Station saved'),
                                                ),
                                                behavior:
                                                    SnackBarBehavior.floating,
                                              ),
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                alreadySaved
                                                    ? const Color(
                                                      0xFF64B5F6,
                                                    ) // Light blue
                                                    : const Color(0xFFF48FB1),
                                            // Light pink
                                            foregroundColor: Colors.white,
                                          ),
                                          child: Text(
                                            alreadySaved ? 'Edit' : 'Save',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );

                      // Now it's safe to pop the bottom sheet
                      Navigator.pop(parentContext);
                    },
                  ),
                ),

                // Reminder stub
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: Icon(
                      hasReminder ? Icons.alarm_off : Icons.alarm_add,
                      color: hasReminder ? Colors.red : Colors.green,
                    ),
                    title: Text(
                      hasReminder ? 'Remove Reminder' : 'Add Reminder',
                      style: TextStyle(
                        color: hasReminder ? Colors.red : Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            hasReminder ? 'Reminder removed' : 'Reminder added',
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
      child: Stack(
        children: [
          Card(
            color: cardColor,
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                          color: Colors.grey.shade50,
                        ),
                        child:
                            photoUrl != null
                                ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    photoUrl,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (
                                      context,
                                      child,
                                      loadingProgress,
                                    ) {
                                      if (loadingProgress == null) return child;
                                      return Center(
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: activePink,
                                          ),
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          gradient: LinearGradient(
                                            colors: [
                                              activePink.withOpacity(0.1),
                                              cardColor,
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.train,
                                          size: 40,
                                          color: activePink.withOpacity(0.7),
                                        ),
                                      );
                                    },
                                  ),
                                )
                                : Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    gradient: LinearGradient(
                                      colors: [
                                        activePink.withOpacity(0.1),
                                        cardColor,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.train,
                                    size: 40,
                                    color: activePink.withOpacity(0.7),
                                  ),
                                ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              address,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                if (phone != null) ...[
                                  InkWell(
                                    onTap: () => _launchUrl('tel:$phone'),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.phone,
                                            size: 12,
                                            color: Colors.green.shade700,
                                          ),
                                          const SizedBox(width: 2),
                                          Text(
                                            'Call',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.green.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                if (website != null) ...[
                                  InkWell(
                                    onTap: () => _launchUrl(website),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.web,
                                            size: 12,
                                            color: Colors.blue.shade700,
                                          ),
                                          const SizedBox(width: 2),
                                          Text(
                                            'Website',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.blue.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: IconButton(
              icon: Transform.rotate(
                angle: pi / 2, // 90 degrees clockwise
                child: const Icon(Icons.navigation_rounded, color: Colors.blue),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MainScaffold(
                      initialIndex: 2,
                      lat: lat,
                      lng: lng,
                      name: name,
                      address: address,
                      photoUrl: photoUrl, // Add this line to pass the photo URL
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        buildSwapButton(), // Always fixed at top
        if (!_isSwapped)
          Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: buildSearchStation(),
          ),
        // Scrollable content section
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // Departure time and route selector (scrollable)
                  if (_isSwapped) ...[
                    buildSearchRoute(),
                    buildRouteSelector(),
                    const SizedBox(height: 16),
                  ],
                  // Station results
                  _isSwapped
                      ? (_selectedRouteIndex >= 0
                          ? (_isRouteStationsLoading
                              ? const SizedBox(
                                height: 200,
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircularProgressIndicator(),
                                      SizedBox(height: 16),
                                      Text('Loading station details...'),
                                    ],
                                  ),
                                ),
                              )
                              : Column(
                                children:
                                    _routeStations
                                        .map(
                                          (station) =>
                                              buildStationCard(station),
                                        )
                                        .toList(),
                              ))
                          : (_fromController.text.isNotEmpty &&
                                  _toController.text.isNotEmpty
                              ? const SizedBox(
                                height: 200,
                              ) // Nothing while loading
                              : const SizedBox(
                                height: 200,
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.route,
                                        size: 64,
                                        color: Colors.grey,
                                      ),
                                      SizedBox(height: 16),
                                      Text(
                                        'Start searching for station routes',
                                      ),
                                    ],
                                  ),
                                ),
                              )))
                      : // When not swapped, show regular station search results
                      (_isLoading && _stations.isEmpty
                          ? const SizedBox(
                            height: 200,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 16),
                                  Text('Loading train stations...'),
                                ],
                              ),
                            ),
                          )
                          : _stations.isEmpty
                          ? const SizedBox(
                            height: 200,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.train,
                                    size: 64,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 16),
                                  Text('No train stations found.'),
                                ],
                              ),
                            ),
                          )
                          : Column(
                            children: [
                              ..._stations.map(
                                (station) => buildStationCard(station),
                              ),
                              if (_nextPageToken != null) ...[
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed:
                                      _isLoading ? null : loadMoreStations,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: activePink,
                                    foregroundColor: Colors.white,
                                  ),
                                  child:
                                      _isLoading
                                          ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                          : const Text('Load More Stations'),
                                ),
                              ],
                            ],
                          )),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _fromController.dispose();
    _toController.dispose();
    _departureTimeController.dispose(); // Add this line
    super.dispose();
  }
}
