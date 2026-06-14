import 'dart:io';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

// 1. Re-use the HTTP Client Wrapper for Authentication
class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}

class GoogleDriveService {
  // Grab the hidden Folder ID we just set up
  static final String _folderId = dotenv.env['DRIVE_FOLDER_ID']!;

  // Micro-task 4.2.2: Stream physical device files up to the cloud
  static Future<String?> uploadMediaFile(
    File imageFile,
    String fileName,
  ) async {
    try {
      // 1. Grab the user who is already logged in from the Sheets step
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final account =
          googleSignIn.currentUser ?? await googleSignIn.signInSilently();

      if (account == null) {
        print("ERROR: Cannot upload image, user is not signed in.");
        return null;
      }

      // 2. Build the secure connection to Google Drive
      final authHeaders = await account.authHeaders;
      final authClient = GoogleAuthClient(authHeaders);
      final driveApi = drive.DriveApi(authClient);

      // 3. Prepare the file instructions (Name it, and put it in the Studious_Images folder)
      final driveFile = drive.File()
        ..name = fileName
        ..parents = [_folderId];

      // 4. Read the physical bytes of the photo from your phone's storage
      final media = drive.Media(imageFile.openRead(), imageFile.lengthSync());

      // 5. Blast it up to the cloud
      final result = await driveApi.files.create(driveFile, uploadMedia: media);

      print("SUCCESS: Image uploaded to Drive! File ID: ${result.id}");

      // Return a permanently shareable web link to view the image
      if (result.id != null) {
        return 'https://drive.google.com/file/d/${result.id}/view';
      }
      return null;
    } catch (e) {
      print("CRITICAL ERROR: Failed to upload image to Drive -> $e");
      return null;
    }
  }
}
