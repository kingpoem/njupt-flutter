import 'package:flutter/material.dart';

import 'package:njupt_flutter/session.dart';
import 'package:njupt_flutter/src/rust/api/jwxt.dart';
import 'package:njupt_flutter/util/cached.dart';

/// 当前页注册的「强制刷新」回调，供顶栏刷新按钮调用。
class PageRefresh extends ChangeNotifier {
  Future<void> Function()? _handler;

  bool get available => _handler != null;

  void bind(Future<void> Function() handler) {
    if (_handler == handler) return;
    _handler = handler;
    notifyListeners();
  }

  void unbind(Future<void> Function() handler) {
    if (_handler != handler) return;
    _handler = null;
    notifyListeners();
  }

  Future<void> refresh() async {
    final handler = _handler;
    if (handler != null) await handler();
  }
}

class PageRefreshScope extends InheritedNotifier<PageRefresh> {
  const PageRefreshScope({
    super.key,
    required PageRefresh controller,
    required super.child,
  }) : super(notifier: controller);

  static PageRefresh of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<PageRefreshScope>();
    assert(scope != null, 'PageRefreshScope not found');
    return scope!.notifier!;
  }

  static PageRefresh? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<PageRefreshScope>()
        ?.notifier;
  }
}

class YearTermControls extends StatelessWidget {
  const YearTermControls({
    super.key,
    required this.year,
    required this.term,
    required this.onChanged,
    this.allYears = false,
    this.onAllYearsChanged,
  });

  final int year;
  final BridgeTerm term;
  final void Function(int year, BridgeTerm term) onChanged;
  final bool allYears;
  final ValueChanged<bool>? onAllYearsChanged;

  @override
  Widget build(BuildContext context) {
    final years = List.generate(8, (i) => DateTime.now().year - i);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (onAllYearsChanged != null)
            FilterChip(
              label: const Text('不限学年学期'),
              selected: allYears,
              onSelected: onAllYearsChanged,
            ),
          DropdownButton<int>(
            value: year,
            items: [
              for (final y in years)
                DropdownMenuItem(value: y, child: Text('$y-${y + 1}')),
            ],
            onChanged: allYears
                ? null
                : (v) {
                    if (v != null) onChanged(v, term);
                  },
          ),
          SegmentedButton<BridgeTerm>(
            segments: const [
              ButtonSegment(value: BridgeTerm.first, label: Text('一学期')),
              ButtonSegment(value: BridgeTerm.second, label: Text('二学期')),
            ],
            selected: {term},
            onSelectionChanged: allYears
                ? null
                : (s) => onChanged(year, s.first),
          ),
        ],
      ),
    );
  }
}

typedef CachedFetcher = Future<String> Function(BridgeFetchMode mode);

class CachedQueryPage extends StatefulWidget {
  const CachedQueryPage({
    super.key,
    required this.title,
    required this.fetcher,
    required this.builder,
    required this.session,
    required this.diskKey,
    this.header,
  });

  final String title;
  final CachedFetcher fetcher;
  final Widget Function(BuildContext context, dynamic data) builder;
  final Widget? header;
  final SessionController session;
  final String diskKey;

  @override
  State<CachedQueryPage> createState() => _CachedQueryPageState();
}

class _CachedQueryPageState extends State<CachedQueryPage> {
  bool _loading = true;
  String? _error;
  CachedPayload? _payload;
  PageRefresh? _refresh;

  Future<void> _forceRefresh() => _loadNetwork(BridgeFetchMode.networkOnly);

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void didUpdateWidget(covariant CachedQueryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.diskKey != widget.diskKey ||
        oldWidget.session.username != widget.session.username) {
      _bootstrap();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final refresh = PageRefreshScope.maybeOf(context);
    if (!identical(refresh, _refresh)) {
      _refresh?.unbind(_forceRefresh);
      _refresh = refresh;
    }
    _refresh?.bind(_forceRefresh);
  }

  @override
  void dispose() {
    _refresh?.unbind(_forceRefresh);
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final user = widget.session.username?.trim() ?? '';
    if (user.isNotEmpty) {
      final disk = await widget.session.diskCache.readEnvelope(user, widget.diskKey);
      if (!mounted) return;
      if (disk != null) {
        setState(() {
          _payload = CachedPayload.parse(disk);
          _loading = widget.session.jwxt == null;
        });
      }
    }

    await widget.session.whenOnline;
    if (!mounted) return;

    if (widget.session.jwxt == null) {
      setState(() {
        _loading = false;
        if (_payload == null) {
          _error = widget.session.lastError ?? '未登录，且无本地缓存';
        }
      });
      return;
    }

    await _loadNetwork(
      _payload != null ? BridgeFetchMode.cacheFirst : BridgeFetchMode.cacheFirst,
    );
  }

  Future<void> _loadNetwork(BridgeFetchMode mode) async {
    if (widget.session.jwxt == null) {
      await widget.session.whenOnline;
      if (widget.session.jwxt == null) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error ??= widget.session.lastError ?? '未登录';
          });
        }
        return;
      }
    }

    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final raw = await widget.fetcher(mode);
      final user = widget.session.username?.trim() ?? '';
      if (user.isNotEmpty) {
        await widget.session.diskCache.writeEnvelope(user, widget.diskKey, raw);
      }
      if (!mounted) return;
      setState(() {
        _payload = CachedPayload.parse(raw);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.session.signingIn ||
            (widget.session.jwxt == null && _payload != null))
          Material(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Expanded(child: Text('正在后台登录，先显示本地缓存…')),
                ],
              ),
            ),
          ),
        if (widget.header != null) widget.header!,
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _loadNetwork(BridgeFetchMode.networkOnly),
            child: _buildBody(),
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading && _payload == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }
    if (_error != null && _payload == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => _loadNetwork(BridgeFetchMode.networkOnly),
            child: const Text('重试'),
          ),
        ],
      );
    }
    return Stack(
      children: [
        widget.builder(context, _payload!.data),
        if (_loading)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(minHeight: 2),
          ),
      ],
    );
  }
}
