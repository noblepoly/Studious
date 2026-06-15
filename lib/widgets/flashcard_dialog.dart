import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/google_sheets_service.dart';
import '../models/topic.dart';

class FlashcardDialog extends StatefulWidget {
  final Topic topic;
  const FlashcardDialog({super.key, required this.topic});

  @override
  State<FlashcardDialog> createState() => _FlashcardDialogState();
}

class _FlashcardDialogState extends State<FlashcardDialog> {
  bool _isExpanded = false;
  bool _isSubmitting = false;

  Future<void> _submitReview(bool isEasy) async {
    setState(() => _isSubmitting = true);

    try {
      int newStage = isEasy ? widget.topic.currentStage + 1 : 1;
      int daysToAdd = isEasy ? (newStage * newStage) : 1;
      DateTime newDate = DateTime.now().add(Duration(days: daysToAdd));

      Topic updatedTopic = Topic(
        id: widget.topic.id,
        semester: widget.topic.semester,
        subject: widget.topic.subject,
        module: widget.topic.module,
        topicName: widget.topic.topicName,
        sourceUrl: widget.topic.sourceUrl,
        feynmanSeed: widget.topic.feynmanSeed,
        dateCreated: widget.topic.dateCreated,
        nextReviewDate: newDate,
        currentStage: newStage,
        status: widget.topic.status,
      );

      await GoogleSheetsService.updateTopic(updatedTopic);

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(true);
      }
    } catch (e) {
      print("ERROR updating sheet: $e");
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  // Dual-mode web launcher fallback engine
  Future<void> _launchUrlSafely(String urlString) async {
    final Uri url = Uri.parse(urlString.trim());
    try {
      bool launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        await launchUrl(url, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      print("Could not trigger system web intent launcher: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
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

                // --- UPGRADED INTERACTION SAFE ATTACHMENT LIST ---
                if (widget.topic.sourceUrl.isNotEmpty) ...[
                  const Text(
                    "Reference Attachments:",
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: widget.topic.sourceUrl
                        .split(',')
                        .where((s) => s.trim().isNotEmpty)
                        .toList()
                        .asMap()
                        .entries
                        .map((entry) {
                          int idx = entry.key;
                          String rawItem = entry.value.trim();

                          String chipTitle = 'Attachment ${idx + 1}';
                          String linkTarget = rawItem;

                          // Split metadata if separator is found
                          if (rawItem.contains('|')) {
                            final splitParts = rawItem.split('|');
                            chipTitle = splitParts[0];
                            linkTarget = splitParts[1];
                          }

                          return Theme(
                            data: ThemeData(canvasColor: Colors.transparent),
                            child: ActionChip(
                              backgroundColor: const Color(0xff2a2a2a),
                              side: const BorderSide(
                                color: Colors.blueAccent,
                                width: 0.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              label: Text(
                                chipTitle,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                              avatar: const Icon(
                                Icons.launch,
                                color: Colors.blueAccent,
                                size: 14,
                              ),
                              onPressed: () => _launchUrlSafely(linkTarget),
                            ),
                          );
                        })
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                ],

                const Text(
                  "Did you remember this well?",
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),

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
                            onPressed: () => _submitReview(false),
                            icon: const Icon(Icons.thumb_down),
                            label: const Text('Hard'),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.greenAccent,
                              foregroundColor: Colors.black,
                            ),
                            onPressed: () => _submitReview(true),
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
}
