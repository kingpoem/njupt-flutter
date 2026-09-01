import 'package:flutter/material.dart';

import 'package:njupt_flutter/src/rust/api/jwxt.dart';
import 'package:njupt_flutter/util/schedule_parse.dart';

class TimetableView extends StatefulWidget {
  const TimetableView({
    super.key,
    required this.courses,
    required this.practices,
    required this.year,
    required this.term,
    this.student,
  });

  final List courses;
  final List practices;
  final int year;
  final BridgeTerm term;
  final Map<String, dynamic>? student;

  @override
  State<TimetableView> createState() => _TimetableViewState();
}

class _TimetableViewState extends State<TimetableView> {
  static const _timeColWidth = 42.0;
  static const _dayHeaderHeight = 48.0;
  static const _periodHeight = 64.0;

  late List<CourseSlot> _slots;
  late int _maxWeek;
  late int _periodCount;
  late int _selectedWeek; // 0 = 全部周
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _initFromCourses(jumpPage: false);
    _pageController = PageController(initialPage: (_selectedWeek - 1).clamp(0, _maxWeek - 1));
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _initFromCourses({required bool jumpPage}) {
    _slots = parseCourseSlots(widget.courses);
    _maxWeek = maxWeekOf(_slots);
    _periodCount = _slots.fold<int>(
      10,
      (m, c) => c.endSection > m ? c.endSection : m,
    );
    if (_periodCount > kPeriodTimes.length) {
      _periodCount = kPeriodTimes.length;
    }
    final estimated =
        estimateCurrentWeek(widget.year, widget.term).clamp(1, _maxWeek);
    _selectedWeek = estimated;
    if (jumpPage && _pageController.hasClients) {
      _pageController.jumpToPage(_selectedWeek - 1);
    }
  }

