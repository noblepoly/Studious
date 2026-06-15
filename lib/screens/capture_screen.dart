import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/settings_service.dart';
import '../services/google_sheets_service.dart';
import '../services/google_drive_service.dart'; // From Phase 4!
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

  // Micro-task 6.3.3: Variable to hold the physical file path
  File? _selectedImage;
  bool _isPicking = false;
  bool _isUploading = false;

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

  // Micro-task 6.3.3: Native hardware file picker trigger
  Future<void> _pickImage() async {
    setState(() => _isPicking = true);

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image, // Restrict selection to photos only
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedImage = File(result.files.single.path!);
        });
        print("SUCCESS: File captured at path -> ${_selectedImage!.path}");
      } else {
        print("User canceled the picker.");
      }
    } catch (e) {
      print("ERROR: Failed to open system file selector -> $e");
    } finally {
      setState(() => _isPicking = false);
    }
  }

  // Micro-task 6.3.4: The Background Upload Chain
  Future<void> _submitForm() async {
    // 1. Check if all text boxes are filled and an image is selected
    if (_formKey.currentState!.validate()) {
      if (_selectedImage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please attach a reference image of your notes first!',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      // 2. Lock the UI and show loading spinner
      setState(() => _isUploading = true);

      try {
        // 1. Generate a unique file name for Google Drive
        String fileName =
            'topic_img_${DateTime.now().millisecondsSinceEpoch}.jpg';

        // 2. Use YOUR exact function, pass both arguments, and accept the String? (nullable)
        String? imageUrl = await GoogleDriveService.uploadMediaFile(
          _selectedImage!,
          fileName,
        );

        // 3. Safety Check: If Drive failed to return a link, stop the process!
        if (imageUrl == null || imageUrl.isEmpty) {
          throw Exception("Google Drive failed to return a valid image link.");
        }

        // 4. Package all the data into a brand new Topic
        Topic newTopic = Topic(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          semester: _activeSemester,
          subject: _subjectController.text,
          module: _moduleController.text,
          topicName: _topicNameController.text,
          sourceUrl: imageUrl, // It is 100% safe to use here now!
          feynmanSeed: _feynmanController.text,
          dateCreated: DateTime.now(),
          nextReviewDate: DateTime.now(),
          currentStage: 1,
          status: 'active',
        );

        // 5. Push the new row to Google Sheets
        await GoogleSheetsService.saveNewTopic(newTopic);

        // 6. Success! Show a green message and wipe the form clean.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Topic saved successfully!'),
              backgroundColor: Colors.greenAccent,
            ),
          );

          _subjectController.clear();
          _moduleController.clear();
          _topicNameController.clear();
          _feynmanController.clear();
          setState(() {
            _selectedImage = null;
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
        // 7. Unlock the UI
        if (mounted) {
          setState(() => _isUploading = false);
        }
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

              // --- DYNAMIC IMAGE PICKER / PREVIEW VIEW BLOCK (6.3.3) ---
              if (_selectedImage != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 200,
                    width: double.infinity,
                    color: const Color(0xff1f1f1f),
                    child: Image.file(_selectedImage!, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.refresh, color: Colors.grey),
                  label: const Text(
                    'Change Image',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ] else ...[
                OutlinedButton.icon(
                  onPressed: _isPicking ? null : _pickImage,
                  icon: _isPicking
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.image_search),
                  label: Text(
                    _isPicking
                        ? 'Opening Gallery...'
                        : 'Attach Reference Image (Required)',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 54),
                    side: BorderSide(color: Colors.grey[700]!),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Save Topic to Database',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
        if (isRequired && (value == null || value.isEmpty)) {
          return 'Please enter a value';
        }
        return null;
      },
    );
  }
}
