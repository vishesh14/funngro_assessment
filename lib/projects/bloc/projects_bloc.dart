import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../projects_api.dart';

part 'projects_event.dart';
part 'projects_state.dart';

class ProjectsBloc extends Bloc<ProjectsEvent, ProjectsState> {
  static const pageSize = 20;

  final ProjectsApi _api;

  /// Bumped on every refresh. A page response that comes back with an older
  /// number is stale (the list was reset meanwhile) and is thrown away.
  int _generation = 0;

  ProjectsBloc(this._api) : super(const ProjectsState()) {
    // droppable(): while a handler is still running, new events of the same
    // type are ignored. Fast scrolling sends many "next page" events; only
    // one request goes out.
    on<ProjectsNextPageRequested>(_onNextPage, transformer: droppable());
    on<ProjectsRetryRequested>(_onRetry, transformer: droppable());
    on<ProjectsRefreshRequested>(_onRefresh, transformer: droppable());
  }

  Future<void> _onNextPage(
    ProjectsNextPageRequested event,
    Emitter<ProjectsState> emit,
  ) async {
    // No automatic retry after an error: on a failing server every scroll
    // would fire another request. The user decides by tapping Retry.
    if (state.error != null) return;
    await _loadPage(emit);
  }

  Future<void> _onRetry(
    ProjectsRetryRequested event,
    Emitter<ProjectsState> emit,
  ) =>
      _loadPage(emit);

  Future<void> _loadPage(Emitter<ProjectsState> emit) async {
    if (state.isLoading || state.isRefreshing || !state.hasMore) return;

    final gen = _generation;
    final page = state.nextPage;
    emit(state.copyWith(isLoading: true, clearError: true));

    try {
      final result = await _api.fetchProjects(page);
      if (gen != _generation) return; // a refresh happened meanwhile
      emit(state.copyWith(
        items: [...state.items, ...result],
        nextPage: page + 1,
        hasMore: result.length == pageSize,
        isLoading: false,
      ));
    } catch (e) {
      if (gen != _generation) return;
      // items are untouched: already-loaded projects stay on screen.
      emit(state.copyWith(error: e, isLoading: false));
    }
  }

  Future<void> _onRefresh(
    ProjectsRefreshRequested event,
    Emitter<ProjectsState> emit,
  ) async {
    _generation++; // any in-flight page load is now stale
    // isLoading: false because the abandoned request will never clear it.
    emit(state.copyWith(isRefreshing: true, isLoading: false));

    try {
      final first = await _api.fetchProjects(0);
      emit(state.copyWith(
        items: first,
        nextPage: 1,
        hasMore: first.length == pageSize,
        clearError: true,
        isRefreshing: false,
      ));
    } catch (_) {
      // Keep the old list - better than wiping it on a flaky network.
      emit(state.copyWith(
        isRefreshing: false,
        refreshFailures: state.refreshFailures + 1,
      ));
    } finally {
      event.completer?.complete();
    }
  }
}
