import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'bloc/projects_bloc.dart';
import 'projects_api.dart';

/// Infinite-scroll projects list.
///
/// Data flow: UI sends events -> ProjectsBloc talks to the API -> emits a new
/// ProjectsState -> BlocBuilder redraws. All loading/error/paging rules live in
/// the bloc; this file only draws the state and forwards user actions.
class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // BlocProvider creates the bloc once and closes it when the screen leaves.
    return BlocProvider(
      create: (_) =>
          ProjectsBloc(ProjectsApi())..add(const ProjectsNextPageRequested()),
      child: const _ProjectsView(),
    );
  }
}

/// Stateful only to own the ScrollController (a UI object, not app state).
class _ProjectsView extends StatefulWidget {
  const _ProjectsView();

  @override
  State<_ProjectsView> createState() => _ProjectsViewState();
}

class _ProjectsViewState extends State<_ProjectsView> {
  static const _loadMoreThresholdPx = 400.0;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - _loadMoreThresholdPx) {
      // Safe to send often: the bloc ignores it while loading / after errors.
      context.read<ProjectsBloc>().add(const ProjectsNextPageRequested());
    }
  }

  Future<void> _onRefresh() {
    final done = Completer<void>();
    context
        .read<ProjectsBloc>()
        .add(ProjectsRefreshRequested(completer: done));
    return done.future; // RefreshIndicator spins until this completes
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Projects')),
      // BlocListener = one-time side effects (SnackBar), not drawing.
      body: BlocListener<ProjectsBloc, ProjectsState>(
        listenWhen: (prev, curr) => prev.refreshFailures != curr.refreshFailures,
        listener: (context, state) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("Couldn't refresh. Showing older results.")),
          );
        },
        child: BlocBuilder<ProjectsBloc, ProjectsState>(
          builder: (context, state) => _buildBody(context, state),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ProjectsState state) {
    // ---- Nothing loaded yet: full-screen states ----
    if (state.items.isEmpty) {
      if (state.error != null) {
        return _FullScreenError(
          onRetry: () =>
              context.read<ProjectsBloc>().add(const ProjectsRetryRequested()),
        );
      }
      if (state.isLoading || state.hasMore) {
        return const Center(child: CircularProgressIndicator()); // first load
      }
      return const Center(child: Text('No projects available right now.'));
    }

    // ---- Have items: list + footer that shows the page state ----
    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: state.items.length + 1, // +1 = footer row
        itemBuilder: (context, index) {
          if (index == state.items.length) return _buildFooter(context, state);
          final p = state.items[index];
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

  Widget _buildFooter(BuildContext context, ProjectsState state) {
    if (state.isRefreshing) return const SizedBox(height: 56);
    if (state.error != null) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            const Expanded(child: Text("Couldn't load more projects.")),
            TextButton(
              onPressed: () => context
                  .read<ProjectsBloc>()
                  .add(const ProjectsRetryRequested()),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (!state.hasMore) {
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
