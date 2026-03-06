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
  bool _visible = false;
  String? error;
  List<dynamic> users = [];
  final TextEditingController _searchController = TextEditingController();
List<dynamic> _filteredUsers = [];
  @override
  void initState() {
    super.initState();
    fetchUsers();
  }

Future<void> fetchUsers() async {
  if (!mounted) return; // guard at entry
  setState(() {
    isLoading = true;
    error = null;
    _visible = false;
  });

  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final res = await http.get(
      Uri.parse('https://safe-up.onrender.com/users'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (!mounted) return; // ← guard after every await

    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      if (data is List) {
        users = List.from(data);
        _normalizeAndSortUsers();
        if (!mounted) return;
        setState(() => isLoading = false);
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) setState(() => _visible = true); // already correct
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
    if (!mounted) return; // ← guard in catch too
    setState(() {
      isLoading = false;
      error = 'Сбой сети: $e';
    });
  }
}

  void _normalizeAndSortUsers() {
    for (var u in users) {
      final stats = u['stats'] ?? {};
      final level = _toIntSafe(u['level'] ?? 1);
      final xp = _toIntSafe(u['xp'] ?? 0);
      final totalAttempts = _toIntSafe(stats['totalAttempts'] ?? stats['total_attempts']);
      final successes = _toIntSafe(stats['successes'] ?? stats['successes_count']);
      final avgScore = _toDoubleSafe(stats['avgScore'] ?? stats['avg_score']);
      final totalTimeSec = _toIntSafe(stats['totalTimeSec'] ?? stats['total_time_sec']);

      u['_stats_parsed'] = {
        'totalAttempts': totalAttempts,
        'successes': successes,
        'avgScore': avgScore,
        'totalTimeSec': totalTimeSec,
        'level': level,
        'xp': xp,
      };

      u['_ratingScore'] = (successes * 0.4) +
          (avgScore * 0.3) +
          (totalAttempts * 0.1) +
          (level * 0.15) +
          (xp * 0.05);
    }
    users.sort((a, b) =>
        (b['_ratingScore'] as double).compareTo(a['_ratingScore'] as double));
    _filteredUsers = List.from(users);
  }
void _filterUsers(String query) {
  setState(() {
    if (query.isEmpty) {
      _filteredUsers = List.from(users);
    } else {
      _filteredUsers = users.where((u) {
        final name = (u['username'] ?? '').toString().toLowerCase();
        return name.contains(query.toLowerCase());
      }).toList();
    }
  });
}
  int _toIntSafe(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? double.tryParse(v)?.toInt() ?? 0;
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
      const months = [
        '', 'янв', 'фев', 'мар', 'апр', 'май', 'июн',
        'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'
      ];
      return "${dt.day} ${months[dt.month]} ${_two(dt.hour)}:${_two(dt.minute)}";
    } catch (_) {
      return iso;
    }
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  String _initials(dynamic username) {
    final s = (username ?? 'U').toString().trim();
    if (s.isEmpty) return 'U';
    return s.split(' ').map((e) => e.isEmpty ? '' : e[0]).take(2).join().toUpperCase();
  }

  Color _rankColor(int index) {
    if (index == 0) return const Color(0xFFFFD700); // gold
    if (index == 1) return const Color(0xFFC0C0C0); // silver
    if (index == 2) return const Color(0xFFCD7F32); // bronze
    return Colors.blue.shade400;
  }

  IconData _rankIcon(int index) {
    if (index == 0) return Icons.workspace_premium_rounded;
    if (index == 1) return Icons.military_tech_rounded;
    if (index == 2) return Icons.military_tech_rounded;
    return Icons.tag;
  }

  // ─── Bottom sheet ────────────────────────────────────────────────────────────

  void _openUserDetails(BuildContext context, dynamic user, int rank) {
    final stats = user['_stats_parsed'] ?? {};
    final achievements = List.from(user['achievements'] ?? []);
    final avatar = (user['avatarUrl'] ?? user['avatar_url'])?.toString() ?? '';
    final username = user['username'] ?? 'Без имени';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.62,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (_, controller) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 20),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header
                  Row(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundColor: Colors.blue.shade50,
                            backgroundImage:
                                avatar.isNotEmpty ? NetworkImage(avatar) : null,
                            child: avatar.isEmpty
                                ? Text(
                                    _initials(username),
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue.shade700),
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade600,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Lv.${user['level'] ?? 1}',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 10,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              username.toString(),
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'XP: ${user['xp'] ?? 0}',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                            if ((user['email'] ?? '').toString().isNotEmpty)
                              Text(
                                user['email'].toString(),
                                style: TextStyle(
                                    color: Colors.grey.shade500, fontSize: 13),
                              ),
                          ],
                        ),
                      ),
                      // Rank badge
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _rankColor(rank - 1).withOpacity(0.12),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: _rankColor(rank - 1).withOpacity(0.4),
                              width: 2),
                        ),
                        child: Center(
                          child: Text(
                            '#$rank',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _rankColor(rank - 1),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Stats row
                  Row(
                    children: [
                      _statCard('Попыток',
                          (stats['totalAttempts'] ?? 0).toString(),
                          Icons.repeat_rounded, Colors.blue),
                      const SizedBox(width: 10),
                      _statCard('Успехов',
                          (stats['successes'] ?? 0).toString(),
                          Icons.check_circle_outline_rounded, Colors.green),
                      const SizedBox(width: 10),
                      _statCard('Среднее',
                          (stats['avgScore'] ?? 0.0).toStringAsFixed(1),
                          Icons.star_rounded, Colors.amber),
                    ],
                  ),

                  const SizedBox(height: 10),

                  _wideStatCard(
                    'Время в тренировках',
                    formatDuration(stats['totalTimeSec'] ?? 0),
                    Icons.timer_rounded,
                    Colors.purple,
                  ),

                  const SizedBox(height: 20),

                  // Dates
                  _sectionTitle('Даты'),
                  const SizedBox(height: 10),
                  _dateRow(Icons.calendar_today_rounded, 'Зарегистрирован',
                      formatIso(user['createdAt'] ?? user['created_at'])),
                  const SizedBox(height: 8),
                  _dateRow(Icons.access_time_rounded, 'Последняя активность',
                      formatIso(user['lastActiveAt'] ?? user['last_active_at'] ?? user['lastActive'])),

                  const SizedBox(height: 20),

                  // Achievements
                  _sectionTitle('Достижения'),
                  const SizedBox(height: 10),
                  if (achievements.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Достижений пока нет',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    )
                  else
                    ...achievements.map<Widget>((a) {
                      final title = a['title'] ?? a['code'] ?? 'Достижение';
                      final earned =
                          formatIso(a['earnedAt'] ?? a['earned_at']);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.amber.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.emoji_events_rounded,
                                color: Colors.amber.shade600, size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(title.toString(),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  Text(earned,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    );
  }

  Widget _statCard(
      String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.12)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: color)),
            const SizedBox(height: 3),
            Text(label,
                style: TextStyle(
                    color: Colors.grey.shade600, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _wideStatCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      color: Colors.grey.shade600, fontSize: 12)),
              Text(value,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: color)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dateRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.blue.shade400),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade500)),
                Text(value,
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Top-3 podium ────────────────────────────────────────────────────────────

  Widget _buildPodium() {
    if (_filteredUsers.length < 3) return const SizedBox.shrink();

    final medals = [
      {'index': 1, 'label': '2', 'height': 80.0, 'color': const Color(0xFFC0C0C0)},
      {'index': 0, 'label': '1', 'height': 110.0, 'color': const Color(0xFFFFD700)},
      {'index': 2, 'label': '3', 'height': 60.0, 'color': const Color(0xFFCD7F32)},
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(20),
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
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 3)),
                  ],
                ),
                child: Icon(Icons.leaderboard_rounded,
                    size: 28, color: Colors.blue.shade600),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Топ игроки',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.3),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Всего участников: ${users.length}',
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.85)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Podium
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: medals.map((m) {
              final idx = m['index'] as int;
              final user = _filteredUsers[idx];
              final avatar =
                  (user['avatarUrl'] ?? user['avatar_url'])?.toString() ?? '';
              final username = user['username'] ?? 'User';
              final stats = user['_stats_parsed'] ?? {};
              final color = m['color'] as Color;
              final height = m['height'] as double;

              return Expanded(
                child: GestureDetector(
                  onTap: () => _openUserDetails(context, user, idx + 1),
                  child: Column(
                    children: [
                      // Crown for #1
                      if (idx == 0)
                        Icon(Icons.workspace_premium_rounded,
                            color: Colors.amber.shade300, size: 22),
                      const SizedBox(height: 4),
                      // Avatar
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: color, width: 2.5),
                        ),
                        child: CircleAvatar(
                          radius: idx == 0 ? 28 : 22,
                          backgroundColor: Colors.white.withOpacity(0.15),
                          backgroundImage:
                              avatar.isNotEmpty ? NetworkImage(avatar) : null,
                          child: avatar.isEmpty
                              ? Text(
                                  _initials(username),
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: color,
                                      fontSize: idx == 0 ? 14 : 12),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        username.toString().split(' ').first,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: idx == 0 ? 13 : 11,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${(stats['avgScore'] ?? 0.0).toStringAsFixed(1)} ★',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Podium block
                      Container(
                        height: height,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.25),
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(10)),
                          border: Border.all(
                              color: color.withOpacity(0.5), width: 1.5),
                        ),
                        child: Center(
                          child: Text(
                            '#${m['label']}',
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─── User list tile ──────────────────────────────────────────────────────────

  Widget _buildUserTile(dynamic user, int index) {
    final stats = user['_stats_parsed'] ?? {};
    final avatar = (user['avatarUrl'] ?? user['avatar_url'])?.toString() ?? '';
    final username = user['username'] ?? 'Без имени';
    final isTop3 = index < 3;
    final rankColor = _rankColor(index);

    return AnimatedOpacity(
      duration: Duration(milliseconds: 400 + index * 50),
      opacity: _visible ? 1 : 0,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : const Offset(0, 0.08),
        duration: Duration(milliseconds: 400 + index * 50),
        curve: Curves.easeOut,
        child: GestureDetector(
          onTap: () => _openUserDetails(context, user, index + 1),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isTop3
                  ? rankColor.withOpacity(0.05)
                  : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isTop3
                    ? rankColor.withOpacity(0.2)
                    : Colors.grey.withOpacity(0.1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                // Rank badge
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isTop3
                        ? rankColor.withOpacity(0.12)
                        : Colors.grey.shade100,
                    shape: BoxShape.circle,
                    border: isTop3
                        ? Border.all(
                            color: rankColor.withOpacity(0.35), width: 1.5)
                        : null,
                  ),
                  child: Center(
                    child: isTop3
                        ? Icon(_rankIcon(index), color: rankColor, size: 18)
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                  ),
                ),

                const SizedBox(width: 12),

                // Avatar
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.blue.shade50,
                      backgroundImage:
                          avatar.isNotEmpty ? NetworkImage(avatar) : null,
                      child: avatar.isEmpty
                          ? Text(
                              _initials(username),
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                  fontSize: 13),
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade600,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Lv${user['level'] ?? 1}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(width: 12),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username.toString(),
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          _miniTag('${stats['totalAttempts'] ?? 0} попыток',
                              Colors.blue),
                          const SizedBox(width: 6),
                          _miniTag('${stats['successes'] ?? 0} успехов',
                              Colors.green),
                        ],
                      ),
                    ],
                  ),
                ),

                // Score
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded,
                            size: 16, color: Colors.amber.shade600),
                        const SizedBox(width: 3),
                        Text(
                          (stats['avgScore'] ?? 0.0).toStringAsFixed(1),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'XP: ${user['xp'] ?? 0}',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11,
            color: color.withOpacity(0.8),
            fontWeight: FontWeight.w500),
      ),
    );
  }

  // ─── Error / empty ───────────────────────────────────────────────────────────

  Widget _buildErrorState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.error_outline_rounded,
                size: 36, color: Colors.red.shade400),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(error!,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
        ),
        const SizedBox(height: 20),
        Center(
          child: ElevatedButton.icon(
            onPressed: fetchUsers,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Попробовать снова'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: TextField(
  controller: _searchController,
  onChanged: _filterUsers,
  decoration: InputDecoration(
    hintText: 'Поиск по имени...',
    border: InputBorder.none,
    hintStyle: TextStyle(color: Colors.grey.shade400),
  ),
),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Обновить',
            onPressed: fetchUsers,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: fetchUsers,
              child: error != null
                  ? _buildErrorState()
                  : users.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            const SizedBox(height: 80),
                            Center(
                              child: Text(
                                'Пользователей нет',
                                style: TextStyle(color: Colors.grey.shade500),
                              ),
                            ),
                          ],
                        )
                      : CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            // Podium banner
                            SliverToBoxAdapter(
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 600),
                                opacity: _visible ? 1 : 0,
                                child: AnimatedSlide(
                                  offset: _visible
                                      ? Offset.zero
                                      : const Offset(0, 0.1),
                                  duration: const Duration(milliseconds: 700),
                                  curve: Curves.easeOut,
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        0, 16, 0, 0),
                                    child: _buildPodium(),
                                  ),
                                ),
                              ),
                            ),

                            // Section label
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    16, 8, 16, 10),
                                child: Text(
                                  'Все участники',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ),

                            // List
                            SliverPadding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 0, 16, 32),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 10),
                                      child: _buildUserTile(
                                          _filteredUsers[index], index),
                                    );
                                  },
                                  childCount: _filteredUsers.length,
                                ),
                              ),
                            ),
                          ],
                        ),
            ),
    );
  }
  @override
void dispose() {
  _searchController.dispose();
  super.dispose();
}
}