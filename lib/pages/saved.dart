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

class _SavedPageState extends State<SavedPage> {
  List<Map<String, dynamic>> _stations = [];
  final Set<String> _selectedPlaceIds = {};
  bool _isLoading = true;

  Future<void> _loadStations() async {
    setState(() {
      _isLoading = true;
    });
    final snapshot =
        await FirebaseFirestore.instance
            .collection('savedStations')
            .orderBy('savedAt', descending: true)
            .get();
    setState(() {
      _stations = snapshot.docs.map((doc) => doc.data()).toList();
      _isLoading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadStations();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    } else if (_stations.isEmpty) {
      return const Center(child: Text('No saved stations yet.'));
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
                    // Updated navigation button onPressed method
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MainScaffold(
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
}
