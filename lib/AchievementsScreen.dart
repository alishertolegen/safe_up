import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String API_BASE = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://10.0.2.2:5000',
);

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  bool isLoading = true;
  bool _visible = false;

  List<dynamic> allAchievements = [];
  Set<String> earnedCodes = {};
  Map<String, dynamic> earnedMap = {};

  String query = "";
  bool showHidden = false;
  bool? onlyEarnedFilter; // null = все, true = полученные, false = не полученные

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    fetchData();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() => query = _searchController.text.trim());
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  String formatReadable(String? iso) {
    if (iso == null || iso.isEmpty) return "";
    DateTime dt;
    try {
      dt = DateTime.parse(iso).toLocal();
    } catch (e) {
      return iso;
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(dt.year, dt.month, dt.day);
    final diff = dateOnly.difference(today).inDays;
    final hhmm = "${_two(dt.hour)}:${_two(dt.minute)}";
    if (diff == 0) return "Сегодня, $hhmm";
    if (diff == -1) return "Вчера, $hhmm";
    const months = [
      '', 'янв', 'фев', 'мар', 'апр', 'май', 'июн',
      'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'
    ];
    return "${dt.day} ${months[dt.month]} ${dt.year}, $hhmm";
  }

  Future<void> fetchData() async {
    if (mounted) setState(() => isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) {
        if (mounted) setState(() => isLoading = false);
        return;
      }
      final headers = {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      };

      final responses = await Future.wait([
        http.get(Uri.parse("$API_BASE/achievements"), headers: headers),
        http.get(Uri.parse("$API_BASE/profile"), headers: headers),
      ]);

      if (responses[0].statusCode == 200) {
        allAchievements = List.from(json.decode(responses[0].body) as List);
      }

      if (responses[1].statusCode == 200) {
        final data = json.decode(responses[1].body);
        final ach = List.from(data['achievements'] ?? []);
        earnedCodes = ach.map<String>((e) => (e['code'] ?? "").toString()).toSet();
        earnedMap = {for (var e in ach) (e['code'] ?? "").toString(): e};
      }
    } catch (_) {
      allAchievements = [];
      earnedCodes = {};
      earnedMap = {};
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) setState(() => _visible = true);
        });
      }
    }
  }

  List<dynamic> get _filteredAchievements {
    final q = query.toLowerCase();
    return allAchievements.where((a) {
      final code = (a['code'] ?? "").toString();
      final title = (a['title'] ?? "").toString();
      final desc = (a['description'] ?? "").toString();

      if (!showHidden && a['hidden'] == true) return false;

      if (onlyEarnedFilter != null) {
        final isEarned = earnedCodes.contains(code);
        if (onlyEarnedFilter == true && !isEarned) return false;
        if (onlyEarnedFilter == false && isEarned) return false;
      }

      if (q.isEmpty) return true;
      return code.toLowerCase().contains(q) ||
          title.toLowerCase().contains(q) ||
          desc.toLowerCase().contains(q);
    }).toList();
  }

  void _toggleOnlyEarned() {
    setState(() {
      if (onlyEarnedFilter == null) onlyEarnedFilter = true;
      else if (onlyEarnedFilter == true) onlyEarnedFilter = false;
      else onlyEarnedFilter = null;
    });
  }

  // ─── Stats bar ─────────────────────────────────────────────────────────────

  Widget _buildStatsBar() {
    final total = allAchievements.where((a) => a['hidden'] != true).length;
    final earned = earnedCodes.length;
    final percent = total == 0 ? 0.0 : earned / total;

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
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(Icons.emoji_events_rounded,
                    size: 28, color: Colors.blue.shade600),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Твои достижения",
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      "$earned из $total получено",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                  ],
                ),
              ),
              // Percentage pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "${(percent * 100).round()}%",
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.25),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Filter chips ───────────────────────────────────────────────────────────

  Widget _buildFilterRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          _filterChip(
            label: "Все",
            icon: Icons.apps_rounded,
            selected: onlyEarnedFilter == null,
            color: Colors.blue,
            onTap: () => setState(() => onlyEarnedFilter = null),
          ),
          const SizedBox(width: 8),
          _filterChip(
            label: "Получено",
            icon: Icons.check_circle_outline_rounded,
            selected: onlyEarnedFilter == true,
            color: Colors.green,
            onTap: () => setState(() => onlyEarnedFilter = true),
          ),
          const SizedBox(width: 8),
          _filterChip(
            label: "Не получено",
            icon: Icons.lock_outline_rounded,
            selected: onlyEarnedFilter == false,
            color: Colors.grey,
            onTap: () => setState(() => onlyEarnedFilter = false),
          ),
          const SizedBox(width: 8),
          _filterChip(
            label: showHidden ? "Скрытые: вкл" : "Скрытые: выкл",
            icon: showHidden ? Icons.visibility_rounded : Icons.visibility_off_rounded,
            selected: showHidden,
            color: Colors.purple,
            onTap: () => setState(() => showHidden = !showHidden),
          ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required IconData icon,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.12) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color.withOpacity(0.4) : Colors.grey.withOpacity(0.2),
            width: 1.5,
          ),
          boxShadow: selected
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? color : Colors.grey.shade500),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? color : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Search field ───────────────────────────────────────────────────────────

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Поиск достижений...',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade400),
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.withOpacity(0.15)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.withOpacity(0.15)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.blue.shade300, width: 1.5),
          ),
          suffixIcon: query.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear_rounded, color: Colors.grey.shade400),
                  onPressed: () {
                    _searchController.clear();
                    FocusScope.of(context).unfocus();
                  },
                )
              : null,
        ),
      ),
    );
  }

  // ─── Achievement card ───────────────────────────────────────────────────────

  Widget _buildAchievementCard(dynamic a, int index) {
    final code = (a['code'] ?? "").toString();
    final title = (a['title'] ?? code).toString();
    final desc = (a['description'] ?? "").toString();
    final iconUrl = (a['iconUrl'] ?? a['icon_url'] ?? "").toString();
    final points = a['points'] != null ? a['points'].toString() : "";
    final isHidden = a['hidden'] == true;

    final earned = earnedCodes.contains(code);
    final earnedObj = earned ? earnedMap[code] : null;
    final earnedAtRaw = earnedObj != null
        ? (earnedObj['earnedAt'] ??
                earnedObj['earned_at'] ??
                earnedObj['earnedAt'])
            ?.toString()
        : null;
    final earnedAt = formatReadable(earnedAtRaw);

    return AnimatedOpacity(
      duration: Duration(milliseconds: 400 + index * 60),
      opacity: _visible ? 1 : 0,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : const Offset(0, 0.08),
        duration: Duration(milliseconds: 400 + index * 60),
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: earned ? Colors.green.shade50 : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: earned
                  ? Colors.green.withOpacity(0.18)
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
              // Icon
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: earned
                      ? Colors.green.withOpacity(0.12)
                      : Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: iconUrl.isNotEmpty
                    ? ClipOval(
                        child: Image.network(
                          iconUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.emoji_events_rounded,
                            color: Colors.amber.shade600,
                            size: 26,
                          ),
                        ),
                      )
                    : Icon(
                        isHidden ? Icons.lock_rounded : Icons.emoji_events_rounded,
                        color: earned
                            ? Colors.green.shade600
                            : Colors.amber.shade600,
                        size: 26,
                      ),
              ),

              const SizedBox(width: 14),

              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: earned
                                  ? Colors.green.shade800
                                  : Colors.grey.shade800,
                            ),
                          ),
                        ),
                        if (points.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: earned
                                  ? Colors.green.withOpacity(0.12)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star_rounded,
                                    size: 13,
                                    color: earned
                                        ? Colors.green.shade600
                                        : Colors.grey.shade500),
                                const SizedBox(width: 3),
                                Text(
                                  points,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: earned
                                        ? Colors.green.shade700
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    if (desc.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        desc,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          height: 1.4,
                        ),
                      ),
                    ],
                    if (earnedAt.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded,
                              size: 12, color: Colors.green.shade500),
                          const SizedBox(width: 4),
                          Text(
                            earnedAt,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Status icon
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: earned
                      ? Colors.green.withOpacity(0.12)
                      : Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  earned ? Icons.check_rounded : Icons.lock_outline_rounded,
                  size: 18,
                  color: earned ? Colors.green.shade600 : Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Empty state ────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.search_off_rounded,
                size: 36, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 16),
          Text(
            "Ничего не найдено",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Попробуй изменить фильтры или запрос",
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Main build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final list = _filteredAchievements;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Достижения'),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Обновить',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: fetchData,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: fetchData,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // Stats banner
                  SliverToBoxAdapter(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 600),
                      opacity: _visible ? 1 : 0,
                      child: AnimatedSlide(
                        offset: _visible ? Offset.zero : const Offset(0, 0.1),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeOut,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
                          child: _buildStatsBar(),
                        ),
                      ),
                    ),
                  ),

                  // Search
                  SliverToBoxAdapter(child: _buildSearchField()),

                  // Filter chips
                  SliverToBoxAdapter(child: _buildFilterRow()),

                  // List or empty
                  if (list.isEmpty)
                    SliverFillRemaining(child: _buildEmptyState())
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _buildAchievementCard(list[index], index),
                            );
                          },
                          childCount: list.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}