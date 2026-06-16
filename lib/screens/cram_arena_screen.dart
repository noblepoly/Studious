import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/topic.dart';

// --- HISTORY STATE TRACKER FOR THE UNDO BUTTON ---
enum SwipeAction { nailed, reviewed }

class CramHistory {
  final Topic topic;
  final SwipeAction action;
  CramHistory(this.topic, this.action);
}

class CramArenaScreen extends StatefulWidget {
  final String subject;
  final List<Topic> deck;

  const CramArenaScreen({super.key, required this.subject, required this.deck});

  @override
  State<CramArenaScreen> createState() => _CramArenaScreenState();
}

class _CramArenaScreenState extends State<CramArenaScreen> {
  // The Engine Lists
  final List<Topic> _activeQueue = [];
  final List<CramHistory> _historyStack = [];

  int _totalUnique = 0;
  int _completedCount = 0;
  bool _isFlipped = false;

  @override
  void initState() {
    super.initState();
    _activeQueue.addAll(widget.deck);
    _totalUnique = widget.deck.length;
  }

  // --- ENGINE LOGIC: NAILED IT ---
  void _handleNailedIt() {
    if (_activeQueue.isEmpty) return;
    setState(() {
      Topic current = _activeQueue.removeAt(0);
      _historyStack.add(CramHistory(current, SwipeAction.nailed));
      _completedCount++;
      _isFlipped = false; // Reset card for the next one
    });
  }

  // --- ENGINE LOGIC: REVIEW AGAIN (THE INFINITY LOOP) ---
  void _handleReviewAgain() {
    if (_activeQueue.isEmpty) return;
    setState(() {
      Topic current = _activeQueue.removeAt(0);
      _historyStack.add(CramHistory(current, SwipeAction.reviewed));
      _activeQueue.add(current); // Toss it to the very bottom of the deck!
      _isFlipped = false;
    });
  }

  // --- ENGINE LOGIC: UNDO THE LAST ACTION ---
  void _handleUndo() {
    if (_historyStack.isEmpty) return;
    setState(() {
      CramHistory lastAction = _historyStack.removeLast();

      if (lastAction.action == SwipeAction.nailed) {
        // If they nailed it, remove from completed, put back at the top
        _completedCount--;
        _activeQueue.insert(0, lastAction.topic);
      } else {
        // If they reviewed it, pull it from the bottom, put back at the top
        _activeQueue.removeLast();
        _activeQueue.insert(0, lastAction.topic);
      }
      _isFlipped = false; // Give them a fresh look
    });
  }

  // Safe Browser Launcher for Attachments
  Future<void> _launchUrlSafely(String urlString) async {
    final Uri url = Uri.parse(urlString.trim());
    try {
      bool launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) await launchUrl(url, mode: LaunchMode.platformDefault);
    } catch (e) {
      print("Could not launch: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    double progress = _totalUnique == 0
        ? 1.0
        : (_completedCount / _totalUnique);

    return Scaffold(
      backgroundColor: const Color(0xff121212),
      appBar: AppBar(
        title: Text(
          '${widget.subject} Cram',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xff1f1f1f),
        elevation: 0,
      ),
      body: _activeQueue.isEmpty
          ? _buildVictoryScreen()
          : _buildArena(progress),
    );
  }

  // --- UI: THE VICTORY SCREEN ---
  Widget _buildVictoryScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.workspace_premium,
            color: Colors.orangeAccent,
            size: 100,
          ),
          const SizedBox(height: 24),
          const Text(
            "Review Complete!",
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          const SizedBox(height: 48),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context); // Close Arena
              Navigator.pop(context); // Close Setup
            },
            icon: const Icon(Icons.check),
            label: const Text(
              "Return to Dashboard",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orangeAccent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  // --- UI: THE ACTIVE CRAM ARENA ---
  Widget _buildArena(double progress) {
    Topic currentCard = _activeQueue[0];

    return Column(
      children: [
        // 1. The Progress Bar & Header
        Container(
          padding: const EdgeInsets.all(16),
          color: const Color(0xff1f1f1f),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Topics Covered',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  Text(
                    '$_completedCount / $_totalUnique',
                    style: const TextStyle(
                      color: Colors.orangeAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[800],
                color: Colors.orangeAccent,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        ),

        // 2. The Instructions
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'Tap card to reveal answer. Use buttons below to sort.',
            style: TextStyle(color: Colors.blueAccent, fontSize: 12),
          ),
        ),

        // 3. The Interactive Flashcard
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _isFlipped = !_isFlipped),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              padding: const EdgeInsets.all(24),
              width: double.infinity,
              decoration: BoxDecoration(
                color: _isFlipped
                    ? const Color(0xff2a2a2a)
                    : const Color(0xff1f1f1f),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _isFlipped
                      ? Colors.orangeAccent.withOpacity(0.5)
                      : Colors.grey[800]!,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (!_isFlipped) ...[
                        // FRONT OF CARD
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Module ${currentCard.module}',
                            style: const TextStyle(
                              color: Colors.blueAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          currentCard.topicName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ] else ...[
                        // BACK OF CARD (REVEALED)
                        Text(
                          currentCard.topicName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Icon(
                          Icons.psychology,
                          color: Colors.orangeAccent,
                          size: 40,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          currentCard.feynmanSeed.isEmpty
                              ? "No Feynman seed provided."
                              : '"${currentCard.feynmanSeed}"',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontStyle: FontStyle.italic,
                            height: 1.5,
                          ),
                        ),

                        // Parse and show Attachments if any exist
                        if (currentCard.sourceUrl.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.only(top: 32, bottom: 16),
                            child: Divider(color: Colors.grey),
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: currentCard.sourceUrl
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

                                  if (rawItem.contains('|')) {
                                    final parts = rawItem.split('|');
                                    chipTitle = parts[0];
                                    linkTarget = parts[1];
                                  }

                                  return ActionChip(
                                    backgroundColor: const Color(0xff1f1f1f),
                                    side: const BorderSide(
                                      color: Colors.blueAccent,
                                      width: 0.5,
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
                                    onPressed: () =>
                                        _launchUrlSafely(linkTarget),
                                  );
                                })
                                .toList(),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // 4. The Action Control Panel
        Padding(
          padding: const EdgeInsets.only(
            left: 24,
            right: 24,
            bottom: 40,
            top: 16,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Review Again (Left)
              FloatingActionButton(
                heroTag: "btnReview",
                onPressed: _handleReviewAgain,
                backgroundColor: const Color(0xff2a2a2a),
                child: const Icon(Icons.replay, color: Colors.redAccent),
              ),

              // Undo (Center - Only active if history exists)
              IconButton(
                onPressed: _historyStack.isEmpty ? null : _handleUndo,
                icon: const Icon(Icons.undo),
                color: _historyStack.isEmpty ? Colors.grey[800] : Colors.white,
                iconSize: 32,
              ),

              // Nailed It (Right)
              FloatingActionButton.extended(
                heroTag: "btnNailed",
                onPressed: _handleNailedIt,
                backgroundColor: Colors.greenAccent,
                foregroundColor: Colors.black,
                icon: const Icon(Icons.check, size: 28),
                label: const Text(
                  'Next',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
