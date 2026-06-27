import 'package:home_widget/home_widget.dart';

class WidgetService {
  // THE FIX: Added "Receiver" to exactly match the Kotlin file!
  static const String _androidWidgetName = 'StudyHealthWidgetReceiver';

  static Future<void> updateHealthWidget(int percentage) async {
    try {
      await HomeWidget.saveWidgetData<int>('health_progress', percentage);

      // We also specifically use the androidName parameter here to be safe
      await HomeWidget.updateWidget(androidName: _androidWidgetName);
      print("SUCCESS: Fired $percentage% to Home Screen!");
    } catch (e) {
      print("Failed to update widget: $e");
    }
  }
}
