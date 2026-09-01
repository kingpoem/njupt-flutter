import 'package:flutter/material.dart';

import 'package:njupt_flutter/src/rust/api/jwxt.dart';
import 'package:njupt_flutter/util/cached.dart';

class CacheBanner extends StatelessWidget {
  const CacheBanner({super.key, required this.fromCache, this.onForceRefresh});

  final bool? fromCache;
  final VoidCallback? onForceRefresh;

  @override
  Widget build(BuildContext context) {
    if (fromCache == null) return const SizedBox.shrink();
    final cached = fromCache!;
    return Material(
      color: cached
          ? Theme.of(context).colorScheme.secondaryContainer
          : Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Icon(cached ? Icons.history : Icons.cloud_done_outlined, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(cached ? '来自内存缓存' : '网络已刷新')),
            if (onForceRefresh != null)
              TextButton(
                onPressed: onForceRefresh,
                child: const Text('强制刷新'),
              ),
          ],
        ),
      ),
    );
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
    this.header,
  });

  final String title;
  final CachedFetcher fetcher;
  final Widget Function(BuildContext context, dynamic data) builder;
  final Widget? header;

  @override
  State<CachedQueryPage> createState() => _CachedQueryPageState();
}

class _CachedQueryPageState extends State<CachedQueryPage> {
  bool _loading = true;
  String? _error;
  CachedPayload? _payload;

  @override
  void initState() {
    super.initState();
    _load(BridgeFetchMode.cacheFirst);
  }

  Future<void> _load(BridgeFetchMode mode) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await widget.fetcher(mode);
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
        if (widget.header != null) widget.header!,
        CacheBanner(
          fromCache: _payload?.fromCache,
          onForceRefresh: () => _load(BridgeFetchMode.networkOnly),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _load(BridgeFetchMode.networkOnly),
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
            onPressed: () => _load(BridgeFetchMode.networkOnly),
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
