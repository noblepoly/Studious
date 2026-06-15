import 'library_screen.dart';
import 'capture_screen.dart';
import 'dashboard_screen.dart';
import 'package:flutter/material.dart';

class MainNavigationHub extends StatefulWidget {
  const MainNavigationHub({super.key});

  @override
  State<MainNavigationHub> createState() => _MainNavigationHubState();
}

class _MainNavigationHubState extends State<MainNavigationHub> {
  // Tracks which tab is currently active (Defaults to 0: Dashboard)
  int _selectedIndex = 0;

  // These are temporary placeholder screens.
  // We will replace these with the actual UI screens in Features 6.2, 6.3, and 6.4!
  final List<Widget> _pages = [
    const DashboardScreen(), // Look! Tab 1 is now real!
    const CaptureScreen(), //Tab 2 is now real!
    const LibraryScreen(), //Tab 3 is now real!
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index; // Changes the screen when a tab is tapped
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff121212), // Dark mode background
      body: _pages[_selectedIndex], // Displays the currently selected page
      // The Lower Navigation Bar Component Block (Micro-task 6.1.1)
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xff1f1f1f),
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            label: 'Capture',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.library_books),
            label: 'Library',
          ),
        ],
      ),
    );
  }
}
