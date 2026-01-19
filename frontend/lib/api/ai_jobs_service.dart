import 'api_client.dart';

class AiJob {
  final String id;
  final String status;
  final int progress;
  final String createdAt;
  final String? updatedAt;
  final String? error;
  final String? prompt;

  const AiJob({
    required this.id,
    required this.status,
    required this.progress,
    required this.createdAt,
    this.updatedAt,
    this.error,
    this.prompt,
  });

  factory AiJob.fromJson(Map<String, dynamic> json) {
    return AiJob(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      progress: (json['progress'] ?? 0) as int,
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString(),
      error: json['error']?.toString(),
      prompt: json['prompt']?.toString(),
    );
  }
}

class AiJobsService {
  AiJobsService(this._api);

  final ApiClient _api;

  Future<AiJob> createJob({
    required String prompt,
    Map<String, dynamic>? settings,
  }) async {
    final data = await _api.postJson('/ai/jobs',
        auth: true,
        body: {'prompt': prompt, 'settings': settings ?? {}});
    return AiJob.fromJson(data);
  }

  Future<List<AiJob>> listJobs({int limit = 20, int offset = 0}) async {
    final list = await _api.getJsonList('/ai/jobs',
        auth: true, query: {'limit': '$limit', 'offset': '$offset'});
    return list
        .whereType<Map<String, dynamic>>()
        .map(AiJob.fromJson)
        .toList();
  }
}
