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
  String? avatarUrl;
  String name = "";
  String email = "";
  bool isLoading = true;

  int totalAttempts = 0;
  int successes = 0;
  double avgScore = 0.0;
  int totalTimeSec = 0;

  List<dynamic> achievements = [];

  String createdAtStr = "";
  String lastActiveStr = "";

  // NEW: XP / Level
  int xp = 0;
  int level = 1;
  static const int XP_PER_LEVEL = 100; // sync with backend or change later

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

  String formatPretty(String? iso) {
  if (iso == null || iso.isEmpty) return "-";

  try {
    final dt = DateTime.parse(iso).toLocal();
    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dt.year, dt.month, dt.day);

    final diff = date.difference(today).inDays;

    String time = "${_two(dt.hour)}:${_two(dt.minute)}";

    if (diff == 0) return "Сегодня, $time";
    if (diff == -1) return "Вчера, $time";

    const months = [
      '',
      'января',
      'февраля',
      'марта',
      'апреля',
      'мая',
      'июня',
      'июля',
      'августа',
      'сентября',
      'октября',
      'ноября',
      'декабря'
    ];
    if (dt.year != now.year) {
  return "${dt.day} ${months[dt.month]} ${dt.year}";
}
    return "${dt.day} ${months[dt.month]} $time";
  } catch (e) {
    return iso;
  }
}

  int _parseInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) {
      return int.tryParse(v) ?? double.tryParse(v ?? "0")?.toInt() ?? 0;
    }
    return 0;
  }

  double _parseDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) {
      return double.tryParse(v) ?? 0.0;
    }
    return 0.0;
  }

  Future<void> fetchProfile() async {
    if (mounted) setState(() => isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;

      final token = prefs.getString("token");

      if (token == null) {
        if (mounted) setState(() => isLoading = false);
        return;
      }

      final res = await http.get(
        Uri.parse("http://10.0.2.2:5000/profile"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        avatarUrl = data["avatarUrl"] ?? data["avatar_url"] ?? "";
        final stats = data["stats"] ?? {};
        final ach = data["achievements"] ?? [];

        if (mounted) {
          setState(() {
            name = data["username"] ?? "";
            email = data["email"] ?? "";

            totalAttempts = _parseInt(stats["totalAttempts"] ?? stats["total_attempts"] ?? 0);
            successes = _parseInt(stats["successes"] ?? 0);
            avgScore = _parseDouble(stats["avgScore"] ?? stats["avg_score"] ?? 0);
            totalTimeSec = _parseInt(stats["totalTimeSec"] ?? stats["total_time_sec"] ?? 0);

            achievements = List.from(ach);

            createdAtStr = formatPretty(data["createdAt"] ?? data["created_at"]);
lastActiveStr = formatPretty(data["lastActiveAt"] ?? data["last_active_at"] ?? data["lastActive"]);

            // NEW: parse xp/level (backend must return them)
            xp = _parseInt(data["xp"] ?? 0);
            level = _parseInt(data["level"] ?? 1);

            isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  String formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) return "${h}ч ${m}м";
    if (m > 0) return "${m}м ${s}с";
    return "${s}с";
  }

  // XP / Level helpers (must mirror backend formula)
  int xpMinForLevel(int lvl) {
    if (lvl <= 1) return 0;
    final base = (lvl - 1);
    return XP_PER_LEVEL * base * base;
  }

  int xpMaxForLevel(int lvl) {
    if (lvl <= 1) return XP_PER_LEVEL;
    return XP_PER_LEVEL * lvl * lvl;
  }

  double xpProgressPercent(int xpValue, int lvl) {
    final minXp = xpMinForLevel(lvl);
    final maxXp = xpMaxForLevel(lvl);
    final span = (maxXp - minXp);
    if (span <= 0) return 0.0;
    final progress = (xpValue - minXp) / span;
    if (progress.isNaN) return 0.0;
    return progress.clamp(0.0, 1.0);
  }

  int xpToNextLevel(int xpValue, int lvl) {
    final maxXp = xpMaxForLevel(lvl);
    final remaining = maxXp - xpValue;
    return remaining > 0 ? remaining : 0;
  }

  @override
  Widget build(BuildContext context) {
    final progress = xpProgressPercent(xp, level);
    final remaining = xpToNextLevel(xp, level);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Профиль'),
        backgroundColor: Colors.white,
        elevation: 0,
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
            icon: const Icon(Icons.edit_outlined),
          )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: fetchProfile,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Profile card with level badge
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade600, Colors.blue.shade400],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.3),
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
                            // Avatar with border and level badge
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 3),
                                  ),
                                  child: CircleAvatar(
                                    radius: 50,
                                    backgroundColor: Colors.white,
                                    backgroundImage: (avatarUrl != null && avatarUrl!.isNotEmpty)
                                        ? NetworkImage(avatarUrl!)
                                        : null,
                                    child: (avatarUrl == null || avatarUrl!.isEmpty)
                                        ? Icon(Icons.person, size: 50, color: Colors.blue)
                                        : null,
                                  ),
                                ),
                                // Level badge (top-right)
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 6),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.shield, size: 16, color: Colors.blue.shade700),
                                        const SizedBox(width: 6),
                                        Text(
                                          "Lv $level",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: Colors.blue.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              name.isNotEmpty ? name : "Имя не указано",
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
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
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.email, size: 16, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Text(
                                    email.isNotEmpty ? email : "Email не указан",
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.white,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _levelProgressCard(),
                    const SizedBox(height: 20),

                    // Stats grid
                    Container(
                      padding: const EdgeInsets.all(20),
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
                              Icon(Icons.bar_chart, color: Colors.blue.shade700, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                "Статистика",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: _statCard(
                                  icon: Icons.replay,
                                  iconColor: Colors.blue,
                                  label: "Попыток",
                                  value: totalAttempts.toString(),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _statCard(
                                  icon: Icons.emoji_events,
                                  iconColor: Colors.amber,
                                  label: "Успехов",
                                  value: successes.toString(),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _statCard(
                                  icon: Icons.star,
                                  iconColor: Colors.orange,
                                  label: "Ср. балл",
                                  value: avgScore.toStringAsFixed(1),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _statCard(
                                  icon: Icons.timer,
                                  iconColor: Colors.purple,
                                  label: "Время",
                                  value: formatDuration(totalTimeSec),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Achievements
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
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
                          // header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.emoji_events, color: Colors.amber.shade700, size: 20),
                                  const SizedBox(width: 8),
                                  const Text(
                                    "Достижения",
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              TextButton(
                                onPressed: () => context.push('/achievements'),
                                child: const Text("Все →"),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          achievements.isEmpty
                              ? Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.info_outline, color: Colors.grey.shade600),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          "Пока нет достижений",
                                          style: TextStyle(color: Colors.grey.shade700),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : SizedBox(
                                  height: 100,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: achievements.length > 5 ? 5 : achievements.length,
                                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                                    itemBuilder: (context, i) {
                                      final a = achievements[i];
                                      final title = a["title"] ?? a["code"] ?? "";
                                      final rawDate = a["earnedAt"] ?? a["earned_at"];

                                      final date = formatPretty(rawDate);

                                      return Container(
                                        width: 140,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.amber.shade100,
                                              Colors.amber.shade50
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(color: Colors.amber.shade200),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Icon(Icons.emoji_events,
                                                color: Colors.amber.shade700, size: 22),

                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  title,
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.amber.shade900,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  date,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.grey.shade700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Activity
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
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
                              Icon(Icons.history, color: Colors.green.shade700, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                "Активность",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _activityRow(
                            icon: Icons.calendar_today,
                            label: "Зарегистрирован",
                            value: createdAtStr.isNotEmpty ? createdAtStr : "-",
                          ),
                          const SizedBox(height: 12),
                          _activityRow(
                            icon: Icons.access_time,
                            label: "Последняя активность",
                            value: lastActiveStr.isNotEmpty ? lastActiveStr : "-",
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Logout button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.remove("token");
                          if (context.mounted) context.go("/login");
                        },
                        icon: const Icon(Icons.logout),
                        label: const Text(
                          "Выйти из аккаунта",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade400,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }
Widget _levelProgressCard() {
  final progress = xpProgressPercent(xp, level);
  final remaining = xpToNextLevel(xp, level);
  Widget _xpRow(IconData icon, Color color, String text) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    ),
  );
}
  void _showXpInfo() {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            /// handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            Row(
              children: [
                Icon(Icons.auto_awesome,
                    color: Colors.deepPurple.shade400),
                const SizedBox(width: 8),
                const Text(
                  "Что такое XP?",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            Text(
              "XP — это опыт, который отражает ваш прогресс в обучении.",
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade800,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 18),

            const Text(
              "Как получать XP:",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 10),

            _xpRow(Icons.check_circle, Colors.green,
                "Правильные решения в тренировках"),
            _xpRow(Icons.emoji_events, Colors.amber,
                "Успешное завершение сценариев"),
            _xpRow(Icons.local_fire_department, Colors.orange,
                "Серия успешных прохождений"),
            _xpRow(Icons.workspace_premium, Colors.blue,
                "Получение достижений"),

            const SizedBox(height: 18),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.trending_up,
                      color: Colors.deepPurple.shade400),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "С каждым уровнем требуется больше XP.",
                      style: TextStyle(
                        color: Colors.deepPurple.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      );
    },
  );
}
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
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

        /// HEADER
        Row(
          children: [
            Icon(Icons.auto_awesome, color: Colors.deepPurple.shade400),
            const SizedBox(width: 8),
            const Text(
              "Уровень",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),

            /// LEVEL BADGE
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "Lv $level",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple.shade700,
                ),
              ),
            )
          ],
        ),

        const SizedBox(height: 16),

        /// XP BAR
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 14,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation(
              Colors.deepPurple.shade400,
            ),
          ),
        ),

        const SizedBox(height: 10),

        /// XP TEXT
       Row(
  children: [
    Text(
      "$xp XP",
      style: const TextStyle(fontWeight: FontWeight.w600),
    ),

    const SizedBox(width: 6),

    /// INFO BUTTON
    InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: _showXpInfo,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.deepPurple.shade50,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.info_outline,
          size: 16,
          color: Colors.deepPurple.shade600,
        ),
      ),
    ),

    const Spacer(),

    Text(
      "До уровня: $remaining XP",
      style: TextStyle(color: Colors.grey.shade600),
    ),
    
  ],
  
),

      ],
    ),
  );
  
}

  Widget _statCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: iconColor.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _activityRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: Colors.grey.shade700),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}