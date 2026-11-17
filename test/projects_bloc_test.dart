import 'package:flutter_test/flutter_test.dart';

import 'package:funngro_assessment/projects/bloc/projects_bloc.dart';
import 'package:funngro_assessment/projects/projects_api.dart';

/// Fake API that returns pre-scripted answers in order: a List<Project> is
/// returned, an Exception is thrown. No delay, no randomness.
class _ScriptedApi extends ProjectsApi {
  _ScriptedApi(this._responses);
  final List<Object> _responses;
  int calls = 0;

  @override
  Future<List<Project>> fetchProjects(int page) async {
    calls++;
    final next = _responses.removeAt(0);
    if (next is Exception) throw next;
    return next as List<Project>;
  }
}

List<Project> _page(int n, {int size = 20}) => List.generate(
      size,
      (i) => Project(id: 'p${n * 20 + i}', title: 'P', company: 'C', payout: 0),
    );

/// Lets the bloc finish processing queued events.
Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  test('first page loads', () async {
    final bloc = ProjectsBloc(_ScriptedApi([_page(0)]));
    bloc.add(const ProjectsNextPageRequested());
    await _settle();

    expect(bloc.state.items.length, 20);
    expect(bloc.state.nextPage, 1);
    expect(bloc.state.hasMore, true);
    expect(bloc.state.error, isNull);
    await bloc.close();
  });

  test('failed page keeps items, no auto-retry, Retry recovers', () async {
    final api = _ScriptedApi([_page(0), ApiException('boom'), _page(1)]);
    final bloc = ProjectsBloc(api);

    bloc.add(const ProjectsNextPageRequested());
    await _settle();
    bloc.add(const ProjectsNextPageRequested()); // fails
    await _settle();
    expect(bloc.state.error, isA<ApiException>());
    expect(bloc.state.items.length, 20); // not lost

    bloc.add(const ProjectsNextPageRequested()); // scroll: ignored after error
    await _settle();
    expect(api.calls, 2);

    bloc.add(const ProjectsRetryRequested());
    await _settle();
    expect(bloc.state.error, isNull);
    expect(bloc.state.items.length, 40);
    await bloc.close();
  });

  test('short page means end of list', () async {
    final api = _ScriptedApi([_page(0, size: 5)]);
    final bloc = ProjectsBloc(api);

    bloc.add(const ProjectsNextPageRequested());
    await _settle();
    expect(bloc.state.hasMore, false);

    bloc.add(const ProjectsNextPageRequested()); // must not call the API
    await _settle();
    expect(api.calls, 1);
    await bloc.close();
  });

  test('refresh resets to page 0', () async {
    final bloc = ProjectsBloc(_ScriptedApi([_page(0), _page(1), _page(0)]));
    bloc.add(const ProjectsNextPageRequested());
    await _settle();
    bloc.add(const ProjectsNextPageRequested());
    await _settle();
    expect(bloc.state.items.length, 40);

    bloc.add(const ProjectsRefreshRequested());
    await _settle();
    expect(bloc.state.items.length, 20);
    expect(bloc.state.nextPage, 1);
    expect(bloc.state.isRefreshing, false);
    await bloc.close();
  });

  test('failed refresh keeps old items and reports once', () async {
    final bloc = ProjectsBloc(_ScriptedApi([_page(0), ApiException('boom')]));
    bloc.add(const ProjectsNextPageRequested());
    await _settle();

    bloc.add(const ProjectsRefreshRequested());
    await _settle();
    expect(bloc.state.items.length, 20);
    expect(bloc.state.refreshFailures, 1);
    expect(bloc.state.isRefreshing, false);
    await bloc.close();
  });
}
