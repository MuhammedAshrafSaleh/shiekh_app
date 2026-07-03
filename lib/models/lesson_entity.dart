// lib/models/lesson_entity.dart
import 'package:equatable/equatable.dart';

class LessonEntity extends Equatable {
  final String id;
  final String bookId;
  final int orderIndex;
  final String title;
  final String? description;
  final String? videoUrl;
  final String? audioUrl;
  final String? pdfUrl;
  final bool audioOnly;
  final String status;

  const LessonEntity({
    required this.id,
    required this.bookId,
    required this.orderIndex,
    required this.title,
    this.description,
    this.videoUrl,
    this.audioUrl,
    this.pdfUrl,
    required this.audioOnly,
    required this.status,
  });

  bool get hasVideo => videoUrl != null && !audioOnly;
  bool get hasAudio => audioUrl != null;
  bool get hasPdf => pdfUrl != null;
  bool get hasQuiz => true; // determined by repository

  factory LessonEntity.fromJson(Map<String, dynamic> json) {
    return LessonEntity(
      id: json['id'] as String,
      bookId: json['book_id'] as String,
      orderIndex: json['order_index'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      videoUrl: json['video_url'] as String?,
      audioUrl: json['audio_url'] as String?,
      pdfUrl: json['pdf_url'] as String?,
      audioOnly: json['audio_only'] as bool,
      status: json['status'] as String,
    );
  }

  @override
  List<Object?> get props => [
        id,
        bookId,
        orderIndex,
        title,
        description,
        videoUrl,
        audioUrl,
        pdfUrl,
        audioOnly,
        status,
      ];
}
