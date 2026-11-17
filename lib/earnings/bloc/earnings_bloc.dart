import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../earnings_fakes.dart'; // In the real app: the existing api and models.

part 'earnings_event.dart';
part 'earnings_state.dart';

/// One bloc per user. If the user changes, the screen creates a new bloc
/// (see EarningsScreen), so there is no stale-user data to worry about here.
class EarningsBloc extends Bloc<EarningsEvent, EarningsState> {
  final String userId;
  final FakeEarningsApi _api;

  StreamSubscription<WalletUpdate>? _walletSub;
  final Set<String> _ids = {}; // for de-duplicating wallet updates
  final List<Earning> _bufferedUpdates = []; // arrived before the first load
  final Map<String, EarningDetail> _detailCache = {};

  EarningsBloc({required this.userId, required FakeEarningsApi api})
      : _api = api,
        super(const EarningsState()) {
    on<EarningsStarted>(_onStarted, transformer: droppable());
    on<EarningsRetryRequested>(_onRetry, transformer: droppable());
    on<_WalletUpdateReceived>(_onWalletUpdate);
    // droppable(): taps while a detail is loading are ignored.
    on<EarningTapped>(_onTapped, transformer: droppable());
    on<EarningDetailOpened>(
        (_, emit) => emit(state.copyWith(clearDetailToOpen: true)));
  }

  Future<void> _onStarted(
    EarningsStarted event,
    Emitter<EarningsState> emit,
  ) async {
    await _walletSub?.cancel();
    // Subscribe BEFORE fetching so updates during the fetch aren't missed.
    _walletSub = _api.walletUpdates(userId).listen(
          (update) => add(_WalletUpdateReceived(update.toEarning())),
          onError: (Object e) => debugPrint('walletUpdates error: $e'),
        );
    await _load(emit);
  }

  Future<void> _onRetry(
    EarningsRetryRequested event,
    Emitter<EarningsState> emit,
  ) async {
    emit(state.copyWith(status: EarningsStatus.loading));
    await _load(emit);
  }

  Future<void> _load(Emitter<EarningsState> emit) async {
    try {
      final data = await _api.fetchEarnings(userId);

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

      emit(state.copyWith(
        status: EarningsStatus.loaded,
        earnings: [...newOnes, ...data],
      ));
    } catch (_) {
      emit(state.copyWith(status: EarningsStatus.error));
    }
  }

  void _onWalletUpdate(
    _WalletUpdateReceived event,
    Emitter<EarningsState> emit,
  ) {
    if (state.status != EarningsStatus.loaded) {
      _bufferedUpdates.add(event.earning); // merged when the fetch finishes
      return;
    }
    if (!_ids.add(event.earning.id)) return; // already shown
    emit(state.copyWith(earnings: [event.earning, ...state.earnings]));
  }

  Future<void> _onTapped(
    EarningTapped event,
    Emitter<EarningsState> emit,
  ) async {
    final id = event.earning.id;
    final cached = _detailCache[id];
    if (cached != null) {
      emit(state.copyWith(detailToOpen: cached));
      return;
    }

    emit(state.copyWith(openingId: id));
    try {
      final detail = await _api.fetchDetail(id);
      _detailCache[id] = detail;
      emit(state.copyWith(clearOpeningId: true, detailToOpen: detail));
    } catch (_) {
      emit(state.copyWith(
        clearOpeningId: true,
        detailFailures: state.detailFailures + 1,
      ));
    }
  }

  @override
  Future<void> close() async {
    // Stop the stream first, so no event is added to a closed bloc.
    await _walletSub?.cancel();
    return super.close();
  }
}
