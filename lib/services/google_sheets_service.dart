import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:http/http.dart' as http;
import '../models/topic.dart'; // Imports your data structure

// 1. The HTTP Client Wrapper (Built yesterday)
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
  // 2. Define the permissions
  static final _googleSignIn = GoogleSignIn(
    scopes: [
      sheets.SheetsApi.spreadsheetsScope,
      'https://www.googleapis.com/auth/drive.file',
    ],
  );

  // 3. Your specific database ID
  // Make sure to paste your actual Google Sheet ID here!
  static final String _spreadsheetId = dotenv.env['SPREADSHEET_ID']!;

  static sheets.SheetsApi? _sheetsApi;

  // 4. The Login & Initialization Function (Built yesterday)
  static Future<void> init() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        print("Login Aborted: User closed the prompt.");
        return;
      }

      final authHeaders = await account.authHeaders;
      final authClient = GoogleAuthClient(authHeaders);

      _sheetsApi = sheets.SheetsApi(authClient);
      print("SUCCESS: Connected to Google Sheets as ${account.email}");
    } catch (e) {
      print("CRITICAL ERROR: Could not connect to Google Sheets -> $e");
    }
  }

  // --- NEW PHASE 4 CRUD METHODS ---

  // Micro-task 4.1.2: Fetch all topics from the cloud
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

  // Micro-task 4.1.3a: Save a new flashcard to the cloud
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

  // Micro-task 4.1.3b: Update an existing flashcard
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
