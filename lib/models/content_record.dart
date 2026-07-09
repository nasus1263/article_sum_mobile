class ContentData {
  final String? original;
  final String? title;
  final String? category;
  final Map<String, String>? summaries;
  final bool processing;
  final String? stage;
  final List<String>? images;
  final String? error;
  final String? folder;
  final String? embeddingError;

  const ContentData({
    this.original,
    this.title,
    this.category,
    this.summaries,
    this.processing = false,
    this.stage,
    this.images,
    this.error,
    this.folder,
    this.embeddingError,
  });

  factory ContentData.fromJson(Map<String, dynamic> json) {
    final rawSummaries = json['summaries'];
    final rawImages = json['images'];
    return ContentData(
      original: json['original'] as String?,
      title: json['title'] as String?,
      category: json['category'] as String?,
      summaries: rawSummaries is Map
          ? rawSummaries.map((k, v) => MapEntry(k.toString(), v.toString()))
          : null,
      processing: json['processing'] as bool? ?? false,
      stage: json['stage'] as String?,
      images: rawImages is List
          ? rawImages.map((e) => e.toString()).toList()
          : null,
      error: json['error'] as String?,
      folder: json['folder'] as String?,
      embeddingError: json['embeddingError'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'original': original,
      'title': title,
      'category': category,
      'summaries': summaries,
      'processing': processing,
      'stage': stage,
      'images': images,
      'error': error,
      'folder': folder,
      'embeddingError': embeddingError,
    };
  }

  String? get firstSummary => (summaries != null && summaries!.isNotEmpty)
      ? summaries!.values.first
      : null;

  String? get firstImage =>
      (images != null && images!.isNotEmpty) ? images!.first : null;
}

class ContentRecord {
  final int id;
  final String url;
  final String tag;
  final String status;
  final ContentData data;
  final DateTime createdAt;
  final double? similarity;
  final List<double>? embedding;

  const ContentRecord({
    required this.id,
    required this.url,
    required this.tag,
    required this.status,
    required this.data,
    required this.createdAt,
    this.similarity,
    this.embedding,
  });

  factory ContentRecord.fromJson(Map<String, dynamic> json) {
    return ContentRecord(
      id: json['id'] as int,
      url: json['url'] as String,
      tag: json['tag'] as String,
      status: json['status'] as String,
      data: ContentData.fromJson(
        (json['data'] as Map?)?.cast<String, dynamic>() ?? {},
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
      similarity: (json['similarity'] as num?)?.toDouble(),
      embedding: _parseEmbedding(json['embedding']),
    );
  }

  /// pgvector columns come back as a JSON list from postgrest, but as a
  /// "[0.1,0.2,...]" string from some RPC paths (e.g. match_contents).
  static List<double>? _parseEmbedding(Object? raw) {
    if (raw is List) return raw.map((e) => (e as num).toDouble()).toList();
    if (raw is String && raw.isNotEmpty) {
      final trimmed = raw.replaceAll('[', '').replaceAll(']', '');
      if (trimmed.isEmpty) return null;
      return trimmed.split(',').map((e) => double.parse(e)).toList();
    }
    return null;
  }
}
