-- 0026_enable_cron_net.sql
-- pg_cron drives the background worker; pg_net lets it call the Edge Function.
--
-- APPLIED TO Medhat-Abdelaziz 2026-11-03 as version 20261103055026.
--
-- After this runs, the schedule itself still has to be created once per
-- project, because it embeds that project's ref in the URL. See
-- docs/WHITELABEL.md, "AI job queue".

create extension if not exists pg_cron;
create extension if not exists pg_net;
