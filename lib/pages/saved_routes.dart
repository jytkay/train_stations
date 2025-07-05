import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:group_assignment/model/route_details_class.dart';
import 'package:group_assignment/model/route_step_class.dart';

class SavedRoutes extends StatefulWidget {
  const SavedRoutes({super.key});

  @override
  State<SavedRoutes> createState() => _SavedRoutesState();
}

class _SavedRoutesState extends State<SavedRoutes> {
  final String userID = "1000";
  final CollectionReference savedRoutesCollection =
  FirebaseFirestore.instance.collection("savedRoutes");

  bool isLoading = true;
  String? errorMessage;
  List<Map<String, dynamic>> savedRoutes = [];

  @override
  void initState() {
    super.initState();
    _fetchSavedRoutes();
  }

  Future<void> _fetchSavedRoutes() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      // Try ordered query first
      QuerySnapshot querySnapshot;
      try {
        querySnapshot = await savedRoutesCollection
            .where('userID', isEqualTo: userID)
            .orderBy('savedAt', descending: true)
            .get();
      } on FirebaseException catch (e) {
        if (e.code == 'failed-precondition') {
          // Fallback to unordered query if index isn't ready
          debugPrint('Index not ready, using unordered query');
          querySnapshot = await savedRoutesCollection
              .where('userID', isEqualTo: userID)
              .get();
        } else {
          rethrow;
        }
      }

      if (querySnapshot.docs.isEmpty) {
        setState(() {
          savedRoutes = [];
          isLoading = false;
        });
        return;
      }

