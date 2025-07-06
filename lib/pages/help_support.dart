import 'package:flutter/material.dart';

class HelpSupportPage extends StatefulWidget {
  const HelpSupportPage({super.key});

  @override
  State<HelpSupportPage> createState() => _HelpSupportPageState();
}

class _HelpSupportPageState extends State<HelpSupportPage> {
  final TextEditingController _feedbackController = TextEditingController();
  bool _isExpanded = false;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  void _submitFeedback() {
    if (_feedbackController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your feedback before submitting.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // TODO: Implement feedback submission logic
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Thank you for your feedback!'),
        backgroundColor: Colors.green.shade600,
      ),
    );
    _feedbackController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Help & Support',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.pink,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // FAQ Section
            Card(
              child: ExpansionTile(
                title: const Text(
                  'Frequently Asked Questions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                initiallyExpanded: _isExpanded,
                onExpansionChanged: (expanded) {
                  setState(() {
                    _isExpanded = expanded;
                  });
                },
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FAQItem(
                          question: 'How do I save train stations?',
                          answer: 'Search for a train station in the Stations page, tap on the station card to view details, tap and hold a station card for the save button to add it to your Saved page.',
                        ),
                        SizedBox(height: 16),
                        _FAQItem(
                          question: 'How do I save train routes?',
                          answer: 'In the Stations page, switch to route search via the button in the top right, enter your departure and destination details with your preferred date and time, tap and hold the route steps (in pink) for the save button to add it to your Saved page.',
                        ),
                        SizedBox(height: 16),
                        _FAQItem(
                          question: 'How do I add reminders?',
                          answer: 'Reminders can only be created for routes. Tap and hold the route steps (in pink) for the reminder button. Select your preferred time and alarm mode. You can adjust the reminder time by tapping on it in the Reminder section.',
                        ),
                        SizedBox(height: 16),
                        _FAQItem(
                          question: 'How do I use navigation?',
                          answer: 'Tap the navigation button on any train station card to open an interactive map with options to view your current location, the station location, and launch Google Maps for detailed directions.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Feedback Section
            const Text(
              'Send Feedback',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'We value your feedback! Please let us know about any issues you\'ve encountered or suggestions for improvement.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your Feedback',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _feedbackController,
                      maxLines: 6,
                      decoration: InputDecoration(
                        hintText: 'Please describe your issue or suggestion...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.pink),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _submitFeedback,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.pink,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: const Text(
                          'Submit Feedback',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Contact Information
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Need More Help?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'If you need immediate assistance or have specific technical issues, please don\'t hesitate to contact our support team.',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(Icons.email_outlined, color: Colors.pink.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          'support@uktraingo.com',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FAQItem extends StatelessWidget {
  final String question;
  final String answer;

  const _FAQItem({
    required this.question,
    required this.answer,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          answer,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}