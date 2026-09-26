-- 0016_lessons_public_duration.sql
-- Additive: expose the admin-entered per-medium durations (migration 0015) to
-- the student-facing lesson list, which reads the URL-free `lessons_public`
-- view (0006 → 0008). Both columns are plain metadata (minutes, nullable) — no
-- URLs or quiz content — so surfacing them keeps the view's guest-safe contract.
--
-- Full `create or replace view` that re-states 0008's definition and appends
-- video_duration_minutes / audio_duration_minutes. security_invoker = false is
-- preserved so the view keeps running as owner (unchanged behaviour).

create or replace view public.lessons_public
  with (security_invoker = false)
as
select
  id,
  book_id,
  order_index,
  title,
  description,
  audio_only,
  status,
  created_at,
  updated_at,
  (video_url is not null and not audio_only) as has_video,
  (audio_url is not null)                    as has_audio,
  (pdf_url is not null)                      as has_pdf,
  -- Presence only — true iff the lesson has at least one quiz question.
  (exists (
     select 1 from public.lesson_quiz_questions q
     where q.lesson_id = lessons.id
   ))                                        as has_quiz,
  video_duration_minutes,
  audio_duration_minutes
from public.lessons
where status = 'published';

grant select on public.lessons_public to authenticated;