      // Process documents
      final routes = querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          ...data,
          'id': doc.id,
          'routeSteps': data['routeSteps'] ?? [], // Ensure routeSteps exists
        };
      }).toList();

      // Sort locally by savedAt if we used unordered query
      routes.sort((a, b) {
        final aDate = a['savedAt'] as Timestamp?;
        final bDate = b['savedAt'] as Timestamp?;

        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;

        return bDate.compareTo(aDate);
      });

      setState(() {
        savedRoutes = routes;
        isLoading = false;
      });

      debugPrint('Successfully fetched ${routes.length} saved routes');

    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load saved routes: ${e.toString()}';
        isLoading = false;
      });
      debugPrint('Error fetching routes: $e');
    }
  }

  String _formatSavedAt(Timestamp savedAt) {
    try {
      final dateTime = savedAt.toDate();
      return DateFormat('MMMM d, yyyy \'at\' h:mm a').format(dateTime);
    } catch (e) {
      debugPrint('Error formatting date: $e');
      return 'Unknown date';
    }
  }

  RouteDetails? _parseRouteDetails(dynamic details) {
    try {
      if (details == null) return null;

      if (details is Map<String, dynamic>) {
        return RouteDetails.fromMap(details);
      } else if (details is String) {
        try {
          final parsed = jsonDecode(details) as Map<String, dynamic>;
          return RouteDetails.fromMap(parsed);
        } catch (e) {
          debugPrint('Error parsing JSON string: $e');
          return null;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error parsing route details: $e');
      return null;
    }
  }

  List<RouteStep> _parseRouteSteps(List<dynamic>? steps) {
    if (steps == null || steps.isEmpty) return [];

    try {
      return steps.map((step) {
        if (step is Map<String, dynamic>) {
          return RouteStep.fromMap(step);
        }
        debugPrint('Invalid step format: $step');
        return RouteStep.fromMap({});
      }).toList();
    } catch (e) {
      debugPrint('Error parsing route steps: $e');
      return [];
    }
  }

  Widget _buildDetailRow({
    required String label,
    required String value,
    bool expanded = false,
  }) {
    return expanded
        ? Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    )
        : Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label ',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 15),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildRouteItem(Map<String, dynamic> route) {
    final fromStation = route['fromStation']?.toString() ?? 'Unknown';
    final toStation = route['toStation']?.toString() ?? 'Unknown';
    final savedAt = route['savedAt'] as Timestamp?;
    final formattedDate = savedAt != null
        ? _formatSavedAt(savedAt)
        : 'Unknown date';
    final routeDetails = _parseRouteDetails(route['routeDetails']);
    final routeSteps = _parseRouteSteps(route['routeSteps'] as List<dynamic>?);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () {
          if (routeSteps.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RouteStepsScreen(
                  fromStation: fromStation,
                  toStation: toStation,
                  routeSteps: routeSteps,
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No route steps available'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        },
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          title: Text(
            '$fromStation → $toStation',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              if (routeDetails != null) ...[
                _buildDetailRow(
                  label: 'Departure Time:',
                  value: routeDetails.departureTime,
                  expanded: true,
                ),
                const SizedBox(height: 8),
                _buildDetailRow(
                  label: 'Arrival Time:',
                  value: routeDetails.arrivalTime,
                  expanded: true,
                ),
                const SizedBox(height: 8),
                _buildDetailRow(
                  label: 'Distance:',
                  value: routeDetails.distance,
                  expanded: true,
                ),
                const SizedBox(height: 8),
                _buildDetailRow(
                  label: 'Total Travel Duration:',
                  value: routeDetails.duration,
                  expanded: true,
                ),
                const SizedBox(height: 12),
              ] else ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No route details available',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Saved on: $formattedDate',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _confirmDelete(route['id']),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(String docId) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: const Text('Are you sure you want to delete this route?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteRoute(docId);
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteRoute(String docId) async {
    try {
      await savedRoutesCollection.doc(docId).delete();
      setState(() {
        savedRoutes.removeWhere((route) => route['id'] == docId);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Route deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete route: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchSavedRoutes,
              child: const Text('Retry'),
            ),
          ],
        ),
      )
          : savedRoutes.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.route_outlined,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No saved routes found',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _fetchSavedRoutes,
        child: ListView.builder(
          itemCount: savedRoutes.length,
          itemBuilder: (context, index) {
            return _buildRouteItem(savedRoutes[index]);
          },
        ),
      ),
    );
  }
}

// 4. Route Steps Screen
class RouteStepsScreen extends StatelessWidget {
  final String fromStation;
  final String toStation;
  final List<RouteStep> routeSteps;

  const RouteStepsScreen({
    super.key,
    required this.fromStation,
    required this.toStation,
    required this.routeSteps,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$fromStation → $toStation'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: routeSteps.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return _buildStepCard(context, routeSteps[index], index);
        },
      ),
    );
  }

  Widget _buildStepCard(BuildContext context, RouteStep step, int index) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Train ${index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    step.departure,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24, thickness: 1),
            _buildStepDetail(context, 'Departure:', step.departure, step.departureTime),
            _buildStepDetail(context, 'Arrival:', step.arrival, step.arrivalTime),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Train line: ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: DefaultTextStyle.of(context).style.copyWith(
                          color: Colors.grey[600],
                        ),
                        children: [
                          TextSpan(
                            text: '${step.line} ',
                            style: const TextStyle(
                              fontStyle: FontStyle.normal,
                            ),
                          ),
                          TextSpan(
                            text: '(${step.numStops} ${int.tryParse(step.numStops) == 1 ? 'stop' : 'stops'})',
                            style: const TextStyle(
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildStepDetail(BuildContext context, String label, String? value1, String? value2) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 4),
          if (value2 != null)
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: DefaultTextStyle.of(context).style.copyWith(
                    color: Colors.grey[600],
                  ),
                  children: [
                    TextSpan(
                      text: '$value1 ',
                      style: const TextStyle(
                        fontStyle: FontStyle.normal,
                      ),
                    ),
                    TextSpan(
                      text: '($value2)',
                      style: const TextStyle(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: Text(
                value1 ?? '',
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),
            ),
        ],
      ),
    );
  }
}