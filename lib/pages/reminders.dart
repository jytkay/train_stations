import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:group_assignment/firestore/save_reminders.dart';
import 'package:group_assignment/dialogs/edit_reminder.dart';
import 'dart:developer' as dev;

class RemindersPage extends StatefulWidget {
  final String userId;
  const RemindersPage({super.key, required this.userId});
  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> {
  List<Map<String, dynamic>> items = [];
  final Map<String, bool> switchStates = {};
  final Map<String, DateTime?> selectedTimes = {};
  bool isLoaded = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final data = await getRemindersByUser(widget.userId);
      for (final doc in data) {
        final id = doc['documentId'] as String;
        switchStates[id] = doc['notificationStatus'] ?? false;
        selectedTimes[id] = (doc['alarmTime'] as Timestamp?)?.toDate();
      }
      setState(() {
        items = data;
        isLoaded = true;
      });
    } catch (e) {
      setState(() {
        isLoaded = true;
        errorMessage = 'Error loading data: $e';
      });
    }
  }

  Widget _buildReminderCard(Map<String, dynamic> item) {
    final documentId = item['documentId'] as String;
    final fromStation = item['fromStation']?.toString() ?? 'Unknown';
    final toStation = item['toStation']?.toString() ?? 'Unknown';
    final routeSteps = item['routeSteps'] as List<dynamic>?; // Add this line

    String? departureTimeFromSteps;
    String? arrivalTimeFromSteps;

    if (routeSteps != null && routeSteps.isNotEmpty) {
      final firstStep = routeSteps.first as Map<String, dynamic>;
      final lastStep = routeSteps.last as Map<String, dynamic>;

      departureTimeFromSteps = firstStep['departureTime']?.toString();
      arrivalTimeFromSteps = lastStep['arrivalTime']?.toString();
    }

    // Create the station flow text
    String? stationFlow;
    if (routeSteps != null && routeSteps.isNotEmpty) {
      final stations = <String>[];

      for (var i = 0; i < routeSteps.length; i++) {
        final step = routeSteps[i] as Map<String, dynamic>;

        if (i == 0) {
          // Include the departure of the first step
          final departure = step['departure']?.toString();
          if (departure != null) stations.add(departure);
        }

        final arrival = step['arrival']?.toString();
        if (arrival != null) stations.add(arrival);
      }

      stationFlow = stations.join(' → ');
    }

    return StatefulBuilder(
      builder: (context, setCardState) {
        DateTime? reminderTime = selectedTimes[documentId];

        Future<void> selectTime() async {
          final picked = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.fromDateTime(
              reminderTime ?? DateTime.now(),
            ),
          );
          if (picked == null) return;

          final now = DateTime.now();
          final newDateTime = DateTime(
            now.year,
            now.month,
            now.day,
            picked.hour,
            picked.minute,
          );

          setState(() {
            selectedTimes[documentId] = newDateTime;
            item['alarmTime'] = Timestamp.fromDate(newDateTime);
          });

          await updateReminderTime(
            documentId: documentId,
            newTime: newDateTime,
          );
        }

        return GestureDetector(
          onTap: () async {
            final result = await showDialog<Map<String, dynamic>>(
              context: context,
              builder: (_) => EditReminderDialog(
                hasReminder: true,
                documentId: documentId,
                currentTime: selectedTimes[documentId],
                currentMode: item['alarmMode'],
                currentDays: item['selectedDays']?.cast<String>(),
                currentStatus: switchStates[documentId] ?? false,
              ),
            );

            if (result != null) {
              if (result['delete'] == true) {
                await deleteReminder(documentId);
                setState(() {
                  items.removeWhere((e) => e['documentId'] == documentId);
                  switchStates.remove(documentId);
                  selectedTimes.remove(documentId);
                });
                return;
              }

              if (result['time'] != null) {
                setState(() {
                  selectedTimes[documentId] = result['time'];
                  item['alarmTime'] = Timestamp.fromDate(result['time']);
                });
              }
              _fetchData();
            }
          },
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // First line: From → To
                  Text(
                    '$fromStation → $toStation',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  // Second line: Full station flow (if available)
                  if (stationFlow != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      stationFlow,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Time button
                      Expanded(
                        flex: 2,
                        child: InkWell(
                          onTap: selectTime,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.access_time,
                                    size: 16, color: Colors.blue),
                                const SizedBox(height: 4),
                                Text(
                                  reminderTime != null
                                      ? DateFormat('hh:mm a').format(reminderTime!)
                                      : 'Tap to set',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Train departure → arrival time
                      Expanded(
                        flex: 6,
                        child: (departureTimeFromSteps == null || arrivalTimeFromSteps == null)
                            ? const SizedBox.shrink()
                            : Text(
                          'Travel Time:\n $departureTimeFromSteps → $arrivalTimeFromSteps',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Toggle
                      Expanded(
                        flex: 2,
                        child: Switch(
                          value: switchStates[documentId] ?? false,
                          onChanged: (value) async {
                            setState(() => switchStates[documentId] = value);
                            await setReminderStatus(
                              documentId: documentId,
                              isActive: value,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
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
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          SizedBox(
            width: double.infinity,
            height: 400,
            child: Image.asset(
              'assets/images/big bang.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.grey[200],
                child: const Icon(Icons.notifications,
                    size: 50, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (!isLoaded)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 80),
                child:
                CircularProgressIndicator(color: Colors.pinkAccent),
              ),
            )
          else if (errorMessage != null)
            Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 80),
                  child: Text(errorMessage!),
                ))
          else if (items.isEmpty)
              const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 80),
                    child: Text('No reminders found'),
                  ))
            else
              ...items.map(_buildReminderCard).toList(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
