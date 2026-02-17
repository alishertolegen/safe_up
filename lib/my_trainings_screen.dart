import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/training.dart';
import 'TrainingDetailScreen.dart';

const String API_BASE = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://10.0.2.2:5000',
);

class MyTrainingsScreen extends StatefulWidget {
  
  const MyTrainingsScreen({super.key});

  @override
  State<MyTrainingsScreen> createState() => _MyTrainingsScreenState();
}

class _MyTrainingsScreenState extends State<MyTrainingsScreen> {
  late Future<List<Training>> _futureTrainings;

  // Icons for training types
  final Map<String, String> _typeIcons = {
    'пожар': '🔥',
    'землетрясение': '🌍',
    'наводнение': '🌊',
    'газовая_утечка': '💨',
    'иное': '⚠️',
  };

  // Colors for difficulty
  final Map<String, Color> _difficultyColors = {
    'easy': Colors.green,
    'medium': Colors.orange,
    'hard': Colors.red,
  };

  final Map<String, String> _difficultyLabels = {
    'easy': 'Лёгкий',
    'medium': 'Средний',
    'hard': 'Сложный',
  };

  @override
  void initState() {
    super.initState();
    _futureTrainings = _fetchTrainings();
  }

  Future<String?> _readToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<List<Training>> _fetchTrainings() async {
    
    final token = await _readToken();

    if (token == null || token.isEmpty) {
      throw Exception('Требуется авторизация. Пожалуйста, войдите в аккаунт.');
    }

    final uri = Uri.parse('$API_BASE/trainings/mine');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final res = await http.get(uri, headers: headers);

    if (res.statusCode == 401) {
      throw Exception('Неавторизован. Пожалуйста, войдите снова.');
    }
    if (res.statusCode == 403) {
      throw Exception('Доступ запрещён. Токен просрочен или некорректен.');
    }
    if (res.statusCode != 200) {
      throw Exception('Ошибка при получении тренингов: ${res.statusCode} ${res.body}');
    }

    final List<dynamic> data = json.decode(res.body) as List<dynamic>;
    final list = data
        .where((e) => e is Map<String, dynamic> || e is Map)
        .map<Training>((e) => Training.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    
    return list;
  }

  Future<void> _refresh() async {
    setState(() {
      _futureTrainings = _fetchTrainings();
    });
    await _futureTrainings;
  }

  void _openDetail(BuildContext context, Training t) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TrainingDetailScreen(training: t)),
    );
  }

  String _getTypeIcon(String type) {
    return _typeIcons[type.toLowerCase()] ?? '⚠️';
  }

  Color _getDifficultyColor(String difficulty) {
    return _difficultyColors[difficulty.toLowerCase()] ?? Colors.grey;
  }

  String _getDifficultyLabel(String difficulty) {
    return _difficultyLabels[difficulty.toLowerCase()] ?? difficulty;
  }
  int _getSuccesses(Training t) {
  final dyn = t as dynamic;
  try {
    final s1 = dyn.successes;
    if (s1 is int) return s1;
    if (s1 is double) return s1.toInt();
    if (s1 is String) return int.tryParse(s1) ?? 0;
  } catch (_) {}

  try {
    final stats = dyn.stats;
    if (stats != null) {
      if (stats is Map) {
        final s2 = stats['successes'] ?? stats['success'] ?? stats['success_count'];
        if (s2 is int) return s2;
        if (s2 is double) return s2.toInt();
        if (s2 is String) return int.tryParse(s2) ?? 0;
      } else {
        final s3 = (stats as dynamic).successes;
        if (s3 is int) return s3;
        if (s3 is double) return s3.toInt();
        if (s3 is String) return int.tryParse(s3) ?? 0;
      }
    }
  } catch (_) {}

  return 0;
}

double _displayPercent(Training t) {
  // Если есть хотя бы 1 успех — зафиксировать 100% и не парсить дальше
  final succ = _getSuccesses(t);
  if (succ >= 1) return 100.0;

  // Иначе — взять последний известный процент безопасно (поддерживаем разные имена)
  final dyn = t as dynamic;
  try {
    final cand = dyn.lastScorePercent ?? dyn.last_score_percent ?? dyn.lastScore ?? dyn.scorePercent;
    if (cand is num) return (cand).toDouble();
    if (cand is String) return double.tryParse(cand) ?? 0.0;
  } catch (_) {}

  return 0.0;
}


  Widget _buildTrainingCard(Training t) {
    final locName = t.location.name.isNotEmpty 
        ? t.location.name 
        : (t.location.floor.isNotEmpty ? t.location.floor : 'Без локации');
    final dateStr = '${t.createdAt.day.toString().padLeft(2, '0')}.${t.createdAt.month.toString().padLeft(2, '0')}.${t.createdAt.year}';
    final displayPercent = _displayPercent(t);
final scorePercent = displayPercent.toStringAsFixed(0);
final difficultyColor = _getDifficultyColor(t.difficulty);
final difficultyLabel = _getDifficultyLabel(t.difficulty);


    return InkWell(
      onTap: () => _openDetail(context, t),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Type icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      _getTypeIcon(t.type),
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Title and metadata
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            dateStr,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Score badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _getScoreColor(displayPercent).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getScoreIcon(displayPercent),
                        size: 16,
                        color: _getScoreColor(displayPercent),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$scorePercent%',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _getScoreColor(displayPercent),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Location and difficulty chips
            Row(
              children: [
                // Location
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_on, size: 14, color: Colors.grey.shade700),
                      const SizedBox(width: 4),
                      Text(
                        locName,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                
                // Difficulty
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: difficultyColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    difficultyLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: difficultyColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  IconData _getScoreIcon(double score) {
    if (score >= 80) return Icons.check_circle;
    if (score >= 60) return Icons.info;
    return Icons.warning;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Мои тренировки'),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FutureBuilder<List<Training>>(
          future: _futureTrainings,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            
            if (snapshot.hasError) {
              return Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        'Ошибка',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => setState(() => _futureTrainings = _fetchTrainings()),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Повторить'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final list = snapshot.data ?? [];
            
            if (list.isEmpty) {
              return Center(
                child: Container(
                  padding: const EdgeInsets.all(32),
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.fitness_center,
                          size: 40,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Тренировок пока нет',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Создайте свою первую тренировку',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: list.length,
                itemBuilder: (context, i) => _buildTrainingCard(list[i]),
              ),
            );
          },
        ),
      ),
    );
  }
}