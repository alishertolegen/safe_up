class ProfileUtils {
  static String two(int n) => n.toString().padLeft(2, '0');

  static String formatIso(String? iso) {
    if (iso == null || iso.isEmpty) return "-";
    try {
      final dt = DateTime.parse(iso).toLocal();
      return "${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}";
    } catch (e) {
      return iso;
    }
  }

  static String formatPretty(String? iso) {
    if (iso == null || iso.isEmpty) return "-";

    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();

      final today = DateTime(now.year, now.month, now.day);
      final date = DateTime(dt.year, dt.month, dt.day);

      final diff = date.difference(today).inDays;
      String time = "${two(dt.hour)}:${two(dt.minute)}";

      if (diff == 0) return "Сегодня, $time";
      if (diff == -1) return "Вчера, $time";

      const months = [
        '',
        'января','февраля','марта','апреля','мая','июня',
        'июля','августа','сентября','октября','ноября','декабря'
      ];

      if (dt.year != now.year) {
        return "${dt.day} ${months[dt.month]} ${dt.year}";
      }

      return "${dt.day} ${months[dt.month]} $time";
    } catch (e) {
      return iso;
    }
  }

  static int parseInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) {
      return int.tryParse(v) ?? double.tryParse(v)?.toInt() ?? 0;
    }
    return 0;
  }

  static double parseDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  static const int XP_PER_LEVEL = 100;

  static int xpMinForLevel(int lvl) {
    if (lvl <= 1) return 0;
    final base = (lvl - 1);
    return XP_PER_LEVEL * base * base;
  }

  static int xpMaxForLevel(int lvl) {
    if (lvl <= 1) return XP_PER_LEVEL;
    return XP_PER_LEVEL * lvl * lvl;
  }

  static double xpProgressPercent(int xp, int lvl) {
    final minXp = xpMinForLevel(lvl);
    final maxXp = xpMaxForLevel(lvl);
    final span = (maxXp - minXp);
    if (span <= 0) return 0.0;

    final progress = (xp - minXp) / span;
    if (progress.isNaN) return 0.0;

    return progress.clamp(0.0, 1.0);
  }

  static int xpToNextLevel(int xp, int lvl) {
    final maxXp = xpMaxForLevel(lvl);
    final remaining = maxXp - xp;
    return remaining > 0 ? remaining : 0;
  }

  static String formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;

    if (h > 0) return "${h}ч ${m}м";
    if (m > 0) return "${m}м ${s}с";
    return "${s}с";
  }
}