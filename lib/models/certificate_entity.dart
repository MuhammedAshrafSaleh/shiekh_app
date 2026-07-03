// lib/models/certificate_entity.dart
import 'package:equatable/equatable.dart';

class CertificateEntity extends Equatable {
  final String id;
  final String userId;
  final String bookId;
  final String? finalExamAttemptId;
  final int finalScore;
  final String? gradeLabel;
  final DateTime issuedAt;
  final String? pdfUrl;

  const CertificateEntity({
    required this.id,
    required this.userId,
    required this.bookId,
    this.finalExamAttemptId,
    required this.finalScore,
    this.gradeLabel,
    required this.issuedAt,
    this.pdfUrl,
  });

  factory CertificateEntity.fromJson(Map<String, dynamic> json) {
    return CertificateEntity(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      bookId: json['book_id'] as String,
      finalExamAttemptId: json['final_exam_attempt_id'] as String?,
      finalScore: json['final_score'] as int,
      gradeLabel: json['grade_label'] as String?,
      issuedAt: DateTime.parse(json['issued_at'] as String),
      pdfUrl: json['pdf_url'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        bookId,
        finalExamAttemptId,
        finalScore,
        gradeLabel,
        issuedAt,
        pdfUrl,
      ];
}
