// rating.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class RatingScreen extends StatefulWidget {
  const RatingScreen({super.key});

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  bool isLoading = true;
  String? error;
  List<dynamic> users = [];

  @override
  void initState() {
    super.initState();
    fetchUsers();
  }

  Future<void> fetchUsers() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final uri = Uri.parse('http://10.0.2.2:5000/users');

      final res = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data is List) {
          users = List.from(data);
          _normalizeAndSortUsers();
          setState(() {
            isLoading = false;
          });
        } else {
          setState(() {
            isLoading = false;
            error = 'Неверный формат ответа от сервера';
          });
        }
      } else {
        setState(() {
          isLoading = false;
          error = 'Ошибка сервера: ${res.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        error = 'Сбой сети: $e';
      });
    }
  }

void _normalizeAndSortUsers() {
  // Ensure stats exist and numeric types are correct
  for (var u in users) {
    final stats = u['stats'] ?? {};
    u['_stats_parsed'] = {
      'totalAttempts': _toIntSafe(stats['totalAttempts'] ?? stats['total_attempts']),
      'successes': _toIntSafe(stats['successes'] ?? stats['successes_count']),
      'avgScore': _toDoubleSafe(stats['avgScore'] ?? stats['avg_score']),
      'totalTimeSec': _toIntSafe(stats['totalTimeSec'] ?? stats['total_time_sec']),
    };
  }

  // Sort: 1) successes desc, 2) avgScore desc, 3) totalAttempts desc
  users.sort((a, b) {
    final sa = a['_stats_parsed'];
    final sb = b['_stats_parsed'];

    final cmpSuc = sb['successes'].compareTo(sa['successes']);
    if (cmpSuc != 0) return cmpSuc;

    final cmpAvg = sb['avgScore'].compareTo(sa['avgScore']);
    if (cmpAvg != 0) return cmpAvg;

    return sb['totalAttempts'].compareTo(sa['totalAttempts']);
  });
}


  int _toIntSafe(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) {
      return int.tryParse(v) ?? double.tryParse(v)?.toInt() ?? 0;
    }
    return 0;
  }

  double _toDoubleSafe(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  String formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) return "${h}ч ${m}м";
    if (m > 0) return "${m}м ${s}с";
    return "${s}с";
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  String formatIso(String? iso) {
    if (iso == null || iso.isEmpty) return "-";
    try {
      final dt = DateTime.parse(iso).toLocal();
      return "${dt.year}-${_two(dt.month)}-${_two(dt.day)} ${_two(dt.hour)}:${_two(dt.minute)}";
    } catch (e) {
      return iso;
    }
  }

  void _openUserDetails(BuildContext context, dynamic user, int rank) {
    final stats = user['_stats_parsed'] ?? {};
    final achievements = List.from(user['achievements'] ?? []);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (_, controller) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                controller: controller,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundImage: (user['avatarUrl'] ?? user['avatar_url']) != null &&
                                (user['avatarUrl'] ?? user['avatar_url']).toString().isNotEmpty
                            ? NetworkImage((user['avatarUrl'] ?? user['avatar_url']).toString())
                            : null,
                        child: (user['avatarUrl'] ?? user['avatar_url']) == null ||
                                (user['avatarUrl'] ?? user['avatar_url']).toString().isEmpty
                            ? Text(
                                (user['username'] ?? 'U')
                                    .toString()
                                    .trim()
                                    .split(' ')
                                    .map((e) => e.isEmpty ? '' : e[0])
                                    .take(2)
                                    .join()
                                    .toUpperCase(),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${user['username'] ?? 'Имя отсутствует'}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user['email'] ?? '',
                              style: TextStyle(color: Colors.grey.shade600),
                            )
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('#$rank', style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star, size: 18, color: Colors.amber),
                              const SizedBox(width: 6),
                              Text((stats['avgScore'] ?? 0.0).toStringAsFixed(1)),
                            ],
                          ),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _smallStat('Попыток', stats['totalAttempts'] ?? 0),
                      const SizedBox(width: 8),
                      _smallStat('Успехов', stats['successes'] ?? 0),
                      const SizedBox(width: 8),
                      _smallStat('Время', formatDuration(stats['totalTimeSec'] ?? 0)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Даты', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  ListTile(
                    leading: const Icon(Icons.calendar_today),
                    title: const Text('Зарегистрирован'),
                    subtitle: Text(formatIso(user['createdAt'] ?? user['created_at'])),
                  ),
                  ListTile(
                    leading: const Icon(Icons.access_time),
                    title: const Text('Последняя активность'),
                    subtitle: Text(formatIso(user['lastActiveAt'] ?? user['last_active_at'] ?? user['lastActive'])),
                  ),
                  const SizedBox(height: 12),
                  Text('Достижения', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  if (achievements.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text('Достижений пока нет.'),
                    )
                  else
                    ...achievements.map<Widget>((a) {
                      final title = a['title'] ?? a['code'] ?? 'Достижение';
                      final earned = formatIso(a['earnedAt'] ?? a['earned_at']);
                      return ListTile(
                        leading: const Icon(Icons.emoji_events, color: Colors.amber),
                        title: Text(title),
                        subtitle: Text(earned),
                      );
                    }).toList(),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _smallStat(String label, dynamic value) {
    final valStr = value is String ? value : value.toString();
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              valStr,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserTile(BuildContext context, dynamic user, int index) {
    final stats = user['_stats_parsed'] ?? {};
    final avatar = (user['avatarUrl'] ?? user['avatar_url'])?.toString() ?? '';
    final username = user['username'] ?? 'Имя отсутствует';
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        onTap: () => _openUserDetails(context, user, index + 1),
        leading: CircleAvatar(
          radius: 24,
          backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
          child: avatar.isEmpty
              ? Text(
                  username.toString().trim().isEmpty
                      ? 'U'
                      : username.toString().trim().split(' ').map((e) => e.isEmpty ? '' : e[0]).take(2).join().toUpperCase(),
                )
              : null,
        ),
        title: Text(username.toString()),
        subtitle: Text('Попыток: ${stats['totalAttempts'] ?? 0} • Успехов: ${stats['successes'] ?? 0}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text((stats['avgScore'] ?? 0.0).toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.star, size: 16, color: Colors.amber),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Рейтинг'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: fetchUsers,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 60),
                      Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
                      const SizedBox(height: 12),
                      Center(child: Text(error!)),
                      const SizedBox(height: 12),
                      Center(
                        child: ElevatedButton(
                          onPressed: fetchUsers,
                          child: const Text('Попробовать снова'),
                        ),
                      )
                    ],
                  )
                : users.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 60),
                          Center(child: Text('Пользователей нет')),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          // show top badge for top-3
                          final user = users[index];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    margin: const EdgeInsets.only(right: 8, bottom: 6),
                                    decoration: BoxDecoration(
                                      color: index < 3 ? Colors.amber.shade100 : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Text('#${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                        const SizedBox(width: 8),
                                        if (index == 0) const Icon(Icons.workspace_premium, color: Colors.orange, size: 18),
                                        if (index == 1) const Icon(Icons.looks_two, color: Colors.grey, size: 18),
                                        if (index == 2) const Icon(Icons.looks_3, color: Colors.brown, size: 18),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              _buildUserTile(context, user, index),
                            ],
                          );
                        },
                      ),
      ),
    );
  }
}
