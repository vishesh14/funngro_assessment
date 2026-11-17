import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'earnings_fakes.dart'; // In the real app: the existing api / models / widgets.

/// Built ONCE for the whole app. The original `formatCurrency` cost ~3ms per
/// call because it re-parsed locale data each time; formatting with a cached
/// NumberFormat takes microseconds.
final NumberFormat _inr =
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

enum _Status { loading, error, loaded }

class EarningsScreen extends StatefulWidget {
  final String userId;
  const EarningsScreen({super.key, required this.userId});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  _Status _status = _Status.loading;
  List<Earning> _earnings = const [];
  final Set<String> _ids = {}; // for de-duplicating wallet updates

  // Updates that arrive while the first fetch is still running.
  final List<Earning> _bufferedUpdates = [];
  StreamSubscription<WalletUpdate>? _walletSub;

  // Details already fetched, so a second tap doesn't re-download.
  final Map<String, EarningDetail> _detailCache = {};
  String? _openingId; // non-null while a detail is loading (blocks double taps)

  // ---------------------------------------------------------------- lifecycle

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(EarningsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Same State object can be reused with a different user: restart cleanly.
    if (oldWidget.userId != widget.userId) _start();
  }

  @override
  void dispose() {
    _walletSub?.cancel(); // no more events -> no setState after dispose
    super.dispose();
  }

  // --------------------------------------------------------------------- data

  /// Only called from initState / didUpdateWidget. Flutter always calls build()
  /// right after those, so we set fields directly instead of calling setState.
  void _start() {
    _walletSub?.cancel();
    _status = _Status.loading;
    _earnings = const [];
    _bufferedUpdates.clear();
    _detailCache.clear();
    // Subscribe BEFORE fetching so updates during the fetch aren't missed.
    _walletSub = api.walletUpdates(widget.userId).listen(
          _onWalletUpdate,
          onError: (Object e) => debugPrint('walletUpdates error: $e'),
        );
    _load();
  }

  void _retry() {
    setState(() => _status = _Status.loading);
    _load();
  }

  Future<void> _load() async {
    final userId = widget.userId;
    try {
      final data = await api.fetchEarnings(userId);
      // The screen may have closed, or switched user, while we waited.
      if (!mounted || userId != widget.userId) return;

      _ids
        ..clear()
        ..addAll(data.map((e) => e.id));
      // Updates that arrived during the fetch: keep only ones the fetch didn't
      // already include. They arrived oldest-first, so newest ends up on top.
      final newOnes = <Earning>[];
      for (final e in _bufferedUpdates) {
        if (_ids.add(e.id)) newOnes.insert(0, e);
      }
      _bufferedUpdates.clear();

      setState(() {
        _earnings = [...newOnes, ...data];
        _status = _Status.loaded;
      });
    } catch (e) {
      if (!mounted || userId != widget.userId) return;
      setState(() => _status = _Status.error);
    }
  }

  void _onWalletUpdate(WalletUpdate update) {
    final earning = update.toEarning();
    if (_status != _Status.loaded) {
      _bufferedUpdates.add(earning); // merged when the fetch finishes
      return;
    }
    if (!_ids.add(earning.id)) return; // already shown
    setState(() => _earnings = [earning, ..._earnings]);
  }

  Future<void> _openDetail(Earning e) async {
    if (_openingId != null) return; // ignore double taps
    EarningDetail? detail = _detailCache[e.id];
    if (detail == null) {
      setState(() => _openingId = e.id);
      try {
        detail = await api.fetchDetail(e.id);
        _detailCache[e.id] = detail;
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Couldn't load details. Try again.")),
          );
        }
      } finally {
        if (mounted) setState(() => _openingId = null);
      }
    }
    // Never use `context` after an await without checking we're still here.
    if (detail == null || !mounted) return;
    final loaded = detail;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DetailScreen(detail: loaded)),
    );
  }

  // ------------------------------------------------------------------------ UI

  @override
  Widget build(BuildContext context) {
    // build() only DESCRIBES the UI. No network calls, no subscriptions here.
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Earnings'),
        bottom: _openingId == null
            ? null
            : const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              ),
      ),
      body: switch (_status) {
        _Status.loading => const Center(child: CircularProgressIndicator()),
        _Status.error => _ErrorView(onRetry: _retry),
        _Status.loaded => _earnings.isEmpty ? const _EmptyView() : _buildList(),
      },
    );
  }

  Widget _buildList() {
    // ListView.builder only builds the ~10 rows on screen, not all 3,000.
    return ListView.builder(
      itemCount: _earnings.length,
      itemBuilder: (context, index) {
        final e = _earnings[index];
        return EarningTile(
          key: ValueKey(e.id), // keeps row identity stable when new items are inserted at the top
          earning: e,
          subtitle: _inr.format(e.amount),
          onTap: _openingId == null ? () => _openDetail(e) : null,
        );
      },
    );
  }
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("Couldn't load your earnings."),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'No earnings yet. Complete a project to see your earnings here!',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
