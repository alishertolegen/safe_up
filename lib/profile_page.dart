import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String name = "";
  String email = "";
  bool isLoading = true;

  // stats
  int totalAttempts = 0;
  int successes = 0;
  double avgScore = 0.0;
  int totalTimeSec = 0;

  // achievements
  List<dynamic> achievements = [];

  // dates
  String createdAtStr = "";
  String lastActiveStr = "";

  @override
  void initState() {
    super.initState();
    fetchProfile();
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

  Future<void> fetchProfile() async {
    setState(() => isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");

      if (token == null) {
        setState(() {
          isLoading = false;
        });
        return;
      }

      final res = await http.get(
        Uri.parse("http://localhost:5000/profile"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final stats = data["stats"] ?? {};
        final ach = data["achievements"] ?? [];

        setState(() {
          name = data["username"] ?? "";
          email = data["email"] ?? "";

          totalAttempts = (stats["totalAttempts"] ?? 0) is int
              ? stats["totalAttempts"]
              : (stats["totalAttempts"] ?? 0).toInt();
          successes = (stats["successes"] ?? 0) is int
              ? stats["successes"]
              : (stats["successes"] ?? 0).toInt();
          avgScore = (stats["avgScore"] ?? 0).toDouble();
          totalTimeSec = (stats["totalTimeSec"] ?? 0) is int
              ? stats["totalTimeSec"]
              : (stats["totalTimeSec"] ?? 0).toInt();

          achievements = List.from(ach);

          createdAtStr = formatIso(data["createdAt"] ?? data["created_at"]);
          lastActiveStr = formatIso(data["lastActiveAt"] ?? data["last_active_at"] ?? data["lastActive"]);
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  String formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) return "${h}ч ${m}м";
    if (m > 0) return "${m}м ${s}s";
    return "${s}s";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Профиль',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        backgroundColor: const Color.fromARGB(255, 177, 42, 32),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Редактировать профиль',
            onPressed: () async {
              final result = await context.push('/profile/edit');
              if (result == true) {
                await fetchProfile();
              }
            },
            icon: const Icon(Icons.edit),
          )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: fetchProfile,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // Карточка профиля
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            // Дефолтный аватар (иконка)
                            const CircleAvatar(
                              radius: 56,
                              backgroundColor: Color.fromARGB(255, 255, 35, 49),
                              child: Icon(
                                Icons.person,
                                size: 60,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              name.isNotEmpty ? name : "Имя не указано",
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                email.isNotEmpty ? email : "Email не указан",
                                style: TextStyle(
                                    fontSize: 16, color: Colors.grey[700]),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      final prefs =
                                          await SharedPreferences.getInstance();
                                      await prefs.remove("token");
                                      context.go("/login");
                                    },
                                    icon: const Icon(Icons.logout, size: 18),
                                    label: const Text("Выйти"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red[400],
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Stats block
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Статистика",
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _statTile("Попыток", totalAttempts.toString()),
                              _statTile("Успехи", successes.toString()),
                              _statTile("Средний балл", avgScore.toStringAsFixed(1)),
                              _statTile("Время", formatDuration(totalTimeSec)),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Achievements
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Достижения",
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 12),
                          achievements.isEmpty
                              ? const Text("Достижений пока нет",
                                  style: TextStyle(color: Colors.black54))
                              : Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: achievements.map<Widget>((a) {
                                    final code = a["code"] ?? "";
                                    final title = a["title"] ?? code;
                                    final earned = formatIso(a["earnedAt"] ?? a["earned_at"]);
                                    return Chip(
                                      label: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                                          const SizedBox(height: 4),
                                          Text(earned, style: const TextStyle(fontSize: 11)),
                                        ],
                                      ),
                                      avatar: const Icon(Icons.emoji_events, size: 18),
                                      backgroundColor: Colors.grey[100],
                                    );
                                  }).toList(),
                                ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Dates
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Активность",
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Зарегистрирован:"),
                              Text(createdAtStr.isNotEmpty ? createdAtStr : "-"),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Последняя активность:"),
                              Text(lastActiveStr.isNotEmpty ? lastActiveStr : "-"),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _statTile(String title, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }
}
