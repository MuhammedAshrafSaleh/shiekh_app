-- ============================================================
-- Sheikhy — Companion Migration 0021_final_exam_source_fk_set_null.sql
-- Additive / idempotent — safe to re-run. Run ONCE in the Supabase SQL Editor.
--
-- Fixes: deleting a lesson quiz question that was imported into a book's final
-- exam failed with
--   violates foreign key constraint
--   "final_exam_questions_source_quiz_question_id_fkey"
-- because the base-schema FK final_exam_questions.source_quiz_question_id
-- → lesson_quiz_questions(id) had the default ON DELETE NO ACTION, which blocks
-- the delete (and the same block fires on a cascading lesson delete).
--
-- source_quiz_question_id is only a provenance marker: final_exam_questions
-- keeps its OWN copy of question_text / choice_* / correct_choice, so the exam
-- question does not depend on the source row's content. Switching the FK to
-- ON DELETE SET NULL therefore lets the source question be deleted while the
-- exam question stays intact (it just loses the "imported from" link). This
-- also mirrors lesson_quiz_questions.source_question_id (migration 0019), which
-- already uses ON DELETE SET NULL.
-- ============================================================

alter table public.final_exam_questions
  drop constraint if exists final_exam_questions_source_quiz_question_id_fkey;

alter table public.final_exam_questions
  add constraint final_exam_questions_source_quiz_question_id_fkey
    foreign key (source_quiz_question_id)
    references public.lesson_quiz_questions(id)
    on delete set null;
