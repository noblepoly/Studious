import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
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

  List<String> _availableSubjects = [];
  String _selectedSubject = 'All Subjects';

  List<String> _availableModules = [];
  String _selectedModule = 'All Modules';

  final Set<String> _selectedTopicIds = {};

  // --- NEW: DUAL-STATE VAULT VARIABLES ---
  bool _isProcessing =
      false; // Renamed from _isArchiving so it makes sense for both actions
  bool _isViewingArchive =
      false; // The switch that flips between Active and Archived folders

  @override
  void initState() {
    super.initState();
    _loadLibrary();
  }

  Future<void> _loadLibrary() async {
    setState(() => _isLoading = true);

    final topics = await GoogleSheetsService.fetchAllTopics();

    final subjects = topics.map((t) => t.subject).toSet().toList();
    subjects.sort();

    final modules = topics.map((t) => t.module.toString()).toSet().toList();
    modules.sort();

    setState(() {
      _allTopics = topics;

      _availableSubjects = ['All Subjects', ...subjects];
      _selectedSubject = 'All Subjects';

      _availableModules = ['All Modules', ...modules];
      _selectedModule = 'All Modules';

      _selectedTopicIds.clear();
      _isLoading = false;
    });

    // Run our new master filter so it respects the archive folder!
    _applyFilters(_selectedSubject, _selectedModule);
  }

  // --- NEW: THE MASTER FILTER ---
  void _applyFilters(String? subject, String? module) {
    setState(() {
      if (subject != null) _selectedSubject = subject;
      if (module != null) _selectedModule = module;

      _filteredTopics = _allTopics.where((t) {
        // 1. Check if the card belongs in the folder we are currently looking at
        final matchesStatus = _isViewingArchive
            ? t.status == 'archived'
            : t.status == 'active';

        // 2. Check the dropdowns
        final matchesSubject =
            _selectedSubject == 'All Subjects' || t.subject == _selectedSubject;
        final matchesModule =
            _selectedModule == 'All Modules' ||
            t.module.toString() == _selectedModule;

        return matchesStatus && matchesSubject && matchesModule;
      }).toList();
    });
  }

  // --- NEW: FOLDER TOGGLE LOGIC ---
  void _toggleVaultView() {
    setState(() {
      _isViewingArchive = !_isViewingArchive;
      _selectedTopicIds.clear(); // Drop any selections when switching rooms
      _applyFilters(_selectedSubject, _selectedModule); // Re-run the list
    });
  }

  // --- UPGRADED: MULTI-LINK HANDLER ---
  // --- UPGRADED METADATA RECOVERY PARSER ---
  Future<void> _openSourceLink(String urlString) async {
    if (urlString.isEmpty) return;

    List<String> rawItems = urlString
        .split(',')
        .where((s) => s.trim().isNotEmpty)
        .toList();
    List<Map<String, String>> parsedAttachments = [];

    for (int i = 0; i < rawItems.length; i++) {
      String item = rawItems[i].trim();
      if (item.contains('|')) {
        final dataSplit = item.split('|');
        parsedAttachments.add({'name': dataSplit[0], 'url': dataSplit[1]});
      } else {
        parsedAttachments.add({'name': 'Attachment ${i + 1}', 'url': item});
      }
    }

    if (parsedAttachments.length == 1) {
      await _launchSingleUrl(parsedAttachments.first['url']!);
    } else {
      showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xff1f1f1f),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Select Attachment',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: parsedAttachments.length,
                    itemBuilder: (context, index) {
                      final asset = parsedAttachments[index];
                      return ListTile(
                        leading: const Icon(
                          Icons.attachment,
                          color: Colors.blueAccent,
                        ),
                        title: Text(
                          asset['name']!,
                          style: const TextStyle(color: Colors.white),
                        ),
                        trailing: const Icon(
                          Icons.launch,
                          color: Colors.grey,
                          size: 16,
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _launchSingleUrl(asset['url']!);
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      );
    }
  }

  Future<void> _launchSingleUrl(String link) async {
    final Uri url = Uri.parse(link.trim());
    try {
      bool running = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!running) {
        await launchUrl(url, mode: LaunchMode.platformDefault);
      }
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

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedTopicIds.contains(id)) {
        _selectedTopicIds.remove(id);
      } else {
        _selectedTopicIds.add(id);
      }
    });
  }

  // --- NEW: BI-DIRECTIONAL CLOUD UPDATE ---
  Future<void> _processSelectedTopics() async {
    setState(() => _isProcessing = true);

    try {
      final topicsToProcess = _allTopics
          .where((t) => _selectedTopicIds.contains(t.id))
          .toList();

      // If we are looking at the archive, we want to make them active. Otherwise, archive them!
      final String newStatus = _isViewingArchive ? 'active' : 'archived';

      for (var topic in topicsToProcess) {
        Topic updatedTopic = Topic(
          id: topic.id,
          semester: topic.semester,
          subject: topic.subject,
          module: topic.module,
          topicName: topic.topicName,
          sourceUrl: topic.sourceUrl, // Corrected Variable!
          feynmanSeed: topic.feynmanSeed, // Corrected Variable!
          dateCreated: topic.dateCreated,
          nextReviewDate: topic.nextReviewDate,
          currentStage: topic.currentStage,
          status: newStatus, // Flip the switch!
        );
        await GoogleSheetsService.updateTopic(updatedTopic);
      }

      await _loadLibrary();

      if (mounted) {
        final actionWord = _isViewingArchive ? 'unarchived' : 'archived';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${topicsToProcess.length} topics $actionWord successfully!',
            ),
            backgroundColor: Colors.greenAccent,
          ),
        );
      }
    } catch (e) {
      print("Error processing topics: $e");
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isSelectionMode = _selectedTopicIds.isNotEmpty;

    return Scaffold(
      // Change background slightly if we are in the vault
      backgroundColor: _isViewingArchive
          ? const Color(0xff0a0a0a)
          : const Color(0xff121212),

      appBar: isSelectionMode
          ? AppBar(
              backgroundColor: _isViewingArchive
                  ? Colors.orangeAccent.withOpacity(0.2)
                  : Colors.blueAccent.withOpacity(0.2),
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => setState(() => _selectedTopicIds.clear()),
              ),
              title: Text(
                '${_selectedTopicIds.length} Selected',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              actions: [
                _isProcessing
                    ? const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                      )
                    : IconButton(
                        // Dynamically swap the icon!
                        icon: Icon(
                          _isViewingArchive ? Icons.unarchive : Icons.archive,
                          color: Colors.white,
                        ),
                        tooltip: _isViewingArchive
                            ? 'Unarchive Selected'
                            : 'Archive Selected',
                        onPressed: _processSelectedTopics,
                      ),
              ],
            )
          : AppBar(
              title: Text(
                _isViewingArchive ? 'Archived Vault' : 'Master Library',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              backgroundColor: const Color(0xff1f1f1f),
              elevation: 0,
              actions: [
                // The new Folder Toggle Button
                IconButton(
                  icon: Icon(
                    _isViewingArchive ? Icons.library_books : Icons.inventory_2,
                    color: _isViewingArchive
                        ? Colors.orangeAccent
                        : Colors.grey,
                  ),
                  tooltip: _isViewingArchive
                      ? 'Back to Library'
                      : 'View Archive',
                  onPressed: _toggleVaultView,
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadLibrary,
                ),
              ],
            ),

      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xff1f1f1f),
            child: Row(
              children: [
                const Icon(Icons.filter_alt, color: Colors.grey),
                const SizedBox(width: 8),
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
                      onChanged: (val) => _applyFilters(val, null),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(width: 1, height: 24, color: Colors.grey[800]),
                const SizedBox(width: 8),
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
                          child: Text(
                            module == 'All Modules' ? module : 'Mod $module',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) => _applyFilters(null, val),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.blueAccent),
                  )
                : _filteredTopics.isEmpty
                ? Center(
                    child: Text(
                      _isViewingArchive
                          ? 'No archived topics here.'
                          : 'No active topics match these filters.',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredTopics.length,
                    itemBuilder: (context, index) {
                      final topic = _filteredTopics[index];
                      final isSelected = _selectedTopicIds.contains(topic.id);

                      return Card(
                        // Give archived cards a slight visual difference so you know where you are
                        color: isSelected
                            ? (_isViewingArchive
                                  ? Colors.orangeAccent.withOpacity(0.2)
                                  : Colors.blueAccent.withOpacity(0.2))
                            : const Color(0xff1f1f1f),
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: isSelected
                              ? BorderSide(
                                  color: _isViewingArchive
                                      ? Colors.orangeAccent
                                      : Colors.blueAccent,
                                  width: 1,
                                )
                              : BorderSide.none,
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          onLongPress: () => _toggleSelection(topic.id),
                          onTap: () {
                            if (isSelectionMode) {
                              _toggleSelection(topic.id);
                            } else {
                              _openSourceLink(topic.sourceUrl);
                            }
                          },
                          leading: isSelectionMode
                              ? Checkbox(
                                  value: isSelected,
                                  activeColor: _isViewingArchive
                                      ? Colors.orangeAccent
                                      : Colors.blueAccent,
                                  onChanged: (bool? value) =>
                                      _toggleSelection(topic.id),
                                )
                              : CircleAvatar(
                                  backgroundColor:
                                      (_isViewingArchive
                                              ? Colors.orangeAccent
                                              : Colors.blueAccent)
                                          .withOpacity(0.2),
                                  child: Text(
                                    topic.module.toString(),
                                    style: TextStyle(
                                      color: _isViewingArchive
                                          ? Colors.orangeAccent
                                          : Colors.blueAccent,
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
                                  style: TextStyle(
                                    color: _isViewingArchive
                                        ? Colors.orangeAccent
                                        : Colors.blueAccent,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          trailing: _isViewingArchive
                              ? const Icon(
                                  Icons.archive,
                                  color: Colors.orangeAccent,
                                  size: 20,
                                )
                              : const Icon(
                                  Icons.check_circle,
                                  color: Colors.greenAccent,
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
