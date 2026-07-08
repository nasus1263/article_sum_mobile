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

  String? get firstSummary =>
      (summaries != null && summaries!.isNotEmpty) ? summaries!.values.first : null;

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

  const ContentRecord({
    required this.id,
    required this.url,
    required this.tag,
    required this.status,
    required this.data,
    required this.createdAt,
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
    );
  }
}
