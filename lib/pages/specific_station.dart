import 'package:flutter/material.dart';
import 'package:group_assignment/api/google_api_key.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'dart:developer' as dev;

class SpecificStationPage extends StatefulWidget {
  final dynamic station;

  const SpecificStationPage({super.key, required this.station});

  @override
  State<SpecificStationPage> createState() => _SpecificStationPageState();
}

class _SpecificStationPageState extends State<SpecificStationPage> {
  String? wikiExtract;
  String? wikiUrl;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchWikipediaSummary();
  }

  Future<void> fetchWikipediaSummary() async {
    final stationName = widget.station['name'] ?? '';
    final query = Uri.encodeQueryComponent('$stationName railway station Wikipedia');
    final searchUrl =
        'https://www.googleapis.com/customsearch/v1?key=$googleApiKey&cx=$searchEngineId&q=$query';

    try {
      final searchResponse = await http.get(Uri.parse(searchUrl));
      final searchData = json.decode(searchResponse.body);
      dev.log('Search API raw response', name: 'fetchSearchInfo', error: searchData);

      if (searchData['items'] != null && searchData['items'].isNotEmpty) {
        final firstItem = searchData['items'][0];
        final link = firstItem['link'];
        final title = Uri.parse(link).pathSegments.last;

        final wikiResponse = await http.get(Uri.parse(
          'https://en.wikipedia.org/api/rest_v1/page/summary/$title',
        ));

        if (wikiResponse.statusCode == 200) {
          final wikiData = json.decode(wikiResponse.body);
          setState(() {
            wikiExtract = capitaliseFirstLetter(wikiData['extract'] ?? '');
            wikiUrl = wikiData['content_urls']['desktop']['page'];
          });
        } else {
          dev.log('Wikipedia summary fetch failed', error: wikiResponse.body);
          setState(() {
            wikiExtract = null;
          });
        }
      } else {
        setState(() {
          wikiExtract = null;
        });
      }
    } catch (e, stackTrace) {
      dev.log('Error fetching Wikipedia summary', name: 'fetchWikipediaSummary', error: e, stackTrace: stackTrace);
      setState(() {
        wikiExtract = null;
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  String capitaliseFirstLetter(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  void _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    final station = widget.station;

    final name = station['name'] ?? 'Unknown Station';
    final address = station['formatted_address'] ?? station['address'] ?? 'No address provided';
    final phone = station['formatted_phone_number'] ?? station['phoneNumber'];
    final website = station['website'] ?? station['websiteUrl'];
    final photoRef = station['photos'] != null && station['photos'].isNotEmpty
        ? station['photos'][0]['photo_reference']
        : null;
    final rawPhotoUrl = station['photoUrl'];
    final photoUrl = photoRef != null
        ? 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photoreference=$photoRef&key=$googleApiKey'
        : (rawPhotoUrl != null && rawPhotoUrl.contains('photoreference=')
        ? rawPhotoUrl.replaceAllMapped(
        RegExp(r'maxwidth=\d+'),
            (match) => 'maxwidth=400')
        : rawPhotoUrl);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.pink.shade300,
      ),
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
            const SizedBox(height: 24),
            Center(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'About',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.pink.shade300,
                      fontSize: 18,
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 4, bottom: 12),
                    height: 2,
                    width: double.infinity,
                    color: Colors.pink.shade300,
                  ),
                ],
              ),
            ),
            if (isLoading)
              Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(color: Colors.pinkAccent),
                    SizedBox(height: 16),
                    const Text('Looking up the train station...'),
                  ],
                ),
              )
            else if (wikiExtract != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  wikiExtract!,
                  textAlign: TextAlign.justify,
                  style: const TextStyle(fontSize: 14), // Matches address font size
                ),
              ),
              const SizedBox(height: 16),
              if (wikiUrl != null)
                Center(
                  child: InkWell(
                    onTap: () => _launchUrl(wikiUrl!),
                    child: const Text(
                      'Read more on Wikipedia',
                      style: TextStyle(
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
            ] else
            const Text(
              'Apologies! Nothing could be found about the station.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
