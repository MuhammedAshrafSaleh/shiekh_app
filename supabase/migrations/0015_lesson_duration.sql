-- 0015_lesson_duration.sql
-- Additive migration: manual per-medium lesson durations + study-seconds RPC.
--
-- Study hours on the Achievements card were a flat 15-min-per-completed-lesson
-- estimate, which heavily under-counts long lessons. Durations are now entered
-- MANUALLY by the admin, separately for video and audio, in minutes. Students
-- never write to `lessons`. Study seconds are computed server-side from real
-- durations (completed lessons) and saved positions (in-progress lessons).

alter table public.lessons
  add column if not exists video_duration_minutes int null
    check (video_duration_minutes between 1 and 600),
  add column if not exists audio_duration_minutes int null
    check (audio_duration_minutes between 1 and 600);

comment on column public.lessons.video_duration_minutes is
  'مدة الفيديو بالدقائق (يدخلها الشيخ يدويًا، 1..600) - تُستخدم لحساب ساعات الدراسة';
comment on column public.lessons.audio_duration_minutes is
  'مدة الملف الصوتي بالدقائق (يدخلها الشيخ يدويًا، 1..600) - تُستخدم لحساب ساعات الدراسة';

-- ------------------------------------------------------------
-- get_my_study_seconds() — total study seconds for the current user.
-- SECURITY DEFINER so it can read lessons.*_duration_minutes regardless of the
-- caller's row-level access; scoped to auth.uid() so a user only ever sees own.
--
-- Per lesson_progress row (vp = video position, ap = audio position, both >= 0):
--   completed = true  → the primary medium's duration (the one with the larger
--                       saved position) in seconds, falling back to the other
--                       medium's duration, then to greatest(vp, ap) if non-zero,
--                       then to a 900s (15 min) constant.
--   completed = false → greatest(vp, ap), capped at the relevant medium's
--                       duration in seconds when that duration is known.
-- ------------------------------------------------------------
create or replace function public.get_my_study_seconds()
returns bigint
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(sum(
    case
      when lp.completed then
        coalesce(
          -- primary medium = the one the student engaged with more
          case when coalesce(lp.audio_position_seconds, 0)
                    > coalesce(lp.video_position_seconds, 0)
               then l.audio_duration_minutes * 60
               else l.video_duration_minutes * 60
          end,
          -- fall back to the other medium's known duration
          case when coalesce(lp.audio_position_seconds, 0)
                    > coalesce(lp.video_position_seconds, 0)
               then l.video_duration_minutes * 60
               else l.audio_duration_minutes * 60
          end,
          -- then to whatever position we managed to save
          nullif(greatest(coalesce(lp.video_position_seconds, 0),
                          coalesce(lp.audio_position_seconds, 0)), 0),
          -- last-resort constant so completed lessons never count as zero
          900
        )
      else
        -- in-progress: real elapsed position, capped at the known duration.
        -- The cap uses the primary medium's duration (larger saved position),
        -- falling back to the other medium's duration — so an audio-only lesson
        -- still caps against audio when positions tie (video duration is null).
        case
          when coalesce(
                 case when coalesce(lp.audio_position_seconds, 0)
                           > coalesce(lp.video_position_seconds, 0)
                      then l.audio_duration_minutes else l.video_duration_minutes end,
                 case when coalesce(lp.audio_position_seconds, 0)
                           > coalesce(lp.video_position_seconds, 0)
                      then l.video_duration_minutes else l.audio_duration_minutes end
               ) is not null
          then least(
                 greatest(coalesce(lp.video_position_seconds, 0),
                          coalesce(lp.audio_position_seconds, 0)),
                 coalesce(
                   case when coalesce(lp.audio_position_seconds, 0)
                             > coalesce(lp.video_position_seconds, 0)
                        then l.audio_duration_minutes else l.video_duration_minutes end,
                   case when coalesce(lp.audio_position_seconds, 0)
                             > coalesce(lp.video_position_seconds, 0)
                        then l.video_duration_minutes else l.audio_duration_minutes end
                 ) * 60)
          else greatest(coalesce(lp.video_position_seconds, 0),
                        coalesce(lp.audio_position_seconds, 0))
        end
    end
  ), 0)::bigint
  from public.lesson_progress lp
  join public.lessons l on l.id = lp.lesson_id
  where lp.user_id = auth.uid();
$$;

grant execute on function public.get_my_study_seconds() to authenticated;
