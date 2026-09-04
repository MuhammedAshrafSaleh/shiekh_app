-- ============================================================
-- Sheikhy — Companion Migration 0004_onboarding.sql
-- Additive only — runs on top of the base schema.sql + 0001–0003.
-- Run this ONCE in Supabase SQL Editor.
-- Adds the admin-managed onboarding slides table shown before login.
-- ============================================================

create table public.onboarding_slides (
  id          uuid primary key default gen_random_uuid(),
  order_index int  not null,
  type        text not null check (type in ('hadith', 'normal')),
  main_text   text not null,  -- الحديث أو العنوان
  sub_text    text,           -- النص التوضيحي (اختياري)
  is_active   boolean not null default true,
  created_at  timestamptz not null default now()
);

alter table public.onboarding_slides enable row level security;

-- Anyone can read active slides; admin can read all (incl. inactive).
create policy "onboarding_read_all" on public.onboarding_slides
  for select using (is_active = true or public.is_admin());

-- Only admin can insert/update/delete.
create policy "onboarding_admin_write" on public.onboarding_slides
  for all using (public.is_admin());

-- Seed initial data.
insert into public.onboarding_slides (order_index, type, main_text, sub_text) values
(1, 'hadith', 'مَن يُرِدِ اللهُ بِهِ خَيْرًا يُفَقِّهْهُ في الدِّينِ', 'شيخي — طريقك لطلب العلم الشرعي'),
(2, 'normal', 'تعلّم من المتون والكتب', 'دروس مرئية ومسموعة وكتب أصيلة بإشراف أهل العلم'),
(3, 'normal', 'ابدأ رحلتك في طلب العلم', 'اختبارات وشهادات إتمام تُرافقك في مسيرتك');
