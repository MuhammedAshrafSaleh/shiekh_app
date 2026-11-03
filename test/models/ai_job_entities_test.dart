// test/models/ai_job_entities_test.dart
//
// Pure parsing tests for the async-queue AI entities. These cover the JSON
// shapes the AdminLessonRepository hands straight to fromJson: the 202 enqueue
// ack, and a generation_jobs row (both a live row and a terminal one).
import 'package:flutter_test/flutter_test.dart';
import 'package:sheikhy_app/models/generation_job_entity.dart';
import 'package:sheikhy_app/models/job_enqueue_entity.dart';

void main() {
  group('JobEnqueueEntity.fromJson', () {
    test('parses the 202 { job_id, status } ack', () {
      final e = JobEnqueueEntity.fromJson(const {
        'job_id': 'job-1',
        'status': 'queued',
      });
      expect(e.jobId, 'job-1');
      expect(e.status, 'queued');
    });

    test('defaults status to queued when absent', () {
      final e = JobEnqueueEntity.fromJson(const {'job_id': 'job-2'});
      expect(e.jobId, 'job-2');
      expect(e.status, 'queued');
    });
  });

  group('GenerationJobEntity.fromJson', () {
    test('parses an active (running) job', () {
      final e = GenerationJobEntity.fromJson(const {
        'id': 'g-1',
        'lesson_id': 'lesson-1',
        'job_type': 'generate_questions',
        'status': 'running',
        'attempts': 2,
        'result_count': null,
        'error_message': null,
      });
      expect(e.id, 'g-1');
      expect(e.lessonId, 'lesson-1');
      expect(e.status, 'running');
      expect(e.attempts, 2);
      expect(e.isActive, true);
      expect(e.resultCount, isNull);
    });

    test('parses a terminal (done) job', () {
      final e = GenerationJobEntity.fromJson(const {
        'id': 'g-2',
        'lesson_id': 'lesson-1',
        'job_type': 'generate_questions',
        'status': 'done',
        'attempts': 3,
        'result_count': 12,
      });
      expect(e.status, 'done');
      expect(e.isActive, false);
      expect(e.resultCount, 12);
    });

    test('parses a failed job with an error message', () {
      final e = GenerationJobEntity.fromJson(const {
        'id': 'g-3',
        'lesson_id': 'lesson-1',
        'job_type': 'generate_questions',
        'status': 'failed',
        'error_message': 'تعذّر التوليد',
      });
      expect(e.isActive, false);
      expect(e.errorMessage, 'تعذّر التوليد');
      expect(e.attempts, 0);
    });
  });
}
