// Route Details Model Class
class RouteDetails {
  final String departureTime;
  final String arrivalTime;
  final String distance;
  final String duration;

  RouteDetails({
    required this.departureTime,
    required this.arrivalTime,
    required this.distance,
    required this.duration,
  });

  factory RouteDetails.fromMap(Map<String, dynamic> map) {
    return RouteDetails(
      departureTime: map['departureTime']?.toString() ?? 'N/A',
      arrivalTime: map['arrivalTime']?.toString() ?? 'N/A',
      distance: map['distance']?.toString() ?? 'N/A',
      duration: map['duration']?.toString() ?? 'N/A',
    );
  }
}