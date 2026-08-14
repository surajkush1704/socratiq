class ContentModel {
  final String documentName;
  final String extractedText;
  final String summary;
  final List<String> keyPoints;
  final List<String> topics;
  final DateTime uploadedAt;

  ContentModel({
    required this.documentName,
    required this.extractedText,
    required this.summary,
    required this.keyPoints,
    required this.topics,
    required this.uploadedAt,
  });

  Map<String, dynamic> toMap() => {
    'documentName': documentName,
    'extractedText': extractedText,
    'summary': summary,
    'keyPoints': keyPoints,
    'topics': topics,
    'uploadedAt': uploadedAt.toIso8601String(),
  };

  factory ContentModel.fromMap(Map<String, dynamic> map) => ContentModel(
    documentName: map['documentName'],
    extractedText: map['extractedText'],
    summary: map['summary'],
    keyPoints: List<String>.from(map['keyPoints']),
    topics: List<String>.from(map['topics']),
    uploadedAt: DateTime.parse(map['uploadedAt']),
  );
}
