class Topic {
  final String id;
  final String semester;
  final String subject;
  final String module;
  final String topicName;
  final String sourceUrl;
  final String feynmanSeed;
  final DateTime dateCreated;
  final DateTime nextReviewDate;
  final int currentStage;
  final String status;

  Topic({
    required this.id,
    required this.semester,
    required this.subject,
    required this.module,
    required this.topicName,
    required this.sourceUrl,
    required this.feynmanSeed,
    required this.dateCreated,
    required this.nextReviewDate,
    required this.currentStage,
    required this.status,
  });

  // This function converts a row from your Google Sheet into a Dart object
  factory Topic.fromList(List<dynamic> row) {
    return Topic(
      id: row[0].toString(),
      semester: row[1].toString(),
      subject: row[2].toString(),
      module: row[3].toString(),
      topicName: row[4].toString(),
      sourceUrl: row[5].toString(),
      feynmanSeed: row[6].toString(),
      dateCreated: DateTime.parse(row[7].toString()),
      nextReviewDate: DateTime.parse(row[8].toString()),
      currentStage: int.tryParse(row[9].toString()) ?? 1,
      status: row[10].toString(),
    );
  }

  // This function converts a Dart object back into a row for your Google Sheet
  List<dynamic> toList() {
    return [
      id,
      semester,
      subject,
      module,
      topicName,
      sourceUrl,
      feynmanSeed,
      dateCreated.toIso8601String(),
      nextReviewDate.toIso8601String(),
      currentStage,
      status,
    ];
  }
}
