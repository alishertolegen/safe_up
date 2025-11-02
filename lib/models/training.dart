// lib/models/training.dart
class Training {
  final String id;
  final String title;
  final String type;
  final String location;
  final String difficulty;
  final DateTime createdAt;
  final double lastScorePercent;

  const Training({
    required this.id,
    required this.title,
    required this.type,
    required this.location,
    required this.difficulty,
    required this.createdAt,
    this.lastScorePercent = 0,
  });
}
