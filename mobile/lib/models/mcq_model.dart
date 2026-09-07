class MCQModel {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  final String difficulty;

  MCQModel({
    required this.question,
    required this.options,
    required this.correctIndex,
    this.explanation = '',
    this.difficulty = 'medium',
  });

  factory MCQModel.fromJson(Map<String, dynamic> json) {
    return MCQModel(
      question: json['question'] ?? '',
      options: List<String>.from(json['options'] ?? []),
      correctIndex: json['correct_index'] ?? json['correctIndex'] ?? 0,
      explanation: json['explanation'] ?? '',
      difficulty: (json['difficulty'] as String? ?? 'medium').toLowerCase(),
    );
  }

  factory MCQModel.fromMap(Map<String, dynamic> map) => MCQModel.fromJson(map);

  Map<String, dynamic> toJson() => {
    'question': question,
    'options': options,
    'correct_index': correctIndex,
    'explanation': explanation,
    'difficulty': difficulty,
  };

  Map<String, dynamic> toMap() => toJson();
}
