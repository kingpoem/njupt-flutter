import 'package:njupt_flutter/src/rust/api/jwxt.dart';

/// 南邮常见节次时间（仙林校区）。
const List<(String, String)> kPeriodTimes = [
  ('08:00', '08:45'),
  ('08:50', '09:35'),
  ('09:50', '10:35'),
  ('10:40', '11:25'),
  ('11:30', '12:15'),
  ('13:45', '14:30'),
  ('14:35', '15:20'),
  ('15:35', '16:20'),
  ('16:25', '17:10'),
  ('18:30', '19:15'),
  ('19:20', '20:05'),
  ('20:10', '20:55'),
];

const List<String> kWeekdayLabels = ['一', '二', '三', '四', '五', '六', '日'];

class CourseSlot {
  CourseSlot({
    required this.name,
    required this.room,
    required this.teacher,
    required this.weekday,
    required this.startSection,
    required this.endSection,
    required this.weeksLabel,
    required this.weeks,
    required this.credit,
    required this.code,
  });

  final String name;
  final String room;
  final String teacher;
  final int weekday; // 1=Mon … 7=Sun
  final int startSection;
  final int endSection;
  final String weeksLabel;
  final Set<int> weeks;
  final String credit;
  final String code;

  bool occursInWeek(int? week) {
    if (week == null) return true;
    return weeks.contains(week);
  }
}

(int, int)? parseSections(String raw) {
  final nums = RegExp(r'\d+').allMatches(raw).map((m) => int.parse(m.group(0)!)).toList();
  if (nums.isEmpty) return null;
  if (nums.length == 1) return (nums.first, nums.first);
  return (nums.first, nums.last);
}

Set<int> parseWeeks(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return {};

  final odd = text.contains('单');
  final even = text.contains('双');
  final result = <int>{};

  for (final part in text.split(RegExp(r'[,，;；]'))) {
    final p = part.trim();
    if (p.isEmpty) continue;

    final range = RegExp(r'(\d+)\s*[-~～至到]\s*(\d+)').firstMatch(p);
    if (range != null) {
      final a = int.parse(range.group(1)!);
      final b = int.parse(range.group(2)!);
      final lo = a < b ? a : b;
      final hi = a < b ? b : a;
      for (var w = lo; w <= hi; w++) {
        if (odd && w.isEven) continue;
        if (even && w.isOdd) continue;
        result.add(w);
      }
      continue;
    }

    final single = RegExp(r'(\d+)').firstMatch(p);
    if (single != null) {
      final w = int.parse(single.group(1)!);
      if (odd && w.isEven) continue;
      if (even && w.isOdd) continue;
      result.add(w);
    }
  }
  return result;
}

List<CourseSlot> parseCourseSlots(List courses) {
  final out = <CourseSlot>[];
  for (final raw in courses) {
    if (raw is! Map) continue;
    final map = Map<String, dynamic>.from(raw);
    final weekday = int.tryParse('${map['weekday'] ?? ''}');
    final sections = parseSections('${map['sections'] ?? ''}');
    if (weekday == null || weekday < 1 || weekday > 7 || sections == null) {
      continue;
    }
    final weeksLabel = '${map['weeks'] ?? ''}';
    out.add(
      CourseSlot(
        name: '${map['name'] ?? ''}',
        room: '${map['room'] ?? ''}',
        teacher: '${map['teacher'] ?? ''}',
        weekday: weekday,
        startSection: sections.$1,
        endSection: sections.$2,
        weeksLabel: weeksLabel,
        weeks: parseWeeks(weeksLabel),
        credit: '${map['credit'] ?? ''}',
        code: '${map['code'] ?? ''}',
      ),
    );
  }
  return out;
}

int maxWeekOf(Iterable<CourseSlot> courses, {int fallback = 18}) {
  var max = 0;
  for (final c in courses) {
    for (final w in c.weeks) {
      if (w > max) max = w;
    }
  }
  return max > 0 ? max : fallback;
}

/// 估算学期第 1 周周一（教学周起点）。
DateTime estimateSemesterStart(int year, BridgeTerm term) {
  final DateTime anchor;
  if (term == BridgeTerm.first) {
    anchor = DateTime(year, 9, 1);
  } else {
    // 春季学期多在 2 月中下旬开学
    anchor = DateTime(year + 1, 2, 17);
  }
  return anchor.subtract(Duration(days: anchor.weekday - DateTime.monday));
}

int estimateCurrentWeek(int year, BridgeTerm term, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final start = estimateSemesterStart(year, term);
  final days = today.difference(start).inDays;
  if (days < 0) return 1;
  return days ~/ 7 + 1;
}

DateTime mondayOfWeek(int year, BridgeTerm term, int week) {
  return estimateSemesterStart(year, term).add(Duration(days: (week - 1) * 7));
}
