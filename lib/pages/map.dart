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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "This screen expects coordinates passed from another file.",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) => const MapPage(
                      lat: 5.3595,
                      lng: 100.2849,
                      address: "Sample Address, Penang, Malaysia - This is a longer address to test display",
                    ),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
                    transitionDuration: Duration.zero, // optional: no animation
                    reverseTransitionDuration: Duration.zero,
                    settings: const RouteSettings(name: "MapPage"),
                    // Disable back gesture (iOS)
                    opaque: true,
                    barrierDismissible: false,
                  ),
                );
              },
              child: const Text('Test with Demo Coordinates'),
            ),
          ],
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
  double? currentLat;
  double? currentLng;
  bool isLoading = false;
  String? errorMessage;
  StreamSubscription<Position>? positionStream;
  bool isFirstLocationUpdate = true;
  bool showGoogleMapsButton = false;
  bool isDestinationVisible = true;
  bool isCurrentLocationFocused = false;




  GoogleMapController? mapController;
  Set<Marker> markers = {};

  late CameraPosition _initialCameraPosition;

  @override
  void initState() {
    super.initState();

    _initialCameraPosition = CameraPosition(
      target: LatLng(widget.lat ?? 5.3595, widget.lng ?? 100.2849),
      zoom: 17.0,
    );

    _setupDestinationMarker();
    _getCurrentLocation();
  }

  void _setupDestinationMarker() {

    if (widget.lat != null && widget.lng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: LatLng(widget.lat!, widget.lng!),
          infoWindow: InfoWindow(
            title: 'Destination:',
            snippet: widget.name != null && widget.name!.isNotEmpty
                ? widget.name!.length > 50
                ? '${widget.name!.substring(0, 50)}...'
                : widget.name!
                : 'Your target location',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      await _checkPermissions();
      _startLocationStream();
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
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

  Future<void> _launchGoogleMapsDirections() async {
    if (currentLat != null && currentLng != null && widget.lat != null && widget.lng != null) {
      final Uri googleMapsUri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&origin=$currentLat,$currentLng&destination=${widget.lat},${widget.lng}&travelmode=driving',
      );
      if (await canLaunchUrl(googleMapsUri)) {
        await launchUrl(googleMapsUri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch Google Maps')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Current or destination location unavailable')),
      );
    }
  }

  void _startLocationStream() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    positionStream = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
      if (mounted) {
        if (position.latitude != currentLat || position.longitude != currentLng) {
          setState(() {
            currentLat = position.latitude;
            currentLng = position.longitude;
            isLoading = false;
            errorMessage = null;
          });
          _updateCurrentLocationMarker(position.latitude, position.longitude);
        }
      }
    }, onError: (error) {
      if (mounted) {
        setState(() {
          errorMessage = 'Unable to get current location: $error';
          isLoading = false;
        });
      }
    });
  }

  void _updateCurrentLocationMarker(double lat, double lng) {
    markers.removeWhere((marker) => marker.markerId.value == 'current_location');

    if (mounted) setState(() {});
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  void _centerOnCurrentLocation() {
    if (currentLat != null && currentLng != null && mapController != null) {
      mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(currentLat!, currentLng!), 16),
      );
      setState(() {
        isCurrentLocationFocused = true;
      });
    } else {
      _getCurrentLocation();
    }
  }

  void _centerOnDestination() {
    if (widget.lat != null && widget.lng != null && mapController != null) {
      mapController!.animateCamera(CameraUpdate.newLatLngZoom(LatLng(widget.lat!, widget.lng!), 16));
    }
  }

  double? _calculateDistance() {
    if (currentLat != null && currentLng != null && widget.lat != null && widget.lng != null) {
      return Geolocator.distanceBetween(currentLat!, currentLng!, widget.lat!, widget.lng!);
    }
    return null;
  }

  String _formatDistance(double distanceInMeters) {
    return distanceInMeters < 1000
        ? '${distanceInMeters.toStringAsFixed(0)} m'
        : '${(distanceInMeters / 1000).toStringAsFixed(2)} km';
  }

  @override
  void dispose() {
    positionStream?.cancel();
    mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final distance = _calculateDistance();
    return Scaffold(
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.blue,
            child: Row(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white.withOpacity(0.2),
                  ),
                  child: widget.photoUrl != null && widget.photoUrl!.isNotEmpty
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(widget.photoUrl!, fit: BoxFit.cover),
                  )
                      : const Icon(Icons.train, size: 40, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.name ?? 'Station Name',
                          style: const TextStyle(fontSize: 18, color: Colors.white)),
                      if (widget.address != null)
                        Text(widget.address!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: Colors.white70)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Map
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: _initialCameraPosition,
                  markers: markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomGesturesEnabled: true,
                  zoomControlsEnabled: false,
                  // The below code always enable map tools bar
                  // (include the direction and map button that will appear on bottom right)
                  mapToolbarEnabled: false,
                  onCameraMove: (position) {
                    // Handle destination visibility
                    if (widget.lat != null && widget.lng != null) {
                      final distanceToDest = Geolocator.distanceBetween(
                        position.target.latitude,
                        position.target.longitude,
                        widget.lat!,
                        widget.lng!,
                      );
                      final isVisible = distanceToDest < 300;
                      if (isDestinationVisible != isVisible) {
                        setState(() {
                          isDestinationVisible = isVisible;
                        });
                      }
                    }
                    // Handle current location focus
                    if (currentLat != null && currentLng != null) {
                      final distanceToCurrent = Geolocator.distanceBetween(
                        position.target.latitude,
                        position.target.longitude,
                        currentLat!,
                        currentLng!,
                      );

                      final isFocused = distanceToCurrent < 100; // Adjust tolerance
                      if (isCurrentLocationFocused != isFocused) {
                        setState(() {
                          isCurrentLocationFocused = isFocused;
                        });
                      }
                    }
                  },
                ),

                // Floating Buttons
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: Column(
                    children: [
                      FloatingActionButton(
                        heroTag: 'dest',
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        onPressed: _centerOnDestination,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDestinationVisible ? Colors.red : Colors.grey,
                          ),
                          padding: const EdgeInsets.all(10),
                          child: const Icon(
                            Icons.place,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),

                      FloatingActionButton(
                        heroTag: 'current',
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        onPressed: _centerOnCurrentLocation,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isCurrentLocationFocused ? Colors.blue : Colors.grey,
                          ),
                          padding: const EdgeInsets.all(10),
                          child: const Center(
                            child: Icon(
                              Icons.my_location,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                        ),
                      ),
                      FloatingActionButton(
                        heroTag: 'directions',
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        onPressed: _launchGoogleMapsDirections,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.blue,
                          ),
                          padding: const EdgeInsets.all(10),
                          child: const Icon(
                            Icons.directions,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Distance & Errors
                Positioned(
                  top: 20,
                  left: 12,
                  right: 12,
                  child: Column(
                    children: [
                      if (distance != null)
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.straighten, size: 16, color: Colors.green),
                              const SizedBox(width: 6),
                              Text(
                                'Distance: ${_formatDistance(distance)}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      if (errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(top: 8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            errorMessage!,
                            style: const TextStyle(color: Colors.red),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
