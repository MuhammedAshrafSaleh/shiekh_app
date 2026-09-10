-- 0009_split_media_position.sql
-- Additive migration: split lesson resume position into per-medium columns.
--
-- Previously video and audio shared lesson_progress.last_position_seconds, so the
-- audio position-save timer overwrote the video resume point and vice-versa. Give
-- each medium its own column. last_position_seconds is kept (dormant) for now — a
-- later cleanup can drop it once no reads remain.

alter table lesson_progress
  add column if not exists video_position_seconds int not null default 0,
  add column if not exists audio_position_seconds int not null default 0;

-- Backfill: existing saved positions are assumed to be video positions.
update lesson_progress
  set video_position_seconds = last_position_seconds
  where last_position_seconds > 0;
