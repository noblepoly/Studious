import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import '../services/google_sheets_service.dart';
import '../models/topic.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<Topic> _allTopics = [];
  List<Topic> _filteredTopics = [];
  bool _isLoading = true;

  // Multi-Tiered Filter State Variables
  List<String> _availableSubjects = [];
  String _selectedSubject = 'All Subjects';

  List<String> _availableModules = [];
  String _selectedModule = 'All Modules';

  @override
  void initState() {
    super.initState();
    _loadLibrary();
  }

  Future<void> _loadLibrary() async {
    setState(() => _isLoading = true);

    final topics = await GoogleSheetsService.fetchAllTopics();

    // Extract unique subjects
    final subjects = topics.map((t) => t.subject).toSet().toList();
    subjects.sort();

    // Extract unique modules
    final modules = topics.map((t) => t.module.toString()).toSet().toList();
    modules.sort(); // Sorts them cleanly (e.g., 1, 2, 3)

    setState(() {
      _allTopics = topics;
      _filteredTopics = topics;

      _availableSubjects = ['All Subjects', ...subjects];
      _selectedSubject = 'All Subjects';

      _availableModules = ['All Modules', ...modules];
      _selectedModule = 'All Modules';

      _isLoading = false;
    });
  }

  // High-speed multi-variable filtering logic
  void _applyFilters(String? subject, String? module) {
    setState(() {
      // Update whatever dropdown the user just clicked
      if (subject != null) _selectedSubject = subject;
      if (module != null) _selectedModule = module;

      // Filter the master list through BOTH conditions
      _filteredTopics = _allTopics.where((t) {
        final matchesSubject =
            _selectedSubject == 'All Subjects' || t.subject == _selectedSubject;
        final matchesModule =
            _selectedModule == 'All Modules' ||
            t.module.toString() == _selectedModule;

        return matchesSubject &&
            matchesModule; // Only keep it if it passes both tests!
      }).toList();
    });
  }

  // Micro-task: Open the source link in the device's native browser
  Future<void> _openSourceLink(String urlString) async {
    if (urlString.isEmpty) return;

    final Uri url = Uri.parse(urlString);
    try {
      // LaunchMode.externalApplication forces it to open in Chrome/Safari instead of inside the app
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open the source link.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff121212),
      appBar: AppBar(
        title: const Text(
          'Master Library',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xff1f1f1f),
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadLibrary),
        ],
      ),
      body: Column(
        children: [
          // --- THE MULTI-TIERED FILTER BAR ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xff1f1f1f),
            child: Row(
              children: [
                const Icon(Icons.filter_alt, color: Colors.grey),
                const SizedBox(width: 8),

                // 1. Subject Dropdown (Takes up 60% of the space)
                Expanded(
                  flex: 3,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      dropdownColor: const Color(0xff2a2a2a),
                      value: _selectedSubject,
                      isExpanded: true,
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: Colors.blueAccent,
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      items: _availableSubjects.map((String subject) {
                        return DropdownMenuItem<String>(
                          value: subject,
                          child: Text(subject, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) => _applyFilters(
                        val,
                        null,
                      ), // Pass the subject, keep the module!
                    ),
                  ),
                ),

                const SizedBox(width: 8),
                Container(
                  width: 1,
                  height: 24,
                  color: Colors.grey[800],
                ), // Divider line
                const SizedBox(width: 8),

                // 2. Module Dropdown (Takes up 40% of the space)
                Expanded(
                  flex: 2,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      dropdownColor: const Color(0xff2a2a2a),
                      value: _selectedModule,
                      isExpanded: true,
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: Colors.blueAccent,
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      items: _availableModules.map((String module) {
                        return DropdownMenuItem<String>(
                          value: module,
                          // If it's a number, stick 'Mod ' in front of it so it looks clean
                          child: Text(
                            module == 'All Modules' ? module : 'Mod $module',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) => _applyFilters(
                        null,
                        val,
                      ), // Pass the module, keep the subject!
                    ),
                  ),
                ),
              ],
            ),
          ),

          // --- THE DATA GRID ---
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.blueAccent),
                  )
                : _filteredTopics.isEmpty
                ? const Center(
                    child: Text(
                      'No topics match these filters.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredTopics.length,
                    itemBuilder: (context, index) {
                      final topic = _filteredTopics[index];
                      return Card(
                        color: const Color(0xff1f1f1f),
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          // THE NEW TAP ACTION!
                          onTap: () => _openSourceLink(topic.sourceUrl),
                          leading: CircleAvatar(
                            backgroundColor: Colors.blueAccent.withOpacity(0.2),
                            child: Text(
                              topic.module.toString(),
                              style: const TextStyle(
                                color: Colors.blueAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            topic.topicName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${topic.subject} • Semester ${topic.semester}',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Stage: ${topic.currentStage} | Next Review: ${topic.nextReviewDate.toString().split(' ')[0]}',
                                  style: const TextStyle(
                                    color: Colors.blueAccent,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          trailing: topic.status == 'active'
                              ? const Icon(
                                  Icons.check_circle,
                                  color: Colors.greenAccent,
                                  size: 20,
                                )
                              : const Icon(
                                  Icons.archive,
                                  color: Colors.grey,
                                  size: 20,
                                ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
