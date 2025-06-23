import 'package:flutter/material.dart';
import 'package:group_assignment/api/google_api_key.dart';
import 'package:url_launcher/url_launcher.dart';

class SpecificStationPage extends StatelessWidget {
  final dynamic station;

  const SpecificStationPage({super.key, required this.station});

  void _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = station['name'] ?? 'Unknown Station';
    final address = station['formatted_address'] ?? 'No address provided';
    final phone = station['formatted_phone_number'];
    final website = station['website'];
    final openingHours = station['opening_hours']?['weekday_text'];
    final photoRef =
        (station['photos'] != null && station['photos'].isNotEmpty)
            ? station['photos'][0]['photo_reference']
            : null;
    final photoUrl =
        photoRef != null
            ? 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photoreference=$photoRef&key=$googleApiKey'
            : null;

    return Scaffold(
      appBar: AppBar(title: Text(name), backgroundColor: Colors.pink.shade300),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (photoUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(photoUrl),
              ),
            const SizedBox(height: 16),
            Text(
              name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16),
                const SizedBox(width: 4),
                Expanded(child: Text(address)),
              ],
            ),
            const SizedBox(height: 12),
            if (phone != null)
              Row(
                children: [
                  const Icon(Icons.phone, size: 16),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () => _launchUrl('tel:$phone'),
                    child: Text(
                      phone,
                      style: const TextStyle(color: Colors.blue),
                    ),
                  ),
                ],
              ),
            if (website != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.web, size: 16),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () => _launchUrl(website),
                    child: const Text(
                      'Visit Website',
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ],
            if (openingHours != null) ...[
              const SizedBox(height: 20),
              const Text(
                'Opening Hours:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              ...openingHours.map<Widget>((hour) => Text(hour)).toList(),
            ],
          ],
        ),
      ),
    );
  }
}