  @override
  void didUpdateWidget(covariant TimetableView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.courses != widget.courses ||
        oldWidget.year != widget.year ||
        oldWidget.term != widget.term) {
      _initFromCourses(jumpPage: true);
    }
  }

  Future<void> _selectWeek(int week) async {
    if (week == _selectedWeek) return;
    setState(() => _selectedWeek = week);
    if (week >= 1 && _pageController.hasClients) {
      await _pageController.animateToPage(
        week - 1,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  List<CourseSlot> _coursesForWeek(int? week) {
    return _slots.where((c) => c.occursInWeek(week)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WeekBar(
          selectedWeek: _selectedWeek,
          maxWeek: _maxWeek,
          onChanged: _selectWeek,
        ),
        if (widget.student != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: Text(
              '${widget.student!['name'] ?? ''} · ${widget.student!['class_name'] ?? ''}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
          ),
        Expanded(
          child: _selectedWeek == 0
              ? _WeekPage(
                  week: null,
                  year: widget.year,
                  term: widget.term,
                  periodCount: _periodCount,
                  timeColWidth: _timeColWidth,
                  dayHeaderHeight: _dayHeaderHeight,
                  periodHeight: _periodHeight,
                  courses: _coursesForWeek(null),
                  practices: widget.practices,
                  showWeekBadge: true,
                  onTapCourse: _showCourseDetail,
                )
              : PageView.builder(
                  controller: _pageController,
                  itemCount: _maxWeek,
                  onPageChanged: (index) {
                    setState(() => _selectedWeek = index + 1);
                  },
                  itemBuilder: (context, index) {
                    final week = index + 1;
                    return _WeekPage(
                      week: week,
                      year: widget.year,
                      term: widget.term,
                      periodCount: _periodCount,
                      timeColWidth: _timeColWidth,
                      dayHeaderHeight: _dayHeaderHeight,
                      periodHeight: _periodHeight,
                      courses: _coursesForWeek(week),
                      practices: widget.practices,
                      showWeekBadge: false,
                      onTapCourse: _showCourseDetail,
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showCourseDetail(CourseSlot course) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final colors = _courseColors(course.name);
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: colors.bg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  course.name,
                  style: TextStyle(
                    color: colors.fg,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _DetailRow(
                Icons.place_outlined,
                course.room.isEmpty ? '未知教室' : course.room,
              ),
              _DetailRow(
                Icons.person_outline,
                course.teacher.isEmpty ? '未知教师' : course.teacher,
              ),
              _DetailRow(
                Icons.schedule_outlined,
                '${kWeekdayLabels[course.weekday - 1]} '
                '${course.startSection}-${course.endSection}节',
              ),
              _DetailRow(Icons.date_range_outlined, course.weeksLabel),
              if (course.credit.isNotEmpty && course.credit != 'null')
                _DetailRow(Icons.star_outline, '${course.credit} 学分'),
              if (course.code.isNotEmpty) _DetailRow(Icons.tag, course.code),
            ],
          ),
        );
      },
    );
  }
}

class _WeekPage extends StatelessWidget {
  const _WeekPage({
    required this.week,
    required this.year,
    required this.term,
    required this.periodCount,
    required this.timeColWidth,
    required this.dayHeaderHeight,
    required this.periodHeight,
    required this.courses,
    required this.practices,
    required this.showWeekBadge,
    required this.onTapCourse,
  });

  final int? week;
  final int year;
  final BridgeTerm term;
  final int periodCount;
  final double timeColWidth;
  final double dayHeaderHeight;
  final double periodHeight;
  final List<CourseSlot> courses;
  final List practices;
  final bool showWeekBadge;
  final ValueChanged<CourseSlot> onTapCourse;

  @override
  Widget build(BuildContext context) {
    final monday =
        week == null ? null : mondayOfWeek(year, term, week!);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 8, 0),
          child: _DayHeader(
            monday: monday,
            timeColWidth: timeColWidth,
            height: dayHeaderHeight,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 8, 8),
          child: SizedBox(
            height: periodCount * periodHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: timeColWidth,
                  child: _TimeColumn(
                    periodCount: periodCount,
                    periodHeight: periodHeight,
                  ),
                ),
                Expanded(
                  child: _CourseGrid(
                    periodCount: periodCount,
                    periodHeight: periodHeight,
                    courses: courses,
                    showWeekBadge: showWeekBadge,
                    onTap: onTapCourse,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (practices.isNotEmpty) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text('实践课', style: Theme.of(context).textTheme.titleSmall),
          ),
          for (final p in practices)
            if (p is Map)
              ListTile(
                dense: true,
                title: Text('${p['name'] ?? ''}'),
                subtitle: Text(
                  '${p['teacher'] ?? ''} · ${p['weeks'] ?? ''}'
                  '${(p['detail'] ?? '').toString().isEmpty ? '' : '\n${p['detail']}'}',
                ),
                isThreeLine: '${p['detail'] ?? ''}'.isNotEmpty,
              ),
          const SizedBox(height: 24),
        ],
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _WeekBar extends StatelessWidget {
  const _WeekBar({
    required this.selectedWeek,
    required this.maxWeek,
    required this.onChanged,
  });

  final int selectedWeek;
  final int maxWeek;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Row(
        children: [
          IconButton(
            tooltip: '上一周',
            onPressed:
                selectedWeek <= 1 ? null : () => onChanged(selectedWeek - 1),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Center(
              child: PopupMenuButton<int>(
                initialValue: selectedWeek,
                onSelected: onChanged,
                offset: const Offset(0, 40),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 0, child: Text('全部周')),
                  for (var w = 1; w <= maxWeek; w++)
                    PopupMenuItem(value: w, child: Text('第$w周')),
                ],
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      selectedWeek == 0 ? '全部周' : '第$selectedWeek周',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: '下一周',
            onPressed: selectedWeek == 0 || selectedWeek >= maxWeek
                ? null
                : () => onChanged(selectedWeek + 1),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.monday,
    required this.timeColWidth,
    required this.height,
  });

  final DateTime? monday;
  final double timeColWidth;
  final double height;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    return SizedBox(
      height: height,
      child: Row(
        children: [
          SizedBox(width: timeColWidth),
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Builder(
                builder: (context) {
                  final date = monday?.add(Duration(days: i));
                  final isToday = date != null &&
                      date.year == today.year &&
                      date.month == today.month &&
                      date.day == today.day;
                  final fg = isToday
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey.shade700;
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        kWeekdayLabels[i],
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              isToday ? FontWeight.w700 : FontWeight.w500,
                          color: fg,
                        ),
                      ),
                      if (date != null)
                        Text(
                          '${date.month}/${date.day}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isToday ? fg : Colors.grey.shade500,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _TimeColumn extends StatelessWidget {
  const _TimeColumn({
    required this.periodCount,
    required this.periodHeight,
  });

  final int periodCount;
  final double periodHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < periodCount; i++)
          SizedBox(
            height: periodHeight,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${i + 1}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
                if (i < kPeriodTimes.length) ...[
                  Text(
                    kPeriodTimes[i].$1,
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.grey.shade500,
                      height: 1.15,
                    ),
                  ),
                  Text(
                    kPeriodTimes[i].$2,
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.grey.shade500,
                      height: 1.15,
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _CourseGrid extends StatelessWidget {
  const _CourseGrid({
    required this.periodCount,
    required this.periodHeight,
    required this.courses,
    required this.showWeekBadge,
    required this.onTap,
  });

  final int periodCount;
  final double periodHeight;
  final List<CourseSlot> courses;
  final bool showWeekBadge;
  final ValueChanged<CourseSlot> onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dayWidth = constraints.maxWidth / 7;
        final height = periodCount * periodHeight;

        final groups = <String, List<CourseSlot>>{};
        for (final c in courses) {
          final key = '${c.weekday}-${c.startSection}-${c.endSection}';
          groups.putIfAbsent(key, () => []).add(c);
        }

        return SizedBox(
          height: height,
          child: Stack(
            children: [
              CustomPaint(
                size: Size(constraints.maxWidth, height),
                painter: _GridPainter(
                  periodCount: periodCount,
                  periodHeight: periodHeight,
                ),
              ),
              for (final entry in groups.entries)
                for (var i = 0; i < entry.value.length; i++)
                  _positionedBlock(
                    course: entry.value[i],
                    dayWidth: dayWidth,
                    index: i,
                    count: entry.value.length,
                  ),
            ],
          ),
        );
      },
    );
  }

  Widget _positionedBlock({
    required CourseSlot course,
    required double dayWidth,
    required int index,
    required int count,
  }) {
    final top = (course.startSection - 1) * periodHeight + 2;
    final height =
        (course.endSection - course.startSection + 1) * periodHeight - 4;
    final slotWidth = (dayWidth - 4) / count;
    final left = (course.weekday - 1) * dayWidth + 2 + index * slotWidth;
    final colors = _courseColors(course.name);

    return Positioned(
      left: left,
      top: top,
      width: slotWidth - 2,
      height: height,
      child: Material(
        color: colors.bg,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => onTap(course),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Center(
              child: Text(
                showWeekBadge
                    ? '${course.name}\n@${course.room}\n${course.weeksLabel}'
                    : '${course.name}\n@${course.room}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.fg,
                  fontSize: count > 1 ? 10 : 11,
                  height: 1.2,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: height > 90 ? 6 : 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({required this.periodCount, required this.periodHeight});

  final int periodCount;
  final double periodHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE8E8E8)
      ..strokeWidth = 1;

    for (var i = 0; i <= periodCount; i++) {
      final y = i * periodHeight;
      const dash = 4.0;
      const gap = 3.0;
      var x = 0.0;
      while (x < size.width) {
        canvas.drawLine(
          Offset(x, y),
          Offset((x + dash).clamp(0, size.width), y),
          paint,
        );
        x += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) =>
      oldDelegate.periodCount != periodCount ||
      oldDelegate.periodHeight != periodHeight;
}

class _CourseColor {
  const _CourseColor(this.bg, this.fg);
  final Color bg;
  final Color fg;
}

const _palette = <_CourseColor>[
  _CourseColor(Color(0xFFFFE4E8), Color(0xFFC45A6A)),
  _CourseColor(Color(0xFFE3F0FF), Color(0xFF3B7DD8)),
  _CourseColor(Color(0xFFE5F6E8), Color(0xFF3B9B57)),
  _CourseColor(Color(0xFFFFF0D6), Color(0xFFC4842A)),
  _CourseColor(Color(0xFFF0E6FF), Color(0xFF7A52C7)),
  _CourseColor(Color(0xFFE0F7F5), Color(0xFF2A9B8F)),
  _CourseColor(Color(0xFFFFE8DA), Color(0xFFD06B3A)),
  _CourseColor(Color(0xFFE8EEFF), Color(0xFF4A62C4)),
  _CourseColor(Color(0xFFFCE4F0), Color(0xFFC24B8A)),
  _CourseColor(Color(0xFFE8F5E0), Color(0xFF5A9A3A)),
];

_CourseColor _courseColors(String name) {
  var hash = 0;
  for (final u in name.codeUnits) {
    hash = (hash * 31 + u) & 0x7fffffff;
  }
  return _palette[hash % _palette.length];
}
