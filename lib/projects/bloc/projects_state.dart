part of 'projects_bloc.dart';

/// Immutable snapshot of the projects screen. The UI is a pure function of it.
class ProjectsState {
  /// Projects loaded so far. A failed load never clears this.
  final List<Project> items;

  /// The page to ask for next.
  final int nextPage;

  /// A page request is in flight.
  final bool isLoading;

  /// The last page load failed; the user must tap Retry.
  final Object? error;

  /// False once the API returns a short (or empty) page.
  final bool hasMore;

  /// Pull-to-refresh is running; page loads are paused.
  final bool isRefreshing;

  /// Goes up by one on every failed refresh. The UI shows a SnackBar when it
  /// changes (a one-time message, not something to keep showing).
  final int refreshFailures;

  const ProjectsState({
    this.items = const [],
    this.nextPage = 0,
    this.isLoading = false,
    this.error,
    this.hasMore = true,
    this.isRefreshing = false,
    this.refreshFailures = 0,
  });

  ProjectsState copyWith({
    List<Project>? items,
    int? nextPage,
    bool? isLoading,
    Object? error,
    bool clearError = false,
    bool? hasMore,
    bool? isRefreshing,
    int? refreshFailures,
  }) {
    return ProjectsState(
      items: items ?? this.items,
      nextPage: nextPage ?? this.nextPage,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      hasMore: hasMore ?? this.hasMore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      refreshFailures: refreshFailures ?? this.refreshFailures,
    );
  }
}
