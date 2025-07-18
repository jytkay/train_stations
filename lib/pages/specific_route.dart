import 'package:flutter/material.dart';
import 'dart:developer' as dev;

class SpecificRoutePage extends StatefulWidget {
  final Map<String, dynamic> route;

  const SpecificRoutePage({
    super.key,
    required this.route,
  });

  @override
  State<SpecificRoutePage> createState() => _SpecificRoutePageState();
}

class _SpecificRoutePageState extends State<SpecificRoutePage> {
  late Map<String, dynamic> _route;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _route = widget.route;
    dev.log("SpecificRoutePage route: $_route");
  }

  Widget _buildRouteHeader() {
    final fromStation = _route['fromStation'] ?? 'Unknown';
    final toStation = _route['toStation'] ?? 'Unknown';
    final routeDetails = (_route['routeDetails'] as Map<String, dynamic>? ?? {});
    final departureTime = routeDetails['departureTime']?.toString() ?? '';
    final arrivalTime = routeDetails['arrivalTime']?.toString() ?? '';
    final duration = routeDetails['duration']?.toString() ?? '';
    final distance = routeDetails['distance']?.toString() ?? '';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.route, color: Colors.pinkAccent, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '$fromStation → $toStation',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (departureTime.isNotEmpty && arrivalTime.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.access_time, color: Colors.grey, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '$departureTime → $arrivalTime',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                if (duration.isNotEmpty) ...[
                  const Icon(Icons.timer, color: Colors.grey, size: 20),
                  const SizedBox(width: 8),
                  Text(duration),
                  if (distance.isNotEmpty) const Text(' • '),
                ],
                if (distance.isNotEmpty) ...[
                  const Icon(Icons.straighten, color: Colors.grey, size: 20),
                  const SizedBox(width: 8),
                  Text(distance),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteNote() {
    final note = _route['note'] ?? '';
    if (note.isEmpty) return const SizedBox.shrink();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.sticky_note_2_outlined,
                color: Colors.pinkAccent, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Note',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    note,
                    style: const TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.pink,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteSteps() {
    final routeSteps = (_route['routeSteps'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    // Debug logging
    dev.log("Route steps length: ${routeSteps.length}");
    dev.log("Route steps data: $routeSteps");
    dev.log("Full route data keys: ${_route.keys.toList()}");

    if (routeSteps.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'No route steps available',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Available keys: ${_route.keys.toList()}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.list, color: Colors.pinkAccent, size: 24),
                const SizedBox(width: 12),
                const Text(
                  'Route Steps',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: routeSteps.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final step = routeSteps[index];
                final departure = step['departure']?.toString() ?? '';
                final arrival = step['arrival']?.toString() ?? '';
                final line = step['line']?.toString() ?? '';
                final departureTime = step['departureTime']?.toString() ?? '';
                final arrivalTime = step['arrivalTime']?.toString() ?? '';
                final numStops = step['numStops']?.toString() ?? '';

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.pinkAccent,
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (line.isNotEmpty)
                              Text(
                                line,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            if (departure.isNotEmpty && arrival.isNotEmpty)
                              Text(
                                '$departure → $arrival',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            if (departureTime.isNotEmpty && arrivalTime.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.access_time, size: 16, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$departureTime → $arrivalTime',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (numStops.isNotEmpty && numStops != '0') ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.train, size: 16, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$numStops stops',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF1F4),
      appBar: AppBar(
        backgroundColor: Colors.pink.shade300,
        elevation: 0,
        title: const Text(
          'Route Details',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        // actions: [
        //   IconButton(
        //     icon: const Icon(Icons.delete, color: Colors.white),
        //     onPressed: _showDeleteDialog,
        //   ),
        // ],
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(color: Colors.pinkAccent),
      )
          : SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRouteHeader(),
            _buildRouteNote(),
            _buildRouteSteps(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}