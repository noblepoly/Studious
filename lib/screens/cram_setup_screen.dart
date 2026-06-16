import 'cram_arena_screen.dart';
import 'package:flutter/material.dart';
import '../services/google_sheets_service.dart';
import '../models/topic.dart';
// import 'cram_arena_screen.dart'; // We will uncomment this in Phase 2!

class CramSetupScreen extends StatefulWidget {
  const CramSetupScreen({super.key});

  @override
  State<CramSetupScreen> createState() => _CramSetupScreenState();
}

class _CramSetupScreenState extends State<CramSetupScreen> {
  List<Topic> _allTopics = [];
  bool _isLoading = true;

  List<String> _subjects = [];
  String? _selectedSubject;

  List<String> _availableModules = [];
  final Set<String> _selectedModules = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final topics = await GoogleSheetsService.fetchAllTopics();

      // We only want to cram 'active' topics!
      _allTopics = topics.where((t) => t.status == 'active').toList();

      final subjects = _allTopics.map((t) => t.subject).toSet().toList();
      subjects.sort();

      setState(() {
        _subjects = subjects;
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading setup data: $e");
      setState(() => _isLoading = false);
    }
  }

  // When you pick a subject, dynamically find all its modules!
  void _onSubjectSelected(String? subject) {
    if (subject == null) return;

    final modules = _allTopics
        .where((t) => t.subject == subject)
        .map((t) => t.module.toString())
        .toSet()
        .toList();

    modules.sort();

    setState(() {
      _selectedSubject = subject;
      _availableModules = modules;
      _selectedModules.clear(); // Reset checkboxes if subject changes
    });
  }

  void _toggleModule(String module, bool? isChecked) {
    setState(() {
      if (isChecked == true) {
        _selectedModules.add(module);
      } else {
        _selectedModules.remove(module);
      }
    });
  }

  void _startCramSession() {
    if (_selectedSubject == null || _selectedModules.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a subject and at least one module!'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // Filter the final deck to send to the Arena!
    final cramDeck = _allTopics.where((t) {
      return t.subject == _selectedSubject &&
          _selectedModules.contains(t.module.toString());
    }).toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            CramArenaScreen(subject: _selectedSubject!, deck: cramDeck),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff121212),
      appBar: AppBar(
        title: const Text(
          'Exam Cram Setup',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xff1f1f1f),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.orangeAccent),
            )
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '1. Select Subject',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xff1f1f1f),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        dropdownColor: const Color(0xff2a2a2a),
                        value: _selectedSubject,
                        hint: const Text(
                          'Choose a subject...',
                          style: TextStyle(color: Colors.grey),
                        ),
                        isExpanded: true,
                        icon: const Icon(
                          Icons.arrow_drop_down,
                          color: Colors.orangeAccent,
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                        items: _subjects.map((String sub) {
                          return DropdownMenuItem<String>(
                            value: sub,
                            child: Text(sub),
                          );
                        }).toList(),
                        onChanged: _onSubjectSelected,
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  if (_selectedSubject != null) ...[
                    const Text(
                      '2. Select Modules',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _availableModules.length,
                        itemBuilder: (context, index) {
                          final module = _availableModules[index];

                          // --- THE FIX: Wrap the CheckboxListTile in a Container ---
                          return Container(
                            // Apply the margin here to separate the items
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xff1f1f1f),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: CheckboxListTile(
                              title: Text(
                                'Module $module',
                                style: const TextStyle(color: Colors.white),
                              ),
                              activeColor: Colors.orangeAccent,
                              checkColor: Colors.black,

                              // Note: We removed tileColor, shape, and contentPadding
                              // from here as they conflict or are redundant with the Container's styling.
                              // Container handles the background and radius now.
                              value: _selectedModules.contains(module),
                              onChanged: (val) => _toggleModule(module, val),
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // The big launch button
                  ElevatedButton.icon(
                    onPressed: _startCramSession,
                    icon: const Icon(Icons.bolt, color: Colors.black),
                    label: const Text(
                      'INITIALIZE CRAM ENGINE',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orangeAccent,
                      foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 60),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
