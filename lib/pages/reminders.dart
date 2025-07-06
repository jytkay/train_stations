import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:group_assignment/firestore/save_reminders.dart';
import 'package:group_assignment/dialogs/edit_reminder.dart';

/// Dummy user identifier; swap out for an auth‑based uid when ready.
const String userID = '1000';

class RemindersPage extends StatefulWidget {
  const RemindersPage({super.key});

  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> {
  // Firestore‑derived data
  List<Map<String, dynamic>> items = [];

  // UI bookkeeping
  final Map<String, bool> switchStates = {};
  final Map<String, DateTime?> selectedTimes = {};

  bool isLoaded = false;
  String? errorMessage;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _timer = Timer.periodic(
      const Duration(minutes: 1),
          (_) => _checkReminderTimes(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Pull reminders for the current user
  Future<void> _fetchData() async {
    try {
      final data = await getRemindersByUser(userID);

      for (final doc in data) {
        final documentId = doc['documentId'] as String;
        switchStates[documentId] = doc['notificationStatus'] ?? false;
        selectedTimes[documentId] =
            (doc['alarmTime'] as Timestamp?)?.toDate();
      }

      setState(() {
        items = data;
        isLoaded = true;
        errorMessage = null;
      });

      _checkReminderTimes();
    } catch (e) {
      setState(() {
        isLoaded = true;
        errorMessage = 'Error loading data: $e';
      });
    }
  }

  /// Validate alarms and reschedule/disable when necessary
  void _checkReminderTimes() {
    if (!mounted) return;

    bool needsUpdate = false;
    final now = DateTime.now();

    for (final entry in selectedTimes.entries) {
      final documentId = entry.key;
      final reminderTime = entry.value;

      if (reminderTime == null || switchStates[documentId] != true) continue;

      final item = items.firstWhere(
            (it) => it['documentId'] == documentId,
        orElse: () => <String, dynamic>{},
      );
      if (item.isEmpty) continue;

      final isDaily = item['alarmMode'] == 'Daily';
      final isOneTime = item['alarmMode'] == 'One Time';

      if (now.isAfter(reminderTime)) {
        if (isDaily) {
          final newTime = reminderTime.add(const Duration(days: 1));
          selectedTimes[documentId] = newTime;
          needsUpdate = true;
          updateReminderTime(documentId: documentId, newTime: newTime);
        } else if (isOneTime) {
          switchStates[documentId] = false;
          needsUpdate = true;
          setReminderStatus(documentId: documentId, isActive: false);
        }
      }
    }

    if (needsUpdate && mounted) setState(() {});
  }

  /// Card builder
  Widget _buildReminderCard(Map<String, dynamic> item) {
    final documentId = item['documentId'] as String;
    final fromStation = item['fromStation']?.toString() ?? 'Unknown';
    final toStation = item['toStation']?.toString() ?? 'Unknown';
    final routeDetails = item['routeDetails'] as Map<String, dynamic>?;
    final departureTime = routeDetails?['departureTime']?.toString() ?? 'N/A';

    return StatefulBuilder(
      builder: (context, setCardState) {
        DateTime? reminderTime = selectedTimes[documentId];

        if (reminderTime == null && item['alarmTime'] != null) {
          reminderTime = (item['alarmTime'] as Timestamp).toDate();
          selectedTimes[documentId] = reminderTime;
        }

        if (reminderTime != null &&
            DateTime.now().isAfter(reminderTime) &&
            item['alarmMode'] == 'One Time' &&
            switchStates[documentId] == true) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() => switchStates[documentId] = false);
            setReminderStatus(documentId: documentId, isActive: false);
          });
        }

        Future<void> selectTime() async {
          final fallback = reminderTime ?? DateTime.now();
          final picked = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.fromDateTime(fallback),
          );
          if (picked == null) return;

          final repeatChoice = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Reminder Type'),
              content: const Text('Should this reminder repeat daily?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Once'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Daily'),
                ),
              ],
            ),
          );
          if (repeatChoice == null) return;

          final now = DateTime.now();
          DateTime selected = DateTime(
            now.year,
            now.month,
            now.day,
            picked.hour,
            picked.minute,
          );
          if (selected.isBefore(now)) {
            selected = selected.add(const Duration(days: 1));
          }

          setState(() {
            selectedTimes[documentId] = selected;
            item['alarmMode'] = repeatChoice ? 'Daily' : 'One Time';
            item['alarmTime'] = Timestamp.fromDate(selected);
          });

          await updateAlarmDetails(
            documentId: documentId,
            alarmTime: selected,
            alarmMode: repeatChoice ? 'Daily' : 'One Time',
            isActive: switchStates[documentId] ?? false,
          );

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reminder time updated'),
              backgroundColor: Colors.green,
            ),
          );
        }

        return GestureDetector(
          onTap: () async {
            final result = await showDialog<Map<String, dynamic>>(
              context: context,
              builder: (context) => EditReminderDialog(
                documentId: documentId,
                currentTime: selectedTimes[documentId],
                currentMode: item['alarmMode'],
                currentDays: item['selectedDays']?.cast<String>(),
                currentStatus: switchStates[documentId] ?? false,
              ),
            );

            if (result != null) {
              setState(() {
                selectedTimes[documentId] = result['time'];
                item['alarmMode'] = result['mode'];
                item['selectedDays'] = result['days'];
                item['alarmTime'] = Timestamp.fromDate(result['time']);
              });
            }
          },
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Text(
                    '$fromStation → $toStation',
                    style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Time button (first)
                      Expanded(
                        flex: 2,
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
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.access_time, size: 16, color: Colors.blue),
                              const SizedBox(height: 4),
                              Text(
                                reminderTime != null
                                    ? DateFormat('hh:mm a').format(reminderTime)
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
                      const SizedBox(width: 8),

                      // Departure time details (middle)
                      Expanded(
                        flex: 6,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (departureTime != 'N/A') ...[
                              const SizedBox(height: 4),
                              Text(
                                'Estimated Train Time: $departureTime',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Switch toggle (last)
                      Expanded(
                        flex: 2,
                        child: Switch(
                          value: switchStates[documentId] ?? false,
                          onChanged: (value) async {
                            if (value && selectedTimes[documentId] == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please set a reminder time first'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                              return;
                            }

                            final alarm = selectedTimes[documentId];
                            if (value &&
                                alarm != null &&
                                DateTime.now().isAfter(alarm) &&
                                item['alarmMode'] == 'One Time') {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('This one‑time reminder has already passed'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                              return;
                            }

                            setState(() => switchStates[documentId] = value);

                            try {
                              await setReminderStatus(
                                documentId: documentId,
                                isActive: value,
                              );
                            } catch (e) {
                              setState(() => switchStates[documentId] = !value);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to update: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  if (switchStates[documentId] == true &&
                      selectedTimes[documentId] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_outline,
                              size: 16,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Reminder active for '
                                    '${DateFormat('MMM d, hh:mm a').format(selectedTimes[documentId]!)} '
                                    '(${item['alarmMode'] == 'Daily' ? 'Daily' : 'One‑time'})',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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
                child: const Icon(Icons.notifications, size: 50, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (!isLoaded)
            const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 80), child: CircularProgressIndicator(color: Colors.pinkAccent)))
          else if (errorMessage != null)
            Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 80), child: Text(errorMessage!)))
          else if (items.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 80), child: Text('No reminders found')))
            else
              ...items.map(_buildReminderCard).toList(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
