import '../services/google_sheets_service.dart';
import 'package:flutter/material.dart';
import '../models/topic.dart';

class FlashcardDialog extends StatefulWidget {
  final Topic topic;

  const FlashcardDialog({super.key, required this.topic});

  @override
  State<FlashcardDialog> createState() => _FlashcardDialogState();
}

class _FlashcardDialogState extends State<FlashcardDialog> {
  bool _isExpanded = false;
  bool _isSubmitting = false; // Add a loading state for the buttons

  // --- THE SPACED REPETITION LOGIC BINDING ---
  Future<void> _submitReview(bool isEasy) async {
    setState(() => _isSubmitting = true);

    // 1. Calculate the math
    // If Easy: advance a stage. If Hard: drop back to Stage 1.
    int newStage = isEasy ? widget.topic.currentStage + 1 : 1;

    // Simple interval math: Stage 1 = 1 day, Stage 2 = 4 days, Stage 3 = 9 days...
    int daysToAdd = isEasy ? (newStage * newStage) : 1;
    DateTime newDate = DateTime.now().add(Duration(days: daysToAdd));

    // 2. Clone the topic with the new data
    Topic updatedTopic = Topic(
      id: widget.topic.id,
      semester: widget.topic.semester,
      subject: widget.topic.subject,
      module: widget.topic.module,
      topicName: widget.topic.topicName,
      sourceUrl: widget.topic.sourceUrl,
      feynmanSeed: widget.topic.feynmanSeed,
      dateCreated: widget.topic.dateCreated,
      nextReviewDate: newDate, // NEW!
      currentStage: newStage, // NEW!
      status: widget.topic.status,
    );

    // 3. Push the update to Google Sheets!
    await GoogleSheetsService.updateTopic(updatedTopic);

    // 4. Close the popup and send a "true" signal back to the dashboard
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: GestureDetector(
        onTap: () {
          if (!_isExpanded) setState(() => _isExpanded = true);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xff1f1f1f),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.blueAccent.withOpacity(0.5),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.topic.topicName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                widget.topic.feynmanSeed.isEmpty
                    ? "No Feynman seed provided."
                    : '"${widget.topic.feynmanSeed}"',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),

              if (_isExpanded) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Divider(color: Colors.grey),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildResourceIcon(
                      Icons.link,
                      'Source',
                      widget.topic.sourceUrl,
                    ),
                    _buildResourceIcon(
                      Icons.folder,
                      'Module',
                      'Mod ${widget.topic.module}',
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  "Did you remember this well?",
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),

                // --- THE UPDATED BUTTONS ---
                _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.blueAccent)
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => _submitReview(false), // HARD
                            icon: const Icon(Icons.thumb_down),
                            label: const Text('Hard'),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.greenAccent,
                              foregroundColor: Colors.black,
                            ),
                            onPressed: () => _submitReview(true), // EASY
                            icon: const Icon(Icons.thumb_up),
                            label: const Text('Easy'),
                          ),
                        ],
                      ),
              ] else ...[
                const SizedBox(height: 24),
                const Text(
                  "Tap to reveal details",
                  style: TextStyle(color: Colors.blueAccent, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResourceIcon(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}
