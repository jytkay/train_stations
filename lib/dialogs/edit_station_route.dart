import 'package:flutter/material.dart';
import 'package:group_assignment/api/google_api_key.dart';
import 'package:group_assignment/firestore/save_stations.dart';
import 'package:group_assignment/firestore/save_routes.dart';
import 'dart:developer' as dev;

Future<void> showEditStationBottomSheet({
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
  final alreadySaved = await isStationSaved(placeId);
  const hasReminder = false;

  showModalBottomSheet(
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
                final existing = await getSavedStationByPlaceId(placeId);
                noteCtrl.text = existing?['note'] ?? '';
              }
              await _showNoteDialog(
                context: context,
                alreadySaved: alreadySaved,
                noteCtrl: noteCtrl,
                onDelete: () async {
                  await removeStationByPlaceId(placeId);
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Station removed from saved'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                onSave: () async {
                  await saveStationToFirestore(
                    placeId: placeId,
                    name: name,
                    address: address,
                    phoneNumber: phone,
                    websiteUrl: website,
                    photoUrl: photoUrl,
                    lat: lat,
                    lng: lng,
                    note: noteCtrl.text.trim(),
                  );
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        alreadySaved ? 'Saved station updated' : 'Station saved',
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              );
              Navigator.pop(context);
            },
          ),
          ListTile(
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
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    hasReminder ? 'Reminder removed' : 'Reminder added',
                  ),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      );
    },
  );
}

Future<void> showEditRouteBottomSheet({
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

  showModalBottomSheet(
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
                dev.log("noteCtrl: $noteCtrl");

                await saveRouteToFirestore(
                  routeId: routeId,
                  fromStation: fromStation,
                  toStation: toStation,
                  routeSteps: routeSteps,
                  routeDetailsRaw: routeDetailsRaw,
                  selectedDepartureDay: selectedDepartureDay,
                  selectedTimeRange: selectedTimeRange,
                  note: noteCtrl.text.trim(),
                );
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      alreadySaved ? 'Saved route updated' : 'Route saved',
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            );
            Navigator.pop(context);
          },
        ),
        ListTile(
          leading: const Icon(Icons.alarm_add, color: Colors.green),
          title: const Text(
            'Add Reminder',
            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
          ),
          onTap: () {
            Navigator.pop(context);
            messenger.showSnackBar(
              const SnackBar(
                content: Text('Reminder functionality coming soon!'),
                behavior: SnackBarBehavior.floating,
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
                        Navigator.pop(context);
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
                      Navigator.pop(context);
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
