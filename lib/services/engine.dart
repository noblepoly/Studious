import '../models/topic.dart';

class SpacedRepetitionEngine {
  // 1. The Core Interval Math
  static DateTime calculateNextReviewDate(int currentStage) {
    // Mathematical formula: Gap = 2^(stage - 1)
    // Stage 1 -> 1 day (Tomorrow)
    // Stage 2 -> 2 days
    // Stage 3 -> 4 days
    // Stage 4 -> 8 days

    int gapInDays = 1;
    if (currentStage > 1) {
      // Bit shifting (<<) is Dart's fastest way to calculate powers of 2
      gapInDays = 1 << (currentStage - 1);
    }

    DateTime now = DateTime.now();
    // Strip away the hours and minutes to match pure calendar dates at midnight
    DateTime pureDate = DateTime(now.year, now.month, now.day);

    return pureDate.add(Duration(days: gapInDays));
  }

  // 2. The "Easy" Button Logic
  static Topic processEasy(Topic topic) {
    int newStage = topic.currentStage + 1;
    DateTime newDate = calculateNextReviewDate(newStage);

    // Return a completely new Topic object with the upgraded stats
    return Topic(
      id: topic.id,
      semester: topic.semester,
      subject: topic.subject,
      module: topic.module,
      topicName: topic.topicName,
      sourceUrl: topic.sourceUrl,
      feynmanSeed: topic.feynmanSeed,
      dateCreated: topic.dateCreated,
      nextReviewDate: newDate, // Pushed further into the future
      currentStage: newStage, // Stage leveled up
      status: topic.status,
    );
  }

  // 3. The "Hard" Button Logic
  static Topic processHard(Topic topic) {
    // Punish the failure: Reset completely to Stage 1 (review tomorrow)
    int resetStage = 1;
    DateTime newDate = calculateNextReviewDate(resetStage);

    return Topic(
      id: topic.id,
      semester: topic.semester,
      subject: topic.subject,
      module: topic.module,
      topicName: topic.topicName,
      sourceUrl: topic.sourceUrl,
      feynmanSeed: topic.feynmanSeed,
      dateCreated: topic.dateCreated,
      nextReviewDate: newDate, // Punished back to tomorrow
      currentStage: resetStage, // Dropped to Stage 1
      status: topic.status,
    );
  }
}
