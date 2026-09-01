-- ============================================================
-- Sheikhy — Migration 0003_student_questions_select_own.sql
-- Additive only — runs on top of 0002_hardening.sql.
-- Run once in Supabase SQL Editor.
-- ============================================================

-- Fix: the "أسئلتي" (My Questions) screen was empty because
-- 0001_app_support.sql left student_questions with an admin-only
-- SELECT policy. Allow a student to read THEIR OWN questions.
-- CC-22-safe: only own rows (auth.uid() = user_id) are exposed;
-- other students' rows stay unreadable on the base table, and the
-- public feed still goes through student_questions_public (no user_id).

drop policy if exists "questions_select_own" on public.student_questions;
create policy "questions_select_own" on public.student_questions
  for select using (auth.uid() = user_id);
