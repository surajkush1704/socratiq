class MCQModel {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  MCQModel({
    required this.question,
    required this.options,
    required this.correctIndex,
    this.explanation = '',
  });

  factory MCQModel.fromJson(Map<String, dynamic> json) {
    return MCQModel(
      question: json['question'] ?? '',
      options: List<String>.from(json['options'] ?? []),
      correctIndex: json['correct_index'] ?? json['correctIndex'] ?? 0,
      explanation: json['explanation'] ?? '',
    );
  }

  factory MCQModel.fromMap(Map<String, dynamic> map) => MCQModel.fromJson(map);

  Map<String, dynamic> toJson() => {
    'question': question,
    'options': options,
    'correct_index': correctIndex,
    'explanation': explanation,
  };

  Map<String, dynamic> toMap() => toJson();
}
