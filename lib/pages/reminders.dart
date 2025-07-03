import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RemindersPage extends StatefulWidget {
  const RemindersPage({super.key});

  @override
  _RemindersPageState createState() => _RemindersPageState();
}

String userID = "1000";

class _RemindersPageState extends State<RemindersPage> {
  final collectionRoutes = FirebaseFirestore.instance.collection("savedRoutes");
  List<Map<String, dynamic>> items = [];
  bool isLoaded = false;
  String? errorMessage;
  Map<String, bool> switchStates = {};
  Map<String, DateTime?> selectedTimes = {};
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchData();
    // Set up a periodic timer to check reminder times every minute
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkReminderTimes();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _checkReminderTimes() {
    if (!mounted) return;

    bool needsUpdate = false;
    final now = DateTime.now();

    for (var entry in selectedTimes.entries) {
      final documentId = entry.key;
      final reminderTime = entry.value;

      if (reminderTime == null || switchStates[documentId] != true) continue;

      final item = items.firstWhere(
            (item) => item['documentId'] == documentId,
        orElse: () => {},
      );

      if (item.isEmpty) continue;

      final isDaily = item['alarmMode'] == 'Daily';
      final isOneTime = item['alarmMode'] == 'One Time';

      if (now.isAfter(reminderTime)) {
        if (isDaily) {
          // For daily reminders, add 1 day and update Firestore
          DateTime newTime = reminderTime.add(const Duration(days: 1));
          selectedTimes[documentId] = newTime;
          needsUpdate = true;

          // Update Firestore with new time
          collectionRoutes.doc(documentId).update({
            'alarmTime': Timestamp.fromDate(newTime),
          }).catchError((e) {
            debugPrint('Error updating daily reminder time: $e');
          });
        } else if (isOneTime) {
          // For one-time reminders, turn off the switch
          switchStates[documentId] = false;
          needsUpdate = true;

          collectionRoutes.doc(documentId).update({
            'notificationStatus': false,
          }).catchError((e) {
            debugPrint('Error turning off one-time reminder: $e');
          });
        }
      }
    }

    if (needsUpdate && mounted) {
      setState(() {});
    }
  }

  Future<void> _fetchData() async {
    try {
      List<Map<String, dynamic>> tempList = [];
      var data = await collectionRoutes.where('userID', isEqualTo: userID).get();

      for (var element in data.docs) {
        var docData = element.data();
        docData['documentId'] = element.id;
        tempList.add(docData);

        final documentId = element.id;
        final notificationActive = docData['notificationStatus'] ?? false;
        final notificationTime = docData['alarmTime']?.toDate();

        switchStates[documentId] = notificationActive;
        selectedTimes[documentId] = notificationTime;
      }

      setState(() {
        items = tempList;
        isLoaded = true;
        errorMessage = null;
      });

      // Check times immediately after loading data
      _checkReminderTimes();
    } catch (e) {
      setState(() {
        isLoaded = true;
        errorMessage = 'Error loading data: $e';
      });
      debugPrint('Error fetching data: $e');
    }
  }

  Widget _buildReminderCard(Map<String, dynamic> item, int index) {
    final documentId = item['documentId'];
    final fromStation = item['fromStation']?.toString() ?? 'Unknown';
    final toStation = item['toStation']?.toString() ?? 'Unknown';
    final routeDetails = item['routeDetails'] as Map<String, dynamic>?;
    final departureTime = routeDetails?['departureTime']?.toString() ?? 'N/A';

    return StatefulBuilder(
      builder: (context, setCardState) {
        DateTime? reminderTime = selectedTimes[documentId];

        if (reminderTime == null && item['alarmTime'] != null) {
          reminderTime = item['alarmTime'].toDate();
          selectedTimes[documentId] = reminderTime;
        }

        // Automatically handle passed reminders
        if (reminderTime != null && DateTime.now().isAfter(reminderTime)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (item['alarmMode'] == 'One Time' && switchStates[documentId] == true) {
              setState(() {
                switchStates[documentId] = false;
              });
              collectionRoutes.doc(documentId).update({
                'notificationStatus': false,
              });
            }
          });
        }

        Future<void> selectTime() async {
          try {
            DateTime fallback = reminderTime ?? DateTime.now();
            final TimeOfDay? picked = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.fromDateTime(fallback),
            );

            if (picked == null) return;

            final bool? repeatChoice = await showDialog<bool>(
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

            final DateTime now = DateTime.now();
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

            await collectionRoutes.doc(documentId).update({
              'alarmTime': selected,
              'alarmMode': repeatChoice ? 'Daily' : 'One Time',
              'notificationStatus': switchStates[documentId] ?? false,
            });

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Reminder time updated'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error updating reminder: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Text(
                  '$fromStation → $toStation',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (departureTime != 'N/A') ...[
                            const SizedBox(height: 4),
                            Text(
                              'Estimated Train Time: $departureTime',
                              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: GestureDetector(
                        onTap: selectTime,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
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
                    ),
                    const SizedBox(width: 8),
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

                          // Don't allow turning on if it's a one-time reminder that has passed
                          if (value &&
                              selectedTimes[documentId] != null &&
                              DateTime.now().isAfter(selectedTimes[documentId]!) &&
                              item['alarmMode'] == 'One Time') {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('This one-time reminder has already passed'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }

                          setState(() {
                            switchStates[documentId] = value;
                          });

                          try {
                            await collectionRoutes.doc(documentId).update({
                              'notificationStatus': value,
                            });
                          } catch (e) {
                            setState(() {
                              switchStates[documentId] = !value;
                            });
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
                if (switchStates[documentId] == true && selectedTimes[documentId] != null)
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
                          const Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Reminder active for ${DateFormat('MMM d, hh:mm a').format(selectedTimes[documentId]!)} (${item['alarmMode'] == 'Daily' ? 'Daily' : 'One-time'})',
                              style: const TextStyle(fontSize: 12, color: Colors.green),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 400,
            child: Image.asset(
              'assets/images/big bang.jpg',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey[200],
                  child: const Icon(
                    Icons.notifications,
                    size: 50,
                    color: Colors.grey,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: isLoaded
                ? errorMessage != null
                ? Center(child: Text(errorMessage!))
                : items.isEmpty
                ? const Center(child: Text('No reminders found'))
                : ListView(
              children: items
                  .asMap()
                  .entries
                  .map((entry) => _buildReminderCard(entry.value, entry.key))
                  .toList(),
            )
                : const Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
    );
  }
}