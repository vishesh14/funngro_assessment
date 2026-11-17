import 'dart:math';

class Project {
  final String id;
  final String title;
  final String company;
  final int payout;

  const Project({
    required this.id,
    required this.title,
    required this.company,
    required this.payout,
  });
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => 'ApiException: $message';
}

// ---- Provided fake API, unchanged ----------------------------------------
class ProjectsApi {
  final _rng = Random();

  /// Returns 20 projects per page. Pages 0..7 exist.
  /// ~900ms latency. Fails (throws ApiException) roughly 1 in 5 calls.
  Future<List<Project>> fetchProjects(int page) async {
    await Future.delayed(Duration(milliseconds: 900));
    if (_rng.nextInt(5) == 0) throw ApiException('server error');
    if (page > 7) return [];
    return List.generate(20, (i) => Project(
      id: 'p${page * 20 + i}',
      title: 'Project ${page * 20 + i}',
      company: 'Company ${_rng.nextInt(50)}',
      payout: 200 + _rng.nextInt(1800),
    ));
  }
}
