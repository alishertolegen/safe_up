// lib/screens/my_trainings_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/training.dart';
import 'TrainingDetailScreen.dart';
const String API_BASE = String.fromEnvironment('API_BASE',
    defaultValue:
        'http://localhost:5000'); // для Android эмулятора. Для iOS/реального девайса укажи http://localhost:5000 или IP.

class MyTrainingsScreen extends StatefulWidget {
  const MyTrainingsScreen({super.key});

  @override
  State<MyTrainingsScreen> createState() => _MyTrainingsScreenState();
}

class _MyTrainingsScreenState extends State<MyTrainingsScreen> {
  late Future<List<Training>> _futureTrainings;

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
    final uri = Uri.parse('$API_BASE/trainings'); // можно добавить фильтры ?isPublished=true
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    final res = await http.get(uri, headers: headers);

    if (res.statusCode != 200) {
      throw Exception('Ошибка при получении тренингов: ${res.statusCode} ${res.body}');
    }

    final List<dynamic> data = json.decode(res.body);
    return data.map<Training>((e) => _trainingFromJson(e)).toList();
  }

  // Преобразование json с сервера в модель Training (подстраивается под ту модель, что у тебя в ../models/training.dart)
  Training _trainingFromJson(Map<String, dynamic> json) {
    // id
    final id = json['_id'] ?? json['id'] ?? '';

    // title, type, difficulty
    final title = json['title'] ?? 'Без названия';
    final type = json['type'] ?? '';
    String difficulty = json['difficulty']?.toString() ?? '';

    // location: сервер возвращает объект { name, floor, extra } — склеим в строку, если нужно
    String location = '';
    final loc = json['location'];
    if (loc is String) {
      location = loc;
    } else if (loc is Map) {
      final name = loc['name'] ?? '';
      final floor = loc['floor'] ?? '';
      final extra = loc['extra'] ?? '';
      location = [name, floor, extra].where((s) => (s?.toString().isNotEmpty ?? false)).join(', ');
    }

    // createdAt: сервер обычно возвращает ISO строку
    DateTime createdAt;
    try {
      final s = json['createdAt'] ?? json['created_at'] ?? DateTime.now().toIso8601String();
      createdAt = DateTime.parse(s.toString());
    } catch (err) {
      createdAt = DateTime.now();
    }

    // lastScorePercent: бек возвращает stats.attempts и stats.successes -> округлим процент успеха
    double lastScorePercent = 0;
    try {
      final stats = json['stats'] as Map<String, dynamic>?;
      final attempts = (stats?['attempts'] ?? 0) is int ? stats!['attempts'] as int : int.tryParse('${stats?['attempts']}') ?? 0;
      final successes = (stats?['successes'] ?? 0) is int ? stats!['successes'] as int : int.tryParse('${stats?['successes']}') ?? 0;
      if (attempts > 0) {
        lastScorePercent = (successes / attempts) * 100;
      } else {
        lastScorePercent = 0;
      }
    } catch (_) {
      lastScorePercent = 0;
    }

    // Если у тебя Training ожидает другие поля — поправь тут
    return Training(
      id: id.toString(),
      title: title,
      type: type,
      location: location,
      difficulty: difficulty,
      createdAt: createdAt,
      lastScorePercent: lastScorePercent,
    );
  }

  void _openDetail(BuildContext context, Training t) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TrainingDetailScreen(training: t)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            const Text('Мои тренировки',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<Training>>(
                future: _futureTrainings,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Ошибка: ${snapshot.error}', textAlign: TextAlign.center),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () => setState(() => _futureTrainings = _fetchTrainings()),
                            child: const Text('Повторить'),
                          )
                        ],
                      ),
                    );
                  }

                  final list = snapshot.data ?? [];
                  if (list.isEmpty) {
                    return const Center(child: Text('Тренировок ещё нет. Создайте первую.'));
                  }

                  return ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, i) {
                      final t = list[i];
                      return ListTile(
                        title: Text(t.title),
                        subtitle: Text('${t.type} • ${t.location} • ${t.difficulty}'),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('${t.lastScorePercent.toStringAsFixed(0)}%'),
                            const SizedBox(height: 4),
                            Text(
                              '${t.createdAt.day.toString().padLeft(2, '0')}.${t.createdAt.month.toString().padLeft(2, '0')}.${t.createdAt.year}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                        onTap: () => _openDetail(context, t),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
