import 'package:njupt_flutter/src/rust/api/jwxt.dart';

/// 加权平均绩点：Σ(学分×绩点) / Σ学分。
/// 无学分、无绩点或绩点为 0 的课程不计入（如通识/通过类课）。
/// 学分来自成绩 API 的 `credit`（正方 `xf`）。
({double? gpa, double credits, int courses}) computeGpa(Iterable<dynamic> items) {
  var sumXfJd = 0.0;
  var sumXf = 0.0;
  var courses = 0;
  for (final raw in items) {
    if (raw is! Map) continue;
    final credit = (raw['credit'] as num?)?.toDouble() ?? 0;
    final jd = (raw['grade_point'] as num?)?.toDouble();
    // 绩点为 0 的课（有学分但不参与绩点）排除在外
    if (credit <= 0 || jd == null || jd <= 0) continue;
    final xfjd = (raw['credit_grade_point'] as num?)?.toDouble();
    sumXf += credit;
    sumXfJd += xfjd ?? (credit * jd);
    courses += 1;
  }
  if (sumXf <= 0) {
    return (gpa: null, credits: 0, courses: 0);
  }
  return (gpa: sumXfJd / sumXf, credits: sumXf, courses: courses);
}

bool gradeMatchesTerm(Map item, int year, BridgeTerm term) {
  final y = '${item['year'] ?? ''}';
  if (y != year.toString()) return false;
  final termCode = '${item['term_code'] ?? ''}';
  final termName = '${item['term_name'] ?? ''}';
  if (term == BridgeTerm.second) {
    return termCode == '12' || termName.contains('二');
  }
  return termCode == '3' || termName.contains('一');
}
