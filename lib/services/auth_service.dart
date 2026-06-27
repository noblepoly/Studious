import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // <-- Added dotenv import
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class AuthService {
  // Your Google Cloud OAuth Scopes
  static const _scopes = [
    'https://www.googleapis.com/auth/spreadsheets',
    'https://www.googleapis.com/auth/drive.file',
  ];

  // --- MOBILE CONFIGURATION ---
  static final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: _scopes);

  // --- WINDOWS DESKTOP CONFIGURATION ---
  // Safely pulling the credentials from the hidden .env file!
  static String get _windowsClientId => dotenv.env['WINDOWS_CLIENT_ID']!;
  static String get _windowsClientSecret =>
      dotenv.env['WINDOWS_CLIENT_SECRET']!;

  // Global container to hold the active credentials for the app session
  static AuthClient? desktopClient;

  /// Main entry point for login that automatically splits mobile and desktop execution paths
  static Future<bool> login() async {
    if (kIsWeb) return false;

    if (Platform.isWindows) {
      return await _loginWindows();
    } else if (Platform.isAndroid || Platform.isIOS) {
      return await _loginMobile();
    }
    return false;
  }

  /// Native Mobile Sign-In Execution
  static Future<bool> _loginMobile() async {
    try {
      final account = await _googleSignIn.signIn();
      return account != null;
    } catch (e) {
      print("Mobile Auth Error: $e");
      return false;
    }
  }

  /// Native Windows Loopback Server Sign-In Execution
  static Future<bool> _loginWindows() async {
    try {
      final id = ClientId(_windowsClientId, _windowsClientSecret);
      final prefs = await SharedPreferences.getInstance();

      // 1. CHECK THE VAULT: Do we already have a saved token from last time?
      final savedTokenStr = prefs.getString('desktop_google_token');

      if (savedTokenStr != null) {
        try {
          // We found one! Re-hydrate it into a working credential
          final credentials = AccessCredentials.fromJson(
            jsonDecode(savedTokenStr),
          );

          // Spin up a client using the saved credentials (no browser needed!)
          desktopClient = autoRefreshingClient(id, credentials, http.Client());
          print("Windows Auth: Restored session from local storage!");
          return true;
        } catch (e) {
          print(
            "Windows Auth: Saved token was expired or corrupt. Re-authenticating...",
          );
        }
      }

      // 2. THE FALLBACK: No valid token found, pop the browser open.
      final client = await clientViaUserConsent(id, _scopes, (url) async {
        final Uri uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          throw 'Could not launch authentication browser window.';
        }
      });

      // Save the validated client session globally
      desktopClient = client;

      // 3. LOCK IT IN THE VAULT: Save the fresh token to the hard drive for next time
      final tokenJson = jsonEncode(client.credentials.toJson());
      await prefs.setString('desktop_google_token', tokenJson);

      print("Windows Auth: Browser login successful! Token saved to vault.");
      return true;
    } catch (e) {
      print("Windows Desktop Auth Error: $e");
      return false;
    }
  }

  /// Standard clear-session logout
  static Future<void> logout() async {
    if (Platform.isWindows) {
      desktopClient?.close();
      desktopClient = null;

      // Wipe the vault on logout!
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('desktop_google_token');
    } else {
      await _googleSignIn.signOut();
    }
  }
}
