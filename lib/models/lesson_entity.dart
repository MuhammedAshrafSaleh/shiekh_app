// lib/models/lesson_entity.dart
import 'package:equatable/equatable.dart';

import 'lesson_pdf_entity.dart';

class LessonEntity extends Equatable {
  final String id;
  final String bookId;
  final int orderIndex;
  final String title;
  final String? description;
  final String? videoUrl;
  final String? audioUrl;

  /// DEPRECATED legacy single-PDF link. Read-only in the app — it is an
  /// auto-mirror of the first [pdfs] row maintained by a DB trigger (migration
  /// 0012). Used only for the inline fallback when [pdfs] is empty. Never write
  /// it from the client.
  final String? pdfUrl;
  final bool audioOnly;
  final String status;

  /// Admin-entered playtime per medium, in minutes (migration 0015, nullable,
  /// DB-checked 1..600). Powers the server-side study-hours total and the
  /// student-facing duration tag. Null = admin hasn't entered it yet.
  final int? videoDurationMinutes;
  final int? audioDurationMinutes;

  /// Multiple titled PDFs (migration 0012). Populated when the row is fetched
  /// with the embedded `lesson_pdfs(*)` select; empty for flat fetches.
  final List<LessonPdfEntity> pdfs;

  /// AI transcription pipeline columns (migration 0011). Populated by the
  /// `transcribe-lesson` Edge Function; used by the AI question-generation flow.
  final String? transcript;
  final String transcriptStatus; // none | queued | running | ready | failed
  final String? transcriptError;
  final DateTime? transcriptGeneratedAt;

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
    this.videoDurationMinutes,
    this.audioDurationMinutes,
    this.pdfs = const [],
    this.transcript,
    this.transcriptStatus = 'none',
    this.transcriptError,
    this.transcriptGeneratedAt,
  });

  bool get hasVideo => videoUrl != null && !audioOnly;
  bool get hasAudio => audioUrl != null;

  /// Transition-safe: true if this lesson has any PDF rows, or a legacy mirror
  /// value still present (pre-migration / never-re-saved data).
  bool get hasPdf => pdfs.isNotEmpty || pdfUrl != null;
  bool get hasQuiz => true; // determined by repository

  /// True when a usable transcript is already saved — lets the AI generation
  /// screen offer "generate only" (skip re-transcribing, save a quota slot).
  bool get hasSavedTranscript =>
      transcriptStatus == 'ready' && (transcript?.trim().isNotEmpty ?? false);

  /// PDFs sorted by their order_index, excluding any with an empty url (e.g.
  /// partial-embed entities from the admin list, which carry only `id`). The DB
  /// embed is already ordered, but sort defensively so any caller can rely on it.
  List<LessonPdfEntity> get orderedPdfs {
    final sorted = [...pdfs.where((p) => p.url.isNotEmpty)]
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    return sorted;
  }

  factory LessonEntity.fromJson(Map<String, dynamic> json) {
    final rawPdfs = json['lesson_pdfs'] as List<dynamic>?;
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
      videoDurationMinutes: json['video_duration_minutes'] as int?,
      audioDurationMinutes: json['audio_duration_minutes'] as int?,
      pdfs:
          rawPdfs
              ?.map((e) => LessonPdfEntity.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      transcript: json['transcript'] as String?,
      transcriptStatus: json['transcript_status'] as String? ?? 'none',
      transcriptError: json['transcript_error'] as String?,
      transcriptGeneratedAt: json['transcript_generated_at'] == null
          ? null
          : DateTime.parse(json['transcript_generated_at'] as String),
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
    videoDurationMinutes,
    audioDurationMinutes,
    pdfs,
    transcript,
    transcriptStatus,
    transcriptError,
    transcriptGeneratedAt,
  ];
}
