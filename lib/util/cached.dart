import 'dart:convert';

import 'package:njupt_flutter/src/rust/api/jwxt.dart';

class CachedPayload {
  CachedPayload({required this.data, required this.fromCache});

  final dynamic data;
  final bool fromCache;

  factory CachedPayload.parse(String raw) {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return CachedPayload(
      data: map['data'],
      fromCache: map['from_cache'] as bool? ?? false,
    );
  }
}

({int year, BridgeTerm term}) defaultAcademicPeriod() {
  final now = DateTime.now();
  if (now.month >= 9) {
    return (year: now.year, term: BridgeTerm.first);
  }
  if (now.month >= 2) {
    return (year: now.year - 1, term: BridgeTerm.second);
  }
  return (year: now.year - 1, term: BridgeTerm.first);
}

String termLabel(BridgeTerm term) =>
    term == BridgeTerm.first ? '第一学期' : '第二学期';
