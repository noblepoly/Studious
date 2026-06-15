import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../services/settings_service.dart';
import '../services/google_sheets_service.dart';
import '../services/google_drive_service.dart';
import '../models/topic.dart';

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _moduleController = TextEditingController();
  final TextEditingController _topicNameController = TextEditingController();
  final TextEditingController _feynmanController = TextEditingController();

  String _activeSemester = 'Loading...';

  // --- UPGRADED: MAP ATTACHMENT STRUCTURE ---
  List<Map<String, dynamic>> _attachments = [];
  int _photoCount = 0; // Tracks photo increments dynamically
  bool _isPicking = false;
  bool _isUploading = false;

  final ImagePicker _cameraPicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _activeSemester = SettingsService.getActiveSemester();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _moduleController.dispose();
    _topicNameController.dispose();
    _feynmanController.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    setState(() => _isPicking = true);
    try {
      final XFile? photo = await _cameraPicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
      if (photo != null) {
        _photoCount++;
        setState(() {
          _attachments.add({
            'file': File(photo.path),
            'name': 'Photo $_photoCount',
          });
        });
      }
    } catch (e) {
      print("Camera error: $e");
    } finally {
      setState(() => _isPicking = false);
    }
  }

  Future<void> _pickFiles() async {
    setState(() => _isPicking = true);
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['jpg', 'png', 'jpeg', 'pdf'],
      );

      if (result != null) {
        setState(() {
          for (var filePlatform in result.files) {
            if (filePlatform.path != null) {
              _attachments.add({
                'file': File(filePlatform.path!),
                'name': filePlatform.name, // Grabs the exact native file name!
              });
            }
          }
        });
      }
    } catch (e) {
      print("File picker error: $e");
    } finally {
      setState(() => _isPicking = false);
    }
  }

  void _removeAttachment(int index) {
    setState(() {
      _attachments.removeAt(index);
      if (_attachments.isEmpty)
        _photoCount = 0; // Reset counter if tray cleared
    });
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      if (_attachments.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please attach at least one reference file or photo!',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      setState(() => _isUploading = true);

      try {
        List<String> serializedPairs = [];

        for (int i = 0; i < _attachments.length; i++) {
          File file = _attachments[i]['file'];
          // Cleans the name so commas or pipes in a PDF name don't break our database!
          String displayName = _attachments[i]['name']
              .toString()
              .replaceAll(',', '_')
              .replaceAll('|', '_');

          String extension = file.path.split('.').last;
          String cloudSecureName =
              'topic_${DateTime.now().millisecondsSinceEpoch}_$i.$extension';

          String? url = await GoogleDriveService.uploadMediaFile(
            file,
            cloudSecureName,
          );
          if (url != null && url.isNotEmpty) {
            // Serialize structural pairing metadata with vertical divider
            serializedPairs.add('$displayName|$url');
          }
        }

        if (serializedPairs.isEmpty)
          throw Exception("Failed to upload assets to Drive.");

        String combinedLinks = serializedPairs.join(',');

        Topic newTopic = Topic(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          semester: _activeSemester,
          subject: _subjectController.text,
          module: _moduleController.text,
          topicName: _topicNameController.text,
          sourceUrl: combinedLinks,
          feynmanSeed: _feynmanController.text,
          dateCreated: DateTime.now(),
          nextReviewDate: DateTime.now(),
          currentStage: 1,
          status: 'active',
        );

        await GoogleSheetsService.saveNewTopic(newTopic);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Topic and attachments saved!'),
              backgroundColor: Colors.greenAccent,
            ),
          );

          _subjectController.clear();
          _moduleController.clear();
          _topicNameController.clear();
          _feynmanController.clear();
          setState(() {
            _attachments.clear();
            _photoCount = 0;
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Upload failed: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff121212),
      appBar: AppBar(
        title: const Text(
          'Add New Topic',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xff1f1f1f),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.folder_shared, color: Colors.blueAccent),
                    const SizedBox(width: 12),
                    Text(
                      'Saving to: Semester $_activeSemester',
                      style: const TextStyle(
                        color: Colors.blueAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildTextField(
                      _subjectController,
                      'Subject (e.g. ECES3)',
                      Icons.book,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 1,
                    child: _buildTextField(
                      _moduleController,
                      'Mod #',
                      Icons.numbers,
                      isNumber: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildTextField(_topicNameController, 'Topic Title', Icons.title),
              const SizedBox(height: 16),
              _buildTextField(
                _feynmanController,
                'Feynman Summary (Explain it simply...)',
                Icons.psychology,
                maxLines: 3,
                isRequired: false,
              ),
              const SizedBox(height: 24),

              const Text(
                "Source Material",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),

              if (_attachments.isNotEmpty) ...[
                SizedBox(
                  height:
                      130, // Tall enough to hold thumbnails and labels below them cleanly
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _attachments.length,
                    itemBuilder: (context, index) {
                      File file = _attachments[index]['file'];
                      String name = _attachments[index]['name'];
                      bool isPdf = file.path.toLowerCase().endsWith('.pdf');

                      return Container(
                        width: 100,
                        margin: const EdgeInsets.only(right: 12),
                        child: Column(
                          children: [
                            Expanded(
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: isPdf
                                          ? Container(
                                              color: const Color(0xff1f1f1f),
                                              child: const Center(
                                                child: Icon(
                                                  Icons.picture_as_pdf,
                                                  color: Colors.redAccent,
                                                  size: 40,
                                                ),
                                              ),
                                            )
                                          : Image.file(file, fit: BoxFit.cover),
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () => _removeAttachment(index),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.black87,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              name,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isPicking ? null : _takePhoto,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Camera'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.grey[800]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isPicking ? null : _pickFiles,
                      icon: const Icon(Icons.folder),
                      label: const Text('Gallery / PDF'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.grey[800]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              _isUploading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Colors.blueAccent,
                      ),
                    )
                  : ElevatedButton(
                      onPressed: _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Upload ${_attachments.isEmpty ? '' : '(${_attachments.length})'} & Save Topic',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool isNumber = false,
    int maxLines = 1,
    bool isRequired = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: Colors.grey),
        filled: true,
        fillColor: const Color(0xff1f1f1f),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      validator: (value) {
        if (isRequired && (value == null || value.isEmpty))
          return 'Please enter a value';
        return null;
      },
    );
  }
}
