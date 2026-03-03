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
  List<dynamic> allAchievements = [];
  Set<String> earnedCodes = {};
  Map<String, dynamic> earnedMap = {}; // code -> earned object

  String query = "";
  bool showHidden = false;
  // null = все, true = только полученные, false = только не полученные
  bool? onlyEarnedFilter;

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
    setState(() {
      query = _searchController.text.trim();
    });
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

    // русские сокращённые месяцы
    const months = [
      '', 'янв', 'фев', 'мар', 'апр', 'май', 'июн',
      'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'
    ];
    final mon = months[dt.month];
    return "${dt.day} $mon ${dt.year}, $hhmm";
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

      final allFut = http.get(Uri.parse("$API_BASE/achievements"), headers: headers);
      final profFut = http.get(Uri.parse("$API_BASE/profile"), headers: headers);

      final responses = await Future.wait([allFut, profFut]);

      final allRes = responses[0];
      final profRes = responses[1];

      if (allRes.statusCode == 200) {
        allAchievements = List.from(json.decode(allRes.body) as List);
      } else {
        allAchievements = [];
      }

      if (profRes.statusCode == 200) {
        final data = json.decode(profRes.body);
        final ach = List.from(data['achievements'] ?? []);
        earnedCodes = ach.map<String>((e) => (e['code'] ?? "").toString()).toSet();
        earnedMap = { for (var e in ach) (e['code'] ?? "").toString(): e };
      } else {
        earnedCodes = {};
        earnedMap = {};
      }
    } catch (e) {
      allAchievements = [];
      earnedCodes = {};
      earnedMap = {};
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  List<dynamic> get _filteredAchievements {
    final q = query.toLowerCase();
    return allAchievements.where((a) {
      final code = (a['code'] ?? "").toString();
      final title = (a['title'] ?? "").toString();
      final desc = (a['description'] ?? "").toString();

      if (!showHidden && (a['hidden'] == true)) return false;

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

  Widget _buildList() {
    final list = _filteredAchievements;
    if (list.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 40),
          Center(child: Text(isLoading ? "Загрузка..." : "Ничего не найдено", style: TextStyle(color: Colors.grey.shade600))),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, idx) {
        final a = list[idx];
        final code = (a['code'] ?? "").toString();
        final title = (a['title'] ?? code).toString();
        final desc = (a['description'] ?? "").toString();
        final iconUrl = (a['iconUrl'] ?? a['icon_url'] ?? "").toString();
        final points = a['points'] != null ? a['points'].toString() : "";

        final earned = earnedCodes.contains(code);
        final earnedObj = earned ? earnedMap[code] : null;
        final earnedAtRaw = earnedObj != null ? (earnedObj['earnedAt'] ?? earnedObj['earned_at'] ?? earnedObj['earnedAt'])?.toString() : null;
        final earnedAt = formatReadable(earnedAtRaw);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: earned ? Colors.green.shade50 : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: earned ? Colors.green.withOpacity(0.12) : Colors.grey.withOpacity(0.08)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.grey.shade100,
                backgroundImage: (iconUrl.isNotEmpty) ? NetworkImage(iconUrl) : null,
                child: (iconUrl.isEmpty) ? Icon(Icons.emoji_events, color: Colors.amber.shade700) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600))),
                        if (points.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text("$points pts", style: const TextStyle(fontSize: 12)),
                          ),
                      ],
                    ),
                    if (desc.isNotEmpty) const SizedBox(height: 6),
                    if (desc.isNotEmpty) Text(desc, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                    if (earnedAt.isNotEmpty) const SizedBox(height: 6),
                    if (earnedAt.isNotEmpty) Text("Получено: $earnedAt", style: TextStyle(fontSize: 12, color: Colors.green.shade700)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(earned ? Icons.check_circle : Icons.lock_open, color: earned ? Colors.green.shade700 : Colors.grey.shade400),
            ],
          ),
        );
      },
    );
  }

  void _toggleOnlyEarned() {
    setState(() {
      if (onlyEarnedFilter == null) onlyEarnedFilter = true;
      else if (onlyEarnedFilter == true) onlyEarnedFilter = false;
      else onlyEarnedFilter = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Достижения'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'refresh') fetchData();
              if (v == 'toggleHidden') setState(() => showHidden = !showHidden);
              if (v == 'cycleEarned') _toggleOnlyEarned();
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'toggleHidden',
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [Text(showHidden ? 'Скрытые: показывать' : 'Скрытые: скрывать'), Switch(value: showHidden, onChanged: (_) => Navigator.pop(ctx, 'toggleHidden'))],
                ),
              ),
              PopupMenuItem(
                value: 'cycleEarned',
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(onlyEarnedFilter == null ? 'Статус: все' : (onlyEarnedFilter == true ? 'Статус: полученные' : 'Статус: не полученные')),
                    Icon(Icons.filter_list),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'refresh', child: Text('Обновить')),
            ],
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // search + clear button
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Поиск по названию или коду',
                            prefixIcon: const Icon(Icons.search),
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            suffixIcon: query.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      FocusScope.of(context).unfocus();
                                    },
                                  )
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // quick filter button to cycle earned filter
                      IconButton(
                        tooltip: onlyEarnedFilter == null ? 'Фильтр статуса: все' : (onlyEarnedFilter == true ? 'Только полученные' : 'Только не полученные'),
                        onPressed: _toggleOnlyEarned,
                        icon: Icon(
                          onlyEarnedFilter == null ? Icons.filter_alt_outlined : (onlyEarnedFilter == true ? Icons.done_all : Icons.do_not_disturb_on_outlined),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: RefreshIndicator(
                    onRefresh: fetchData,
                    child: _buildList(),
                  ),
                ),
              ],
            ),
    );
  }
}