-- 0010_student_questions_admin_delete.sql
-- Additive-only. Adds admin-only DELETE on student_questions so the admin can
-- delete individual questions and clear all questions for a book.
-- The base schema only defined select/insert/admin-update policies.

drop policy if exists "questions_admin_delete" on public.student_questions;
create policy "questions_admin_delete" on public.student_questions
  for delete using (public.is_admin());
