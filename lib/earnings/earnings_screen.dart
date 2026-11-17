import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'bloc/earnings_bloc.dart';
import 'earnings_fakes.dart'; // In the real app: the existing api / models / widgets.

/// Built ONCE for the whole app. The original `formatCurrency` cost ~3ms per
/// call because it re-parsed locale data each time; formatting with a cached
/// NumberFormat takes microseconds.
final NumberFormat _inr =
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

/// Data flow: UI sends events -> EarningsBloc (API + wallet stream) -> emits
/// EarningsState -> BlocBuilder redraws. build() never fetches or subscribes.
class EarningsScreen extends StatelessWidget {
  final String userId;
  const EarningsScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      // A new userId gives a new key -> a new bloc for the new user. The old
      // bloc is closed automatically, which cancels its wallet subscription.
      key: ValueKey(userId),
      create: (_) => EarningsBloc(userId: userId, api: api)
        ..add(const EarningsStarted()),
      child: const _EarningsView(),
    );
  }
}

class _EarningsView extends StatelessWidget {
  const _EarningsView();

  @override
  Widget build(BuildContext context) {
    // Listeners handle one-time side effects (navigation, SnackBar). They only
    // run while this widget is on screen, so no `mounted` checks are needed.
    return MultiBlocListener(
      listeners: [
        BlocListener<EarningsBloc, EarningsState>(
          listenWhen: (prev, curr) =>
              prev.detailToOpen == null && curr.detailToOpen != null,
          listener: (context, state) {
            final detail = state.detailToOpen!;
            context.read<EarningsBloc>().add(const EarningDetailOpened());
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => DetailScreen(detail: detail)),
            );
          },
        ),
        BlocListener<EarningsBloc, EarningsState>(
          listenWhen: (prev, curr) =>
              prev.detailFailures != curr.detailFailures,
          listener: (context, state) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Couldn't load details. Try again.")),
            );
          },
        ),
      ],
      child: BlocBuilder<EarningsBloc, EarningsState>(
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('My Earnings'),
              bottom: state.openingId == null
                  ? null
                  : const PreferredSize(
                      preferredSize: Size.fromHeight(2),
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
            ),
            body: switch (state.status) {
              EarningsStatus.loading =>
                const Center(child: CircularProgressIndicator()),
              EarningsStatus.error => _ErrorView(
                  onRetry: () => context
                      .read<EarningsBloc>()
                      .add(const EarningsRetryRequested()),
                ),
              EarningsStatus.loaded => state.earnings.isEmpty
                  ? const _EmptyView()
                  : _EarningsList(state: state),
            },
          );
        },
      ),
    );
  }
}

class _EarningsList extends StatelessWidget {
  final EarningsState state;
  const _EarningsList({required this.state});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<EarningsBloc>();
    final canTap = state.openingId == null;
    // ListView.builder only builds the ~10 rows on screen, not all 3,000.
    return ListView.builder(
      itemCount: state.earnings.length,
      itemBuilder: (context, index) {
        final e = state.earnings[index];
        return EarningTile(
          key: ValueKey(e.id), // stable identity when items are inserted on top
          earning: e,
          subtitle: _inr.format(e.amount),
          onTap: canTap ? () => bloc.add(EarningTapped(e)) : null,
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
