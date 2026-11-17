import 'package:flutter/material.dart';

import 'projects_api.dart';

/// Infinite-scroll projects list.
///
/// All state lives in this one State class so the flow is easy to follow:
///   _items        projects loaded so far (never cleared by a failed load)
///   _nextPage     the page to ask for next
///   _isLoading    a page request is in flight
///   _error        the last page request failed (user must tap Retry)
///   _hasMore      false once the API returns a short/empty page
///   _isRefreshing pull-to-refresh is running (page loads are paused)
///   _generation   bumped on refresh; responses from older requests are ignored
class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  static const _pageSize = 20;
  static const _loadMoreThresholdPx = 400.0;

  final _api = ProjectsApi();
  final _scroll = ScrollController();

  List<Project> _items = const [];
  int _nextPage = 0;
  bool _isLoading = false;
  Object? _error;
  bool _hasMore = true;
  bool _isRefreshing = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadNextPage();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - _loadMoreThresholdPx) {
      // Deliberately NOT retrying automatically after an error: on a failing
      // server, every scroll event would fire another request.
      if (_error == null) _loadNextPage();
    }
  }

  Future<void> _loadNextPage() async {
    if (_isLoading || _isRefreshing || !_hasMore) return;
    final gen = _generation;
    final page = _nextPage;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _api.fetchProjects(page);
      if (!mounted || gen != _generation) return; // stale (refresh happened)
      setState(() {
        _items = [..._items, ...result];
        _nextPage = page + 1;
        _hasMore = result.length == _pageSize;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || gen != _generation) return;
      setState(() {
        _error = e; // _items untouched: already-loaded projects stay visible
        _isLoading = false;
      });
    }
  }

  Future<void> _refresh() async {
    final gen = ++_generation; // any in-flight page load is now ignored
    setState(() {
      _isRefreshing = true;
      _isLoading = false; // the abandoned request will never clear this itself
    });

    try {
      final first = await _api.fetchProjects(0);
      if (!mounted || gen != _generation) return;
      setState(() {
        _items = first;
        _nextPage = 1;
        _hasMore = first.length == _pageSize;
        _error = null;
        _isRefreshing = false;
      });
    } catch (e) {
      if (!mounted || gen != _generation) return;
      // Keep the old list - better than wiping it on a flaky network.
      setState(() => _isRefreshing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't refresh. Showing older results.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Projects')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // ---- Nothing loaded yet: full-screen states ----
    if (_items.isEmpty) {
      if (_error != null) {
        return _FullScreenError(onRetry: _loadNextPage);
      }
      if (_isLoading || _hasMore) {
        return const Center(child: CircularProgressIndicator()); // first load
      }
      return const Center(child: Text('No projects available right now.'));
    }

    // ---- Have items: list + footer that shows the page state ----
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _items.length + 1, // +1 = footer row
        itemBuilder: (context, index) {
          if (index == _items.length) return _buildFooter();
          final p = _items[index];
          return ListTile(
            key: ValueKey(p.id),
            title: Text(p.title),
            subtitle: Text(p.company),
            trailing: Text('₹${p.payout}'),
          );
        },
      ),
    );
  }

  Widget _buildFooter() {
    if (_isRefreshing) return const SizedBox(height: 56);
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            const Expanded(child: Text("Couldn't load more projects.")),
            TextButton(onPressed: _loadNextPage, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (!_hasMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: Text("You've reached the end")),
      );
    }
    // Loading the next page (or about to).
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _FullScreenError extends StatelessWidget {
  final VoidCallback onRetry;
  const _FullScreenError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 48),
          const SizedBox(height: 8),
          const Text("Couldn't load projects."),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
