import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: PlaceholderPage(),
    );
  }
}

class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Location Demo')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const MapPage(
                  lat: 5.3595,
                  lng: 100.2849,
                  address: "Sample Address, Penang, Malaysia",
                  name: "Penang Station",
                ),
              ),
            );
          },
          child: const Text('Open Map with Destination'),
        ),
      ),
    );
  }
}

class MapPage extends StatefulWidget {
  final double? lat;
  final double? lng;
  final String? address;
  final String? photoUrl;
  final String? name;

  const MapPage({
    super.key,
    this.lat,
    this.lng,
    this.name,
    this.address,
    this.photoUrl,
  });

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  GoogleMapController? mapController;
  StreamSubscription<Position>? positionStream;

  double? currentLat;
  double? currentLng;
  String? errorMessage;

  Set<Marker> markers = {};

  bool isCurrentLocationFocused = false;
  bool isDestinationFocused = true; // default on launch

  @override
  void initState() {
    super.initState();
    _addDestinationMarker();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    positionStream?.cancel();
    mapController?.dispose();
    super.dispose();
  }

  void _addDestinationMarker() {
    if (widget.lat != null && widget.lng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: LatLng(widget.lat!, widget.lng!),
          infoWindow: InfoWindow(
            title: widget.name ?? 'Destination',
            snippet: widget.address ?? '',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      await _checkPermissions();

      positionStream = Geolocator.getPositionStream().listen((position) {
        if (mounted) {
          setState(() {
            currentLat = position.latitude;
            currentLng = position.longitude;
            errorMessage = null;
          });
        }
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
      });
    }
  }

  Future<void> _checkPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permission permanently denied.');
    }
  }

  void _centerOnDestination() {
    if (widget.lat != null && widget.lng != null && mapController != null) {
      mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(widget.lat!, widget.lng!), 16),
      );
    }
  }

  void _centerOnCurrentLocation() {
    if (currentLat != null && currentLng != null && mapController != null) {
      mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(currentLat!, currentLng!), 16),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Current location not available yet.")),
      );
    }
  }

  void _launchGoogleMapsDirections() async {
    if (currentLat == null || currentLng == null || widget.lat == null || widget.lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Coordinates missing for directions.")),
      );
      return;
    }

    final url = Uri.parse(
      "https://www.google.com/maps/dir/?api=1"
          "&origin=$currentLat,$currentLng"
          "&destination=${widget.lat},${widget.lng}"
          "&travelmode=transit",
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not launch Google Maps.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final CameraPosition initialCameraPosition = CameraPosition(
      target: LatLng(widget.lat ?? 0, widget.lng ?? 0),
      zoom: 16,
    );

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) {
              mapController = controller;
              _centerOnDestination();
              setState(() {
                isDestinationFocused = true;
                isCurrentLocationFocused = false;
              });
            },
            initialCameraPosition: initialCameraPosition,
            markers: markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // Floating Buttons
          Positioned(
            bottom: 20,
            right: 20,
            child: Column(
              children: [
                // Destination button
                FloatingActionButton(
                  heroTag: 'dest',
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  onPressed: () {
                    _centerOnDestination();
                    setState(() {
                      isDestinationFocused = true;
                      isCurrentLocationFocused = false;
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDestinationFocused ? Colors.red : Colors.grey,
                    ),
                    padding: const EdgeInsets.all(10),
                    child: const Icon(Icons.place, color: Colors.white, size: 30),
                  ),
                ),
                const SizedBox(height: 10),

                // My Location button
                FloatingActionButton(
                  heroTag: 'current',
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  onPressed: () {
                    _centerOnCurrentLocation();
                    setState(() {
                      isDestinationFocused = false;
                      isCurrentLocationFocused = true;
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCurrentLocationFocused ? Colors.blue : Colors.grey,
                    ),
                    padding: const EdgeInsets.all(10),
                    child: const Icon(Icons.my_location, color: Colors.white, size: 30),
                  ),
                ),
                const SizedBox(height: 10),

                // Directions button
                FloatingActionButton(
                  heroTag: 'directions',
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  onPressed: _launchGoogleMapsDirections,
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.green,
                    ),
                    padding: const EdgeInsets.all(10),
                    child: const Icon(Icons.directions, color: Colors.white, size: 30),
                  ),
                ),
              ],
            ),
          ),

          if (errorMessage != null)
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(10),
                color: Colors.red.shade100,
                child: Text(
                  errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
