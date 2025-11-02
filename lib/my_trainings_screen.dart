import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/training.dart';
import 'TrainingDetailScreen.dart';

const String API_BASE = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://localhost:5000',
);
// Примечание: для Android-эмулятора обычно используйте http://10.0.2.2:5000 в переменной окружения API_BASE

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
    // Используем фабрику из модели
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
    // ждём завершения, чтобы RefreshIndicator закрывался корректно
    await _futureTrainings;
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

                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, i) {
                        final t = list[i];
                        final locName = t.location.name.isNotEmpty ? t.location.name : (t.location.floor.isNotEmpty ? t.location.floor : '-');
                        final dateStr =
                            '${t.createdAt.day.toString().padLeft(2, '0')}.${t.createdAt.month.toString().padLeft(2, '0')}.${t.createdAt.year}';
                        return ListTile(
                          title: Text(t.title),
                          subtitle: Text('${t.type} • $locName • ${t.difficulty}'),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('${t.lastScorePercent.toStringAsFixed(0)}%'),
                              const SizedBox(height: 4),
                              Text(dateStr, style: const TextStyle(fontSize: 11)),
                            ],
                          ),
                          onTap: () => _openDetail(context, t),
                        );
                      },
                    ),
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
