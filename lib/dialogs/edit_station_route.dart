import 'package:flutter/material.dart';
import 'package:group_assignment/api/google_api_key.dart';
import 'package:group_assignment/firestore/save_stations.dart';
import 'package:group_assignment/firestore/save_routes.dart';
import 'package:group_assignment/firestore/save_reminders.dart';
import 'package:group_assignment/dialogs/edit_reminder.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

Future<bool?> showEditStationBottomSheet({
  required userId,
  required BuildContext context,
  required Map<String, dynamic> station,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final placeId = station['place_id'];
  final name = station['name'] ?? 'Unnamed';
  final address = station['formatted_address'] ?? 'No address';
  final phone = station['formatted_phone_number'];
  final website = station['website'];
  final photoRef = (station['photos'] != null && station['photos'].isNotEmpty)
      ? station['photos'][0]['photo_reference']
      : null;
  final String? photoUrl = (photoRef?.isNotEmpty ?? false)
      ? 'https://maps.googleapis.com/maps/api/place/photo'
      '?maxwidth=400&photoreference=$photoRef&key=$googleApiKey'
      : station['photoUrl'];
  final lat = station['geometry']?['location']?['lat'];
  final lng = station['geometry']?['location']?['lng'];
  final alreadySaved = await isStationSaved(userId, placeId);

  return await showModalBottomSheet<bool>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
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
              final noteCtrl = TextEditingController();
              if (alreadySaved) {
                final existing = await getSavedStationByPlaceId(userId, placeId);
                noteCtrl.text = existing?['note'] ?? '';
              }

              await _showNoteDialog(
                context: context,
                alreadySaved: alreadySaved,
                noteCtrl: noteCtrl,
                onDelete: () async {
                  await removeStationByPlaceId(userId, placeId);
                  await messenger
                      .showSnackBar(
                    const SnackBar(
                      content: Text('Station removed from saved'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  )
                      .closed;
                  if (context.mounted) Navigator.of(context).pop(true);
                },
                onSave: () async {
                  final note = noteCtrl.text.trim();
                  if (alreadySaved) {
                    await updateNoteForStation(
                      userId: userId,
                      placeId: placeId,
                      note: note,
                    );
                    await messenger
                        .showSnackBar(
                      const SnackBar(
                        content: Text('Saved station note updated'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    )
                        .closed;
                  } else {
                    await saveStationToFirestore(
                      userId: userId,
                      placeId: placeId,
                      name: name,
                      address: address,
                      phoneNumber: phone,
                      websiteUrl: website,
                      photoUrl: photoUrl,
                      lat: lat,
                      lng: lng,
                      note: note,
                    );
                    await messenger
                        .showSnackBar(
                      const SnackBar(
                        content: Text('Station saved'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    )
                        .closed;
                  }
                  if (context.mounted) Navigator.of(context).pop(true);
                },
              );
            },
          ),
        ],
      );
    },
  );
}

Future<bool?> showEditRouteBottomSheet({
  required String userId,
  required BuildContext context,
  required String routeId,
  required Map<String, dynamic> routeDetailsRaw,
  required List<Map<String, dynamic>> routeSteps,
  required String fromStation,
  required String toStation,
  DateTime? selectedDepartureDay,
  required String selectedTimeRange,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final alreadySaved = await isRouteSaved(routeId);
  final noteCtrl = TextEditingController();

  if (alreadySaved) {
    final existing = await getSavedRouteById(routeId);
    noteCtrl.text = existing?['note'] ?? '';
  }

  final reminder = await getReminderForRoute(
    userId: userId,
    fromStation: fromStation,
    toStation: toStation,
  );
  final hasReminder = reminder != null;

  final rawDeparture = routeDetailsRaw['departure_time'];
  final rawArrival = routeDetailsRaw['arrival_time'];

  String departureTimeFormatted = '';
  String arrivalTimeFormatted = '';
  final formatter = DateFormat.jm();

  try {
    if (rawDeparture is String) {
      departureTimeFormatted = formatter.format(DateTime.parse(rawDeparture));
    } else if (rawDeparture is Timestamp) {
      departureTimeFormatted = formatter.format(rawDeparture.toDate());
    }
  } catch (_) {}

  try {
    if (rawArrival is String) {
      arrivalTimeFormatted = formatter.format(DateTime.parse(rawArrival));
    } else if (rawArrival is Timestamp) {
      arrivalTimeFormatted = formatter.format(rawArrival.toDate());
    }
  } catch (_) {}

  final now = DateTime.now();
  if (departureTimeFormatted.isEmpty) {
    departureTimeFormatted = formatter.format(now);
  }
  if (arrivalTimeFormatted.isEmpty) {
    arrivalTimeFormatted = formatter.format(now.add(const Duration(minutes: 10)));
  }

  return await showModalBottomSheet<bool>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: Icon(
            alreadySaved ? Icons.edit : Icons.bookmark_add,
            color: alreadySaved ? Colors.blue : Colors.green,
          ),
          title: Text(
            alreadySaved ? 'Edit Saved Route' : 'Save Route',
            style: TextStyle(
              color: alreadySaved ? Colors.blue : Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
          onTap: () async {
            await _showNoteDialog(
              context: context,
              alreadySaved: alreadySaved,
              noteCtrl: noteCtrl,
              onDelete: () async {
                await removeRouteById(routeId);
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Route removed from saved'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              onSave: () async {
                if (alreadySaved) {
                  await updateNoteForRoute(
                    userId: userId,
                    routeId: routeId,
                    newNote: noteCtrl.text.trim(),
                  );
                } else {
                  await saveRouteToFirestore(
                    userId: userId,
                    routeId: routeId,
                    fromStation: fromStation,
                    toStation: toStation,
                    routeSteps: routeSteps,
                    routeDetailsRaw: routeDetailsRaw,
                    selectedDepartureDay: selectedDepartureDay,
                    selectedTimeRange: selectedTimeRange,
                    note: noteCtrl.text.trim(),
                  );
                }

                messenger.showSnackBar(
                  SnackBar(
                    content: Text(alreadySaved ? 'Note updated' : 'Route saved'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            );
            Navigator.of(context).pop(true); // <- return true
          },
        ),
        ListTile(
          leading: Icon(
            hasReminder ? Icons.alarm : Icons.alarm_add,
            color: hasReminder ? Colors.blue : Colors.green,
          ),
          title: Text(
            hasReminder ? 'Edit Reminder' : 'Add Reminder',
            style: TextStyle(
              color: hasReminder ? Colors.blue : Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
          onTap: () async {
            Navigator.of(context).pop(true); // <- also return true to indicate update
            await showDialog<Map<String, dynamic>>(
              context: context,
              builder: (_) => EditReminderDialog(
                documentId: hasReminder ? reminder['documentId'] as String : '',
                currentTime: hasReminder
                    ? (reminder['alarmTime'] as Timestamp).toDate()
                    : now.add(const Duration(minutes: 1)),
                currentMode: hasReminder ? reminder['alarmMode'] ?? 'One Time' : 'One Time',
                currentDays: hasReminder
                    ? (reminder['selectedDays'] as List<dynamic>?)?.cast<String>() ?? []
                    : [],
                currentStatus: hasReminder ? reminder['notificationStatus'] ?? true : true,
                hasReminder: hasReminder,
                routeDetails: {
                  'userId': userId,
                  'routeId': routeId,
                  'fromStation': fromStation,
                  'toStation': toStation,
                  'departureTime': departureTimeFormatted,
                  'arrivalTime': arrivalTimeFormatted,
                  'routeSteps': routeSteps,
                },
              ),
            );
          },
        ),
      ],
    ),
  );
}

Future<void> _showNoteDialog({
  required BuildContext context,
  required bool alreadySaved,
  required TextEditingController noteCtrl,
  required Future<void> Function() onSave,
  Future<void> Function()? onDelete,
}) {
  return showDialog(
    context: context,
    builder: (_) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              alreadySaved ? 'Edit Note' : 'Add Note',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Add note...',
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFF06292)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFF06292), width: 2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                if (alreadySaved && onDelete != null) ...[
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF8A80),
                      ),
                      onPressed: () async {
                        Navigator.of(context).pop(true);
                        await onDelete();
                      },
                      child: const Text('Delete', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: alreadySaved
                          ? const Color(0xFF64B5F6)
                          : const Color(0xFFF48FB1),
                    ),
                    onPressed: () async {
                      Navigator.of(context).pop(true);
                      await onSave();
                    },
                    child: Text(
                      alreadySaved ? 'Edit' : 'Save',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}