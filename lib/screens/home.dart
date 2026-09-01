import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:njupt_flutter/session.dart';
import 'package:njupt_flutter/src/rust/api/card.dart';
import 'package:njupt_flutter/src/rust/api/jwxt.dart';
import 'package:njupt_flutter/widgets/common.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.session});

  final SessionController session;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final TextEditingController _user;
  late final TextEditingController _pass;
  late bool _offCampus;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _user = TextEditingController(text: widget.session.username ?? '');
    _pass = TextEditingController();
    _offCampus = widget.session.offCampus;
  }

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = await widget.session.login(
      username: _user.text.trim(),
      password: _pass.text,
      offCampus: _offCampus,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.session.lastError ?? '登录失败')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: ListView(
            padding: const EdgeInsets.all(24),
            shrinkWrap: true,
            children: [
              Text('南邮校园', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                '统一身份认证登录教务与校园卡',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _user,
                decoration: const InputDecoration(
                  labelText: '学号',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pass,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: '密码',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                  ),
                ),
                onSubmitted: (_) => _submit(),
                autofillHints: const [AutofillHints.password],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('校外登录（WebVPN）'),
                subtitle: const Text('校内网可关闭；校外请开启'),
                value: _offCampus,
                onChanged: (v) => setState(() => _offCampus = v),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: widget.session.loggingIn ? null : _submit,
                child: widget.session.loggingIn
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('登录'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.session});

  final SessionController session;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _destinations = [
    (Icons.calendar_month, '课表'),
    (Icons.grade, '成绩'),
    (Icons.analytics_outlined, '分项'),
    (Icons.event, '考试'),
    (Icons.replay, '补考'),
    (Icons.schedule_send, '缓考'),
    (Icons.checklist, '已选'),
    (Icons.person, '学籍'),
    (Icons.credit_card, '校园卡'),
    (Icons.search, '选课浏览'),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final body = _pageAt(_index);
    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(
                    icon: Icon(d.$1),
                    label: Text(d.$2),
                  ),
              ],
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: IconButton(
                    tooltip: '退出登录',
                    onPressed: () => widget.session.logout(),
                    icon: const Icon(Icons.logout),
                  ),
                ),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(_destinations[_index].$2),
        actions: [
          IconButton(
            tooltip: '退出登录',
            onPressed: () => widget.session.logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index.clamp(0, 4),
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final d in _destinations.take(5))
            NavigationDestination(icon: Icon(d.$1), label: d.$2),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              child: Text(
                widget.session.username ?? '',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            for (var i = 0; i < _destinations.length; i++)
              ListTile(
                leading: Icon(_destinations[i].$1),
                title: Text(_destinations[i].$2),
                selected: _index == i,
                onTap: () {
                  setState(() => _index = i);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _pageAt(int i) {
    final s = widget.session;
    return switch (i) {
      0 => _SchedulePage(session: s),
      1 => _GradesPage(session: s),
      2 => _GradeDetailsPage(session: s),
      3 => _ExamsPage(session: s, kind: _ExamKind.normal),
      4 => _ExamsPage(session: s, kind: _ExamKind.makeup),
      5 => _ExamsPage(session: s, kind: _ExamKind.deferred),
      6 => _SelectedPage(session: s),
      7 => _ProfilePage(session: s),
      8 => _CardPage(session: s),
      _ => _CourseSelectPage(session: s),
    };
  }
}

class _SchedulePage extends StatelessWidget {
  const _SchedulePage({required this.session});
  final SessionController session;

  @override
  Widget build(BuildContext context) {
    return CachedQueryPage(
      key: ValueKey('schedule-${session.year}-${session.term}'),
      title: '课表',
      header: YearTermControls(
        year: session.year,
        term: session.term,
        onChanged: (y, t) => session.setPeriod(year: y, term: t),
      ),
      fetcher: (mode) => fetchSchedule(
        jwxt: session.jwxt!,
        year: session.year,
        term: session.term,
        mode: mode,
      ),
      builder: (context, data) {
        final map = data as Map<String, dynamic>;
        final courses = (map['courses'] as List?) ?? const [];
        final practices = (map['practices'] as List?) ?? const [];
        final student = map['student'] as Map<String, dynamic>?;
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12),
          children: [
            if (student != null)
              ListTile(
                title: Text('${student['name']} · ${student['student_id']}'),
                subtitle: Text('${student['major']} · ${student['class_name']}'),
              ),
            const Divider(),
            for (final c in courses)
              ListTile(
                title: Text('${c['name']}'),
                subtitle: Text(
                  '${c['weekday_name']} ${c['sections']} · ${c['room']}\n'
                  '${c['teacher']} · ${c['weeks']}',
                ),
                isThreeLine: true,
              ),
            if (practices.isNotEmpty) ...[
              const Divider(),
              const ListTile(title: Text('实践课')),
              for (final p in practices)
                ListTile(
                  title: Text('${p['name']}'),
                  subtitle: Text('${p['teacher']} · ${p['weeks']}\n${p['detail']}'),
                  isThreeLine: true,
                ),
            ],
          ],
        );
      },
    );
  }
}

class _GradesPage extends StatefulWidget {
  const _GradesPage({required this.session});
  final SessionController session;

  @override
  State<_GradesPage> createState() => _GradesPageState();
}

class _GradesPageState extends State<_GradesPage> {
  bool _all = true;

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    return CachedQueryPage(
      key: ValueKey('grades-$_all-${s.year}-${s.term}'),
      title: '成绩',
      header: YearTermControls(
        year: s.year,
        term: s.term,
        allYears: _all,
        onAllYearsChanged: (v) => setState(() => _all = v),
        onChanged: (y, t) => s.setPeriod(year: y, term: t),
      ),
      fetcher: (mode) => fetchGrades(
        jwxt: s.jwxt!,
        year: _all ? null : s.year,
        term: _all ? null : s.term,
        mode: mode,
      ),
      builder: (context, data) {
        final items = ((data as Map)['items'] as List?) ?? const [];
        return ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final g = items[i] as Map;
            return ListTile(
              title: Text('${g['name']}'),
              subtitle: Text(
                '${g['academic_year']} ${g['term_name']} · ${g['course_nature']}',
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${g['score']}', style: Theme.of(context).textTheme.titleMedium),
                  Text('绩点 ${g['grade_point'] ?? '-'}'),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _GradeDetailsPage extends StatefulWidget {
  const _GradeDetailsPage({required this.session});
  final SessionController session;

  @override
  State<_GradeDetailsPage> createState() => _GradeDetailsPageState();
}

class _GradeDetailsPageState extends State<_GradeDetailsPage> {
  bool _all = true;

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    return CachedQueryPage(
      key: ValueKey('grade-details-$_all-${s.year}-${s.term}'),
      title: '成绩分项',
      header: YearTermControls(
        year: s.year,
        term: s.term,
        allYears: _all,
        onAllYearsChanged: (v) => setState(() => _all = v),
        onChanged: (y, t) => s.setPeriod(year: y, term: t),
      ),
      fetcher: (mode) => fetchGradeDetails(
        jwxt: s.jwxt!,
        year: _all ? null : s.year,
        term: _all ? null : s.term,
        mode: mode,
      ),
      builder: (context, data) {
        final items = ((data as Map)['items'] as List?) ?? const [];
        return ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final g = items[i] as Map;
            return ListTile(
              title: Text('${g['name']} · ${g['component']}'),
              subtitle: Text('${g['academic_year']} ${g['term_name']}'),
              trailing: Text('${g['score']}'),
            );
          },
        );
      },
    );
  }
}

enum _ExamKind { normal, makeup, deferred }

class _ExamsPage extends StatefulWidget {
  const _ExamsPage({required this.session, required this.kind});
  final SessionController session;
  final _ExamKind kind;

  @override
  State<_ExamsPage> createState() => _ExamsPageState();
}

class _ExamsPageState extends State<_ExamsPage> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    return CachedQueryPage(
      key: ValueKey('exams-${widget.kind}-$_all-${s.year}-${s.term}'),
      title: '考试',
      header: YearTermControls(
        year: s.year,
        term: s.term,
        allYears: _all,
        onAllYearsChanged: (v) => setState(() => _all = v),
        onChanged: (y, t) => s.setPeriod(year: y, term: t),
      ),
      fetcher: (mode) {
        final year = _all ? null : s.year;
        final term = _all ? null : s.term;
        return switch (widget.kind) {
          _ExamKind.normal => fetchExams(
            jwxt: s.jwxt!,
            year: year,
            term: term,
            mode: mode,
          ),
          _ExamKind.makeup => fetchMakeupExams(
            jwxt: s.jwxt!,
            year: year,
            term: term,
            mode: mode,
          ),
          _ExamKind.deferred => fetchDeferredExams(
            jwxt: s.jwxt!,
            year: year,
            term: term,
            mode: mode,
          ),
        };
      },
      builder: (context, data) {
        final items = ((data as Map)['items'] as List?) ?? const [];
        return ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final e = items[i] as Map;
            return ListTile(
              title: Text('${e['name'] ?? e['kcmc'] ?? ''}'),
              subtitle: Text(
                '${e['time'] ?? e['kssj'] ?? ''} · ${e['room'] ?? e['cdmc'] ?? ''}\n'
                '${e['seat'] ?? e['zwh'] ?? ''}',
              ),
              isThreeLine: true,
            );
          },
        );
      },
    );
  }
}

