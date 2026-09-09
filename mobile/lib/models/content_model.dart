class ContentModel {
  final String documentName;
  final String extractedText;
  final String summary;
  final List<String> keyPoints;
  final List<String> topics;
  final DateTime uploadedAt;
  final String documentLanguage;      // 'sa', 'hi', 'en', etc.
  final String responseLanguage;      // 'hi', 'en', etc.
  final String languageDisplayName;   // 'Sanskrit', 'Hindi', 'English'

  ContentModel({
    required this.documentName,
    required this.extractedText,
    required this.summary,
    required this.keyPoints,
    required this.topics,
    DateTime? uploadedAt,
    this.documentLanguage = 'en',
    this.responseLanguage = 'en',
    this.languageDisplayName = 'English',
  }) : uploadedAt = uploadedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'documentName': documentName,
    'extractedText': extractedText,
    'summary': summary,
    'keyPoints': keyPoints,
    'topics': topics,
    'uploadedAt': uploadedAt.toIso8601String(),
    'documentLanguage': documentLanguage,
    'responseLanguage': responseLanguage,
    'languageDisplayName': languageDisplayName,
  };

  factory ContentModel.fromMap(Map<String, dynamic> map) => ContentModel(
    documentName: map['documentName'] as String? ?? 'Untitled',
    extractedText: map['extractedText'] as String? ?? '',
    summary: map['summary'] as String? ?? '',
    keyPoints: (map['keyPoints'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    topics: (map['topics'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    uploadedAt: map['uploadedAt'] != null
        ? DateTime.tryParse(map['uploadedAt'].toString()) ?? DateTime.now()
        : DateTime.now(),
    documentLanguage: map['documentLanguage'] as String? ?? 'en',
    responseLanguage: map['responseLanguage'] as String? ?? 'en',
    languageDisplayName: map['languageDisplayName'] as String? ?? 'English',
  );
}
