import 'dart:io'; // Needed to check Platform.isWindows
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:http/http.dart' as http;
import '../models/topic.dart';
import 'auth_service.dart'; // Brings in your new Desktop Loopback keys!

// 1. The HTTP Client Wrapper
class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}

class GoogleSheetsService {
  // 2. Define the permissions (Used as the Mobile Fallback)
  static final _googleSignIn = GoogleSignIn(
    clientId:
        '126899395997-t4fdnl9odrlt87l5amtcouksejdqodsf.apps.googleusercontent.com',
    scopes: [
      sheets.SheetsApi.spreadsheetsScope,
      'https://www.googleapis.com/auth/drive.file',
    ],
  );

  // 3. Your specific database ID
  static final String _spreadsheetId = dotenv.env['SPREADSHEET_ID']!;

  static sheets.SheetsApi? _sheetsApi;

  // --- THE NEW TRAFFIC COP ---
  static Future<http.Client?> _getAuthenticatedClient() async {
    if (Platform.isWindows) {
      // Windows uses the global Loopback token we caught in AuthService
      return AuthService.desktopClient;
    } else {
      // Mobile checks for the active session, or silently syncs it
      var user =
          _googleSignIn.currentUser ?? await _googleSignIn.signInSilently();

      final headers = await user?.authHeaders;
      if (headers == null) {
        print("Error: Mobile headers are null. User might not be logged in.");
        return null;
      }
      return GoogleAuthClient(headers);
    }
  }

  // 4. The Login & Initialization Function (UPDATED)
  static Future<void> init() async {
    try {
      // Ask the traffic cop for the correct cross-platform keys
      final client = await _getAuthenticatedClient();

      if (client == null) {
        print("CRITICAL ERROR: No valid auth token found for database!");
        return;
      }

      // Initialize the APIs using the universal client
      _sheetsApi = sheets.SheetsApi(client);
      print("SUCCESS: Connected to Google Sheets across all platforms!");
    } catch (e) {
      print("CRITICAL ERROR: Could not connect to Google Sheets -> $e");
    }
  }

  // --- CRUD METHODS (These remain exactly the same!) ---

  static Future<List<Topic>> fetchAllTopics() async {
    if (_sheetsApi == null) return [];

    try {
      final response = await _sheetsApi!.spreadsheets.values.get(
        _spreadsheetId,
        'Sheet1!A2:K',
      );

      final rows = response.values ?? [];
      return rows.map((row) => Topic.fromList(row)).toList();
    } catch (e) {
      print("Error fetching topics: $e");
      return [];
    }
  }

  static Future<void> saveNewTopic(Topic topic) async {
    if (_sheetsApi == null) return;

    try {
      final valueRange = sheets.ValueRange(values: [topic.toList()]);

      await _sheetsApi!.spreadsheets.values.append(
        valueRange,
        _spreadsheetId,
        'Sheet1!A:K',
        valueInputOption: 'USER_ENTERED',
      );
      print("SUCCESS: Saved '${topic.topicName}' to cloud.");
    } catch (e) {
      print("Error saving new topic: $e");
    }
  }

  static Future<void> updateTopic(Topic updatedTopic) async {
    if (_sheetsApi == null) return;

    try {
      final response = await _sheetsApi!.spreadsheets.values.get(
        _spreadsheetId,
        'Sheet1!A:A',
      );

      final rows = response.values ?? [];
      int rowIndex = -1;

      for (int i = 0; i < rows.length; i++) {
        if (rows[i].isNotEmpty && rows[i][0] == updatedTopic.id) {
          rowIndex = i + 1;
          break;
        }
      }

      if (rowIndex == -1) {
        print("ERROR: Topic ID not found in database.");
        return;
      }

      final valueRange = sheets.ValueRange(values: [updatedTopic.toList()]);

      await _sheetsApi!.spreadsheets.values.update(
        valueRange,
        _spreadsheetId,
        'Sheet1!A$rowIndex:K$rowIndex',
        valueInputOption: 'USER_ENTERED',
      );
      print("SUCCESS: Updated '${updatedTopic.topicName}' in cloud.");
    } catch (e) {
      print("Error updating topic: $e");
    }
  }
}
