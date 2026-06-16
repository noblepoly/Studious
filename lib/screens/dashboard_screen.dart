import 'cram_setup_screen.dart';
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
    try {
      final topics = await GoogleSheetsService.fetchAllTopics();
      _allTopics = topics.where((t) => t.status == 'active').toList();

      final now = DateTime.now();
      // Reset the time to midnight so we strictly compare days
      final today = DateTime(now.year, now.month, now.day);

      // THE NEW CAP: 7 days from today
      final nextWeek = today.add(const Duration(days: 7));

      setState(() {
        _dueTopics = topics.where((t) {
          final reviewDate = DateTime(
            t.nextReviewDate.year,
            t.nextReviewDate.month,
            t.nextReviewDate.day,
          );
          // THE FIX: Check if it is 'active' AND due today/past
          return t.status == 'active' &&
              (reviewDate.isBefore(today) ||
                  reviewDate.isAtSameMomentAs(today));
        }).toList();

        _futureTopics = topics.where((t) {
          final reviewDate = DateTime(
            t.nextReviewDate.year,
            t.nextReviewDate.month,
            t.nextReviewDate.day,
          );
          // THE FIX: Check if it is 'active' AND due in the next week
          return t.status == 'active' &&
              reviewDate.isAfter(today) &&
              reviewDate.isBefore(nextWeek);
        }).toList();

        // Sort both lists so the most urgent ones are at the top
        _dueTopics.sort((a, b) => a.nextReviewDate.compareTo(b.nextReviewDate));
        _futureTopics.sort(
          (a, b) => a.nextReviewDate.compareTo(b.nextReviewDate),
        );
      });
    } catch (e) {
      print("Error loading dashboard: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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

                  // --- THE NEW CRAM MODE LAUNCHER ---
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CramSetupScreen(),
                        ),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xffff8a00), Color(0xffe52e71)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orangeAccent.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.local_fire_department,
                            color: Colors.white,
                            size: 32,
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Exam Cram Mode',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Review your topics for exam.',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.white,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
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
