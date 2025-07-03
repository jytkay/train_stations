// Route Step Model Class
class RouteStep {
  final String departure;
  final String departureTime;
  final String arrival;
  final String arrivalTime;
  final String line;
  final String numStops;

  RouteStep({
    required this.departure,
    required this.departureTime,
    required this.arrival,
    required this.arrivalTime,
    required this.line,
    required this.numStops,
  });

  factory RouteStep.fromMap(Map<String, dynamic> map) {
    return RouteStep(
      departure: map['departure']?.toString() ?? 'Unknown',
      departureTime: map['departureTime']?.toString() ?? 'N/A',
      arrival: map['arrival']?.toString() ?? 'Unknown',
      arrivalTime: map['arrivalTime']?.toString() ?? 'N/A',
      line: map['line']?.toString() ?? 'Unknown Line',
      numStops: map['numStops']?.toString() ?? '0',
    );
  }
}
