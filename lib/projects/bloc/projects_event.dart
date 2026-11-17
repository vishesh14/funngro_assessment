part of 'projects_bloc.dart';

sealed class ProjectsEvent {
  const ProjectsEvent();
}

/// Sent on first open and whenever the user scrolls near the bottom.
/// Ignored while a load is running, after an error, or at the end of the list.
final class ProjectsNextPageRequested extends ProjectsEvent {
  const ProjectsNextPageRequested();
}

/// The user tapped Retry after a failed page load.
final class ProjectsRetryRequested extends ProjectsEvent {
  const ProjectsRetryRequested();
}

/// Pull-to-refresh. [completer] finishes when the refresh is done, so the
/// RefreshIndicator spinner knows when to hide.
final class ProjectsRefreshRequested extends ProjectsEvent {
  final Completer<void>? completer;
  const ProjectsRefreshRequested({this.completer});
}