class _SelectedPage extends StatefulWidget {
  const _SelectedPage({required this.session});
  final SessionController session;

  @override
  State<_SelectedPage> createState() => _SelectedPageState();
}

class _SelectedPageState extends State<_SelectedPage> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    return CachedQueryPage(
      key: ValueKey('selected-$_all-${s.year}-${s.term}'),
      title: '已选课程',
      header: YearTermControls(
        year: s.year,
        term: s.term,
        allYears: _all,
        onAllYearsChanged: (v) => setState(() => _all = v),
        onChanged: (y, t) => s.setPeriod(year: y, term: t),
      ),
      fetcher: (mode) => fetchSelected(
        jwxt: s.jwxt!,
        year: _all ? null : s.year,
        term: _all ? null : s.term,
        mode: mode,
      ),
      builder: (context, data) {
        final items = ((data as Map)['items'] as List?) ?? const [];
        return ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final c = items[i] as Map;
            return ListTile(
              title: Text('${c['name']}'),
              subtitle: Text(
                '${c['teacher'] ?? ''} · ${c['time'] ?? c['sksj'] ?? ''}\n'
                '${c['place'] ?? c['jxdd'] ?? ''} · 学分 ${c['credit'] ?? c['xf'] ?? ''}',
              ),
              isThreeLine: true,
            );
          },
        );
      },
    );
  }
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage({required this.session});
  final SessionController session;

  @override
  Widget build(BuildContext context) {
    return CachedQueryPage(
      title: '学籍',
      fetcher: (mode) => fetchProfile(jwxt: session.jwxt!, mode: mode),
      builder: (context, data) {
        final p = data as Map<String, dynamic>;
        final entries = [
          ('学号', p['student_id']),
          ('姓名', p['name']),
          ('性别', p['gender']),
          ('年级', p['grade_year']),
          ('学院', p['college']),
          ('专业', p['major']),
          ('班级', p['class_name']),
          ('学制', p['study_years']),
          ('学籍状态', p['status']),
          ('是否在校', p['in_school']),
          ('入学日期', p['enrollment_date']),
          ('培养层次', p['education_level']),
          ('邮箱', p['email']),
          ('电话', p['phone']),
        ];
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            for (final e in entries)
              ListTile(title: Text(e.$1), subtitle: Text('${e.$2 ?? ''}')),
            ListTile(
              title: const Text('全部字段'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final raw = await fetchProfileFields(
                  jwxt: session.jwxt!,
                  mode: BridgeFetchMode.cacheFirst,
                );
                final payload = jsonDecode(raw) as Map<String, dynamic>;
                final fields = (payload['data'] as Map).cast<String, dynamic>();
                if (!context.mounted) return;
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('学籍全部字段')),
                      body: ListView(
                        children: [
                          for (final e in fields.entries)
                            ListTile(
                              title: Text(e.key),
                              subtitle: Text('${e.value}'),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            ListTile(
              title: const Text('清空教务缓存'),
              subtitle: FutureBuilder(
                future: jwxtCacheLen(jwxt: session.jwxt!),
                builder: (context, snap) =>
                    Text('当前条目：${snap.data ?? '...'}'),
              ),
              onTap: () async {
                await clearJwxtCache(jwxt: session.jwxt!);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('教务缓存已清空')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }
}

class _CardPage extends StatelessWidget {
  const _CardPage({required this.session});
  final SessionController session;

  @override
  Widget build(BuildContext context) {
    return CachedQueryPage(
      title: '校园卡',
      fetcher: (mode) =>
          fetchCardBalance(card: session.card!, mode: mode),
      builder: (context, data) {
        final b = data as Map<String, dynamic>;
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            Text('余额', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '${b['display'] ?? '${b['amount']}元'}',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 24),
            FilledButton.tonal(
              onPressed: () async {
                await clearCardCache(card: session.card!);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('校园卡缓存已清空，请下拉刷新')),
                  );
                }
              },
              child: const Text('清空余额缓存'),
            ),
          ],
        );
      },
    );
  }
}

class _CourseSelectPage extends StatefulWidget {
  const _CourseSelectPage({required this.session});
  final SessionController session;

  @override
  State<_CourseSelectPage> createState() => _CourseSelectPageState();
}

class _CourseSelectPageState extends State<_CourseSelectPage> {
  SelectionContextHandle? _ctx;
  List<dynamic> _tabs = const [];
  String? _kklxdm;
  String? _xkkzId;
  String _filter = '';
  bool _onlyAvailable = false;
  bool _loading = true;
  String? _error;
  List<dynamic> _courses = const [];
  List<dynamic> _chosen = const [];

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ctx = await fetchSelectionContext(jwxt: widget.session.jwxt!);
      final raw = await selectionContextJson(ctx: ctx);
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final tabs = (map['tabs'] as List?) ?? const [];
      setState(() {
        _ctx = ctx;
        _tabs = tabs;
        if (tabs.isNotEmpty) {
          _kklxdm = '${tabs.first['kklxdm']}';
          _xkkzId = '${tabs.first['xkkz_id']}';
        }
        _loading = false;
      });
      await Future.wait([_search(), _loadChosen()]);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _search() async {
    if (_ctx == null || _kklxdm == null) return;
    final raw = await searchSelectableCourses(
      jwxt: widget.session.jwxt!,
      ctx: _ctx!,
      query: BridgeSelectableSearch(
        year: widget.session.year,
        term: widget.session.term,
        kklxdm: _kklxdm!,
        filter: _filter.isEmpty ? null : _filter,
        pageStart: 1,
        pageEnd: 20,
        onlyAvailable: _onlyAvailable,
      ),
    );
    final decoded = jsonDecode(raw);
    setState(() {
      if (decoded is List) {
        _courses = decoded;
      } else if (decoded is Map && decoded['tmpList'] is List) {
        _courses = decoded['tmpList'] as List;
      } else if (decoded is Map && decoded['items'] is List) {
        _courses = decoded['items'] as List;
      } else {
        _courses = [decoded];
      }
    });
  }

  Future<void> _loadChosen() async {
    if (_ctx == null) return;
    final raw = await selectionChosen(
      jwxt: widget.session.jwxt!,
      ctx: _ctx!,
      year: widget.session.year,
      term: widget.session.term,
    );
    final decoded = jsonDecode(raw);
    setState(() {
      if (decoded is List) {
        _chosen = decoded;
      } else if (decoded is Map && decoded['tmpList'] is List) {
        _chosen = decoded['tmpList'] as List;
      } else {
        _chosen = decoded is List ? decoded : [decoded];
      }
    });
  }

  Future<void> _details(Map course) async {
    if (_ctx == null || _kklxdm == null || _xkkzId == null) return;
    final kchId = '${course['kch_id'] ?? course['kchid'] ?? ''}';
    if (kchId.isEmpty) return;
    final raw = await selectableClassDetails(
      jwxt: widget.session.jwxt!,
      ctx: _ctx!,
      query: BridgeClassDetailQuery(
        year: widget.session.year,
        term: widget.session.term,
        kklxdm: _kklxdm!,
        kchId: kchId,
        xkkzId: _xkkzId!,
      ),
    );
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(16),
          children: [
            Text('教学班详情', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            SelectableText(const JsonEncoder.withIndent('  ').convert(jsonDecode(raw))),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!),
              const SizedBox(height: 12),
              FilledButton(onPressed: _boot, child: const Text('重试')),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        YearTermControls(
          year: widget.session.year,
          term: widget.session.term,
          onChanged: (y, t) async {
            await widget.session.setPeriod(year: y, term: t);
            await Future.wait([_search(), _loadChosen()]);
          },
        ),
        if (_tabs.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                for (final t in _tabs)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('${t['name']}'),
                      selected: _kklxdm == '${t['kklxdm']}',
                      onSelected: (_) async {
                        setState(() {
                          _kklxdm = '${t['kklxdm']}';
                          _xkkzId = '${t['xkkz_id']}';
                        });
                        await _search();
                      },
                    ),
                  ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: '课程名过滤',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) => _filter = v,
                  onSubmitted: (_) => _search(),
                ),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('仅余量'),
                selected: _onlyAvailable,
                onSelected: (v) async {
                  setState(() => _onlyAvailable = v);
                  await _search();
                },
              ),
              IconButton(onPressed: _search, icon: const Icon(Icons.search)),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await Future.wait([_search(), _loadChosen()]);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const ListTile(title: Text('可选课程（只读）')),
                for (final c in _courses)
                  ListTile(
                    title: Text('${c['kcmc'] ?? c['name'] ?? c}'),
                    subtitle: Text('${c['kch'] ?? ''} · ${c['xf'] ?? ''}学分'),
                    onTap: c is Map
                        ? () => _details(Map<String, dynamic>.from(c))
                        : null,
                  ),
                const Divider(),
                const ListTile(title: Text('选课模块已选')),
                for (final c in _chosen)
                  ListTile(
                    title: Text('${c['kcmc'] ?? c['name'] ?? c}'),
                    subtitle: Text('${c['jsxx'] ?? c['teacher'] ?? ''}'),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
