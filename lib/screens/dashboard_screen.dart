import '../widgets/flashcard_dialog.dart';
import 'package:flutter/material.dart';
import '../services/google_sheets_service.dart';
import '../models/topic.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Topic> _allTopics = [];
  List<Topic> _dueTopics = [];
  List<Topic> _futureTopics = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  // Fetches data and sorts it into buckets (Micro-task 6.2.2)
  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    final cloudTopics = await GoogleSheetsService.fetchAllTopics();

    // Sort logic: Get today's pure calendar date at midnight
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    List<Topic> due = [];
    List<Topic> future = [];

    for (var topic in cloudTopics) {
      // If the review date is today or in the past, it's due!
      if (topic.nextReviewDate.isBefore(today) ||
          topic.nextReviewDate.isAtSameMomentAs(today)) {
        due.add(topic);
      } else {
        future.add(topic);
      }
    }

    setState(() {
      _allTopics = cloudTopics;
      _dueTopics = due;
      _futureTopics = future;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Calculate Health Bar Math (Micro-task 6.2.1)
    double healthPercentage = 1.0;
    if (_allTopics.isNotEmpty) {
      int completed = _allTopics.length - _dueTopics.length;
      healthPercentage = completed / _allTopics.length;
    }

    return Scaffold(
      backgroundColor: const Color(0xff121212),
      appBar: AppBar(
        title: const Text(
          'Daily Study Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xff1f1f1f),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.blueAccent),
            )
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              color: Colors.blueAccent,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // --- THE HEALTH BAR (Micro-task 6.2.1) ---
                  const Text(
                    'Daily Study Health',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: healthPercentage,
                    backgroundColor: Colors.grey[800],
                    // Dynamically changes color based on progress!
                    color: healthPercentage > 0.8
                        ? Colors.greenAccent
                        : (healthPercentage > 0.4
                              ? Colors.orangeAccent
                              : Colors.redAccent),
                    minHeight: 12,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(healthPercentage * 100).toStringAsFixed(0)}% Mastered',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 32),

                  // --- DUE TODAY BASKET (Micro-task 6.2.2) ---
                  const Text(
                    'Needs Review',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_dueTopics.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Text(
                        'All caught up for today! Great job.',
                        style: TextStyle(color: Colors.greenAccent),
                      ),
                    ),
                  ..._dueTopics.map(
                    (topic) => Card(
                      color: const Color(0xff1f1f1f),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(
                          topic.topicName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          '${topic.subject} • Stage ${topic.currentStage}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        trailing: const Icon(
                          Icons.play_circle_fill,
                          color: Colors.blueAccent,
                          size: 32,
                        ),
                        onTap: () async {
                          // Wait for the dialog to close, and catch the signal it sends back
                          final didUpdate = await showDialog<bool>(
                            context: context,
                            builder: (context) => FlashcardDialog(topic: topic),
                          );
                          // If the user clicked Easy or Hard, refresh the lists!
                          if (didUpdate == true) {
                            _loadDashboardData();
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // --- UPCOMING BASKET ---
                  const Text(
                    'Upcoming',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._futureTopics.map(
                    (topic) => Card(
                      color: const Color(0xff1f1f1f),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(
                          topic.topicName,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          'Due: ${topic.nextReviewDate.toString().split(' ')[0]}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
