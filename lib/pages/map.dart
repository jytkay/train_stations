import 'package:flutter/material.dart';

class MapPage extends StatelessWidget {
  final double? lat;
  final double? lng;

  const MapPage({super.key, this.lat, this.lng});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Map Page'));
  }
}
