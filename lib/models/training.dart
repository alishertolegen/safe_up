// lib/models/training.dart
class Training {
  final String id;
  final String title;
  final String summary;
  final String type;
  final LocationInfo location;
  final String difficulty;
  final bool aiGenerated;
  final AiMeta? aiMeta;
  final int? durationEstimateSec;
  final List<Scene> scenes;
  final SummaryMetrics summaryMetrics;
  final Stats stats;
  final List<String> tags;
  final List<String> assets;
  final UserSummary? createdBy;
  final bool isPublished;
  final DateTime createdAt;
  final DateTime updatedAt;

  Training({
    required this.id,
    required this.title,
    required this.summary,
    required this.type,
    required this.location,
    required this.difficulty,
    required this.aiGenerated,
    this.aiMeta,
    this.durationEstimateSec,
    required this.scenes,
    required this.summaryMetrics,
    required this.stats,
    required this.tags,
    required this.assets,
    this.createdBy,
    required this.isPublished,
    required this.createdAt,
    required this.updatedAt,
  });

  double get lastScorePercent {
    // например: successes / attempts * 100 (защита от деления на ноль)
    if (stats.attempts == 0) return 0;
    return (stats.successes / stats.attempts) * 100;
  }

  factory Training.fromJson(Map<String, dynamic> json) {
    return Training(
      id: json['_id']?.toString() ?? '',
      title: (json['title'] ?? '') as String,
      summary: (json['summary'] ?? '') as String,
      type: (json['type'] ?? '') as String,
      location: LocationInfo.fromJson(json['location'] ?? {}),
      difficulty: (json['difficulty'] ?? 'medium') as String,
      aiGenerated: (json['aiGenerated'] ?? false) as bool,
      aiMeta: json['aiMeta'] != null ? AiMeta.fromJson(json['aiMeta']) : null,
      durationEstimateSec: json['durationEstimateSec'] != null ? (json['durationEstimateSec'] as num).toInt() : null,
      scenes: (json['scenes'] as List<dynamic>?)
              ?.map((e) => Scene.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      summaryMetrics: SummaryMetrics.fromJson(json['summaryMetrics'] ?? {}),
      stats: Stats.fromJson(json['stats'] ?? {}),
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      assets: (json['assets'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      createdBy: json['createdBy'] != null ? UserSummary.fromPossible(json['createdBy']) : null,
      isPublished: (json['isPublished'] ?? false) as bool,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class LocationInfo {
  final String name;
  final String floor;
  final String extra;
  const LocationInfo({required this.name, required this.floor, required this.extra});
  factory LocationInfo.fromJson(Map<String, dynamic> json) {
    return LocationInfo(
      name: (json['name'] ?? '') as String,
      floor: (json['floor'] ?? '') as String,
      extra: (json['extra'] ?? '') as String,
    );
  }
}

class AiMeta {
  final String? model;
  final String? promptSeed;
  final String? version;
  AiMeta({this.model, this.promptSeed, this.version});
  factory AiMeta.fromJson(Map<String, dynamic> json) {
    return AiMeta(
      model: json['model']?.toString(),
      promptSeed: json['promptSeed']?.toString(),
      version: json['version']?.toString(),
    );
  }
}

class SummaryMetrics {
  final int totalChoices;
  SummaryMetrics({required this.totalChoices});
  factory SummaryMetrics.fromJson(Map<String, dynamic> json) {
    return SummaryMetrics(totalChoices: (json['totalChoices'] ?? 0) as int);
  }
}

class Stats {
  final int attempts;
  final int successes;
  final int avgTimeSec;
  Stats({required this.attempts, required this.successes, required this.avgTimeSec});
  factory Stats.fromJson(Map<String, dynamic> json) {
    return Stats(
      attempts: (json['attempts'] ?? 0) as int,
      successes: (json['successes'] ?? 0) as int,
      avgTimeSec: (json['avgTimeSec'] ?? 0) as int,
    );
  }
}

class UserSummary {
  final String id;
  final String? username;
  final String? email;
  UserSummary({required this.id, this.username, this.email});
  factory UserSummary.fromPossible(dynamic data) {
    // data может быть только id (ObjectId как строка) или populated object
    if (data is String) return UserSummary(id: data);
    if (data is Map<String, dynamic> || data is Map) {
      final m = Map<String, dynamic>.from(data as Map);
      return UserSummary(
        id: (m['_id']?.toString() ?? m['id']?.toString() ?? '') as String,
        username: m['username']?.toString(),
        email: m['email']?.toString(),
      );
    }
    return UserSummary(id: data.toString());
  }
}

class Scene {
  final int id;
  final String title;
  final String description;
  final String hint;
  final List<Choice> choices;
  final String defaultChoiceId;

  Scene({
    required this.id,
    required this.title,
    required this.description,
    required this.hint,
    required this.choices,
    required this.defaultChoiceId,
  });

  factory Scene.fromJson(Map<String, dynamic> json) {
    return Scene(
      id: (json['id'] is num) ? (json['id'] as num).toInt() : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      title: (json['title'] ?? '') as String,
      description: (json['description'] ?? '') as String,
      hint: (json['hint'] ?? '') as String,
      choices: (json['choices'] as List<dynamic>?)
              ?.map((c) => Choice.fromJson(Map<String, dynamic>.from(c as Map)))
              .toList() ??
          [],
      defaultChoiceId: (json['defaultChoiceId'] ?? 'a') as String,
    );
  }
}

class Choice {
  final String id;
  final String text;
  final String consequenceType;
  final String consequenceText;
  final int scoreDelta;
  Choice({
    required this.id,
    required this.text,
    required this.consequenceType,
    required this.consequenceText,
    required this.scoreDelta,
  });
  factory Choice.fromJson(Map<String, dynamic> json) {
    return Choice(
      id: (json['id']?.toString() ?? 'a'),
      text: (json['text'] ?? '') as String,
      consequenceType: (json['consequenceType'] ?? 'neutral') as String,
      consequenceText: (json['consequenceText'] ?? '') as String,
      scoreDelta: (json['scoreDelta'] ?? 0) is int ? (json['scoreDelta'] as int) : (json['scoreDelta'] as num).toInt(),
    );
  }
}
